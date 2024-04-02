// SPDX-License-Identifier: MIT
pragma solidity >=0.8;

/* solhint-disable var-name-mixedcase */
/* solhint-disable private-vars-leading-underscore */

import {console} from "forge-std/console.sol";
import "forge-std/Test.sol";
import {SigUtils} from "../../utils/SigUtils.sol";

import "../../../contracts/USDe.sol";
import "../../../contracts/StakedUSDe.sol";
import "../../../contracts/interfaces/IUSDe.sol";
import "../../../contracts/interfaces/IERC20Events.sol";
import "./StakedUSDe.t.sol";

contract EthenaBalancerRateProviderTest is Test, IERC20Events {
  USDe public usdeToken;
  StakedUSDe public stakedUSDe;
  EthenaBalancerRateProvider public rateProvider;

  SigUtils public sigUtilsUSDe;
  SigUtils public sigUtilsStakedUSDe;

  address public owner;
  address public rewarder;
  address public alice;
  address public bob;
  address public greg;

  bytes32 REWARDER_ROLE = keccak256("REWARDER_ROLE");

  event Deposit(address indexed caller, address indexed owner, uint256 assets, uint256 shares);
  event Withdraw(
    address indexed caller, address indexed receiver, address indexed owner, uint256 assets, uint256 shares
  );
  event RewardsReceived(uint256 indexed amount);

  function setUp() public virtual {
    usdeToken = new USDe(address(this));

    alice = vm.addr(0xB44DE);
    bob = vm.addr(0x1DE);
    greg = vm.addr(0x6ED);
    owner = vm.addr(0xA11CE);
    rewarder = vm.addr(0x1DEA);
    vm.label(alice, "alice");
    vm.label(bob, "bob");
    vm.label(greg, "greg");
    vm.label(owner, "owner");
    vm.label(rewarder, "rewarder");

    vm.prank(owner);
    stakedUSDe = new StakedUSDe(IUSDe(address(usdeToken)), rewarder, owner);
    rateProvider = new EthenaBalancerRateProvider(address(stakedUSDe));

    sigUtilsUSDe = new SigUtils(usdeToken.DOMAIN_SEPARATOR());
    sigUtilsStakedUSDe = new SigUtils(stakedUSDe.DOMAIN_SEPARATOR());

    usdeToken.setMinter(address(this));
  }

  function _mintApproveDeposit(address staker, uint256 amount) internal {
    usdeToken.mint(staker, amount);

    vm.startPrank(staker);
    usdeToken.approve(address(stakedUSDe), amount);

    uint256 prevRate = rateProvider.getRate();

    vm.expectEmit(true, true, true, false);
    emit Deposit(staker, staker, amount, amount);

    stakedUSDe.deposit(amount, staker);
    vm.stopPrank();

    if (prevRate == 0) return;

    uint256 _totalSupply = stakedUSDe.totalSupply();

    if (_totalSupply == 0) {
      assertEq(rateProvider.getRate(), 0);
    } else {
      // redeeming can decrease the rate slightly when mint is huge and totalSupply is small
      // decrease < 1e-16 percent
      uint256 newRate = rateProvider.getRate();
      // 1e-16 percent is the max chg https://book.getfoundry.sh/reference/forge-std/assertApproxEqRel
      assertApproxEqRel(newRate, prevRate, 1, "_mint: Rate should not change");
    }
  }

  function _redeem(address staker, uint256 amount) internal {
    vm.startPrank(staker);

    vm.expectEmit(true, true, true, false);
    emit Withdraw(staker, staker, staker, amount, amount);

    uint256 prevRate = rateProvider.getRate();

    stakedUSDe.redeem(amount, staker, staker);

    uint256 _totalSupply = stakedUSDe.totalSupply();
    if (_totalSupply == 0) {
      assertEq(rateProvider.getRate(), 0);
    } else {
      uint256 newRate = rateProvider.getRate();
      assertGe(newRate, prevRate, "_redeem: Rate should not decrease");
      // 1e-16 percent is the max chg https://book.getfoundry.sh/reference/forge-std/assertApproxEqRel
      assertApproxEqRel(newRate, prevRate, 1, "_redeem: Rate should not change");
    }

    vm.stopPrank();
  }

  function _transferRewards(uint256 amount, uint256 expectedNewVestingAmount) internal {
    usdeToken.mint(address(rewarder), amount);
    vm.startPrank(rewarder);

    usdeToken.approve(address(stakedUSDe), amount);
    uint256 prevRate = rateProvider.getRate();

    vm.expectEmit(true, true, false, true);
    emit Transfer(rewarder, address(stakedUSDe), amount);

    stakedUSDe.transferInRewards(amount);

    assertEq(rateProvider.getRate(), prevRate, "Rate should not change");

    assertApproxEqAbs(stakedUSDe.getUnvestedAmount(), expectedNewVestingAmount, 1);
    vm.stopPrank();
  }

  function _assertVestedAmountIs(uint256 amount) internal {
    assertApproxEqAbs(stakedUSDe.totalAssets(), amount, 2);
  }

  function testRateCanResetToZero() public {
    uint256 amount = 349025800980970709709;
    _mintApproveDeposit(alice, amount);
    assertEq(rateProvider.getRate(), 1 ether);
    _redeem(alice, amount);
    assertEq(rateProvider.getRate(), 0);
  }

  function testRate() public {
    uint256 amount = 349025800980970709709;
    uint256 amount2 = 4348203948;
    uint256 amount3 = 9830943709327043274902347930498908;
    uint256 amount4 = 33232;
    uint256 amount5 = 1203948230483098089080;
    uint256 expectedNewRate = (amount + amount2 + amount3 + amount5) * 1 ether / (amount + amount2 + amount3);
    console.log("expectedNewRate", expectedNewRate);
    _mintApproveDeposit(alice, amount);
    assertEq(rateProvider.getRate(), 1 ether);
    _mintApproveDeposit(bob, amount2);
    assertEq(rateProvider.getRate(), 1 ether);
    _mintApproveDeposit(greg, amount3);
    assertEq(rateProvider.getRate(), 1 ether);
    _transferRewards(amount5, amount5);
    vm.warp(block.timestamp + 8 hours);
    _redeem(alice, amount4);
    assertEq(rateProvider.getRate(), expectedNewRate);
    _redeem(bob, amount2);
    assertEq(rateProvider.getRate(), expectedNewRate);
    _redeem(greg, amount3);
    assertEq(rateProvider.getRate(), expectedNewRate);
    _redeem(alice, amount - amount4);
    assertEq(rateProvider.getRate(), 0);
  }

  function testFuzzRate(uint256 amount, uint256 amount2, uint256 amount3, uint256 amount4, uint256 amount5) public {
    amount = bound(amount, 1 ether + 1, 1e50);
    amount4 = bound(amount4, 1, amount - 1 ether);
    amount2 = bound(amount2, 1, 1e50);
    amount3 = bound(amount3, 1, 1e50);
    amount5 = bound(amount5, 1, 1e50);
    uint256 amountsWithoutRewards = (amount + amount2 + amount3);
    uint256 amountsWithRewards = (amountsWithoutRewards + amount5);
    uint256 expectedNewRate = amountsWithRewards * 1 ether / amountsWithoutRewards;
    console.log("expectedNewRate", expectedNewRate);
    _mintApproveDeposit(alice, amount);
    assertEq(rateProvider.getRate(), 1 ether);
    _mintApproveDeposit(bob, amount2);
    assertEq(rateProvider.getRate(), 1 ether);
    _mintApproveDeposit(greg, amount3);
    assertEq(rateProvider.getRate(), 1 ether);
    _transferRewards(amount5, amount5);
    vm.warp(block.timestamp + 8 hours);
    _redeem(alice, amount4);
    assertApproxEqRel(rateProvider.getRate(), expectedNewRate, 1);
    _redeem(bob, amount2);
    assertApproxEqRel(rateProvider.getRate(), expectedNewRate, 2);
    _redeem(greg, amount3);
    assertApproxEqRel(rateProvider.getRate(), expectedNewRate, 2);
    _redeem(alice, amount - amount4);
    assertEq(rateProvider.getRate(), 0);
    assertEq(stakedUSDe.totalAssets() * 1 ether / amountsWithRewards, 0);
    assertEq(stakedUSDe.totalSupply(), 0);
  }
}
