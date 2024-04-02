// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/console.sol";
import "ds-test/test.sol";
import "forge-std/Test.sol";

import "../../../contracts/mock/MockToken.sol";
import "../../../contracts/EthenaLPStaking.sol";
import "../../../contracts/interfaces/IEthenaLPStakingDefinitions.sol";
import "../../../contracts/USDe.sol";

contract EthenaLPStakingTest is DSTest, Test, IEthenaLPStakingDefinitions {
  // ---------------------- Setup -----------------------

  EthenaLPStaking public ethenaLpStaking;

  address public owner;
  address public newOwner;
  MockToken public lpToken;
  address public alice;
  address internal constant _ETH_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

  function setUp() public virtual {
    owner = vm.addr(0xA11CE);
    newOwner = vm.addr(0x1);
    lpToken = new MockToken("LP Token", "LPT", 18, address(this));
    alice = vm.addr(0x1DEA);

    vm.label(owner, "owner");
    vm.label(newOwner, "newOwner");
    vm.label(alice, "alice");

    ethenaLpStaking = new EthenaLPStaking(owner);
  }

  // --------------------- Helpers ----------------------

  function _updateStakeParamsAndCheck(
    address caller,
    address token,
    uint8 epoch,
    uint248 stakeLimit,
    uint48 cooldown,
    bool expectRevert,
    uint8 oldEpoch,
    uint248 oldStakeLimit,
    uint104 oldTotalStaked,
    uint104 oldTotalCoolingDown,
    uint48 oldCooldown
  ) internal {
    if (!expectRevert) {
      vm.expectEmit(true, true, true, true);
      emit StakeParametersUpdated(token, epoch, stakeLimit, cooldown);
    }
    vm.prank(caller);
    ethenaLpStaking.updateStakeParameters(token, epoch, stakeLimit, cooldown);
    if (expectRevert) {
      _checkStakeParams(token, oldEpoch, oldStakeLimit, oldTotalStaked, oldTotalCoolingDown, oldCooldown);
    } else {
      _checkStakeParams(token, epoch, stakeLimit, oldTotalStaked, oldTotalCoolingDown, cooldown);
    }
  }

  function _checkStakeParams(
    address token,
    uint8 epoch,
    uint248 stakeLimit,
    uint104 totalStaked,
    uint104 totalCoolingDown,
    uint48 cooldown
  ) internal {
    (uint8 _epoch, uint248 _stakeLimit, uint104 _totalStaked, uint104 _totalCoolingDown, uint48 _cooldown) =
      ethenaLpStaking.stakeParametersByToken(token);
    assertEq(_epoch, epoch);
    assertEq(_stakeLimit, stakeLimit);
    assertEq(_totalStaked, totalStaked);
    assertEq(_totalCoolingDown, totalCoolingDown);
    assertEq(_cooldown, cooldown);
  }

  function _setEpochAndCheck(uint8 newEpoch, uint8 oldEpoch, address caller, bool expectRevert) internal {
    if (!expectRevert) {
      vm.expectEmit(true, true, true, true);
      emit NewEpoch(newEpoch, oldEpoch);
    }
    vm.prank(caller);
    ethenaLpStaking.setEpoch(newEpoch);
    if (expectRevert) {
      assertEq(ethenaLpStaking.currentEpoch(), oldEpoch);
    } else {
      assertEq(ethenaLpStaking.currentEpoch(), newEpoch);
    }
  }

  function _stakeAndCheck(
    address caller,
    address token,
    uint104 amount,
    bool expectRevert,
    uint256 oldStakedAmount,
    uint256 oldCoolingDownAmount,
    uint256 oldCooldownStartTimestamp,
    uint256 oldTotalStaked,
    uint256 oldTotalCoolingDown
  ) internal {
    if (!expectRevert) {
      vm.expectEmit(true, true, true, true);
      emit Stake(caller, token, amount);
    }
    vm.prank(caller);
    ethenaLpStaking.stake(token, amount);
    if (expectRevert) {
      _checkStake(
        caller,
        token,
        oldStakedAmount,
        oldCoolingDownAmount,
        oldCooldownStartTimestamp,
        oldTotalStaked,
        oldTotalCoolingDown
      );
    } else {
      _checkStake(
        caller,
        token,
        oldStakedAmount + amount,
        oldCoolingDownAmount,
        oldCooldownStartTimestamp,
        oldTotalStaked + amount,
        oldTotalCoolingDown
      );
    }
  }

  function _unstakeAndCheck(
    address caller,
    address token,
    uint104 amount,
    bool expectRevert,
    uint256 oldStakedAmount,
    uint256 oldCoolingDownAmount,
    uint256 oldCooldownStartTimestamp,
    uint256 oldTotalStaked,
    uint256 oldTotalCoolingDown
  ) internal {
    if (!expectRevert) {
      vm.expectEmit(true, true, true, true);
      emit Unstake(caller, token, amount);
    }
    vm.prank(caller);
    ethenaLpStaking.unstake(token, amount);
    if (expectRevert) {
      _checkStake(
        caller,
        token,
        oldStakedAmount,
        oldCoolingDownAmount,
        oldCooldownStartTimestamp,
        oldTotalStaked,
        oldTotalCoolingDown
      );
    } else {
      _checkStake(
        caller,
        token,
        oldStakedAmount - amount,
        oldCoolingDownAmount + amount,
        block.timestamp,
        oldTotalStaked - amount,
        oldTotalCoolingDown + amount
      );
    }
  }

  function _withdrawAndCheck(
    address caller,
    address token,
    uint104 amount,
    bool expectRevert,
    uint256 oldStakedAmount,
    uint256 oldCoolingDownAmount,
    uint256 oldCooldownStartTimestamp,
    uint256 oldTotalStaked,
    uint256 oldTotalCoolingDown
  ) internal {
    if (!expectRevert) {
      vm.expectEmit(true, true, true, true);
      emit Withdraw(caller, token, amount);
    }
    vm.prank(caller);
    ethenaLpStaking.withdraw(token, amount);
    if (expectRevert) {
      _checkStake(
        caller,
        token,
        oldStakedAmount,
        oldCoolingDownAmount,
        oldCooldownStartTimestamp,
        oldTotalStaked,
        oldTotalCoolingDown
      );
    } else {
      _checkStake(
        caller,
        token,
        oldStakedAmount,
        oldCoolingDownAmount - amount,
        oldCooldownStartTimestamp,
        oldTotalStaked,
        oldTotalCoolingDown - amount
      );
    }
  }

  function _checkStake(
    address staker,
    address token,
    uint256 stakedAmount,
    uint256 coolingDownAmount,
    uint256 cooldownStartTimestamp,
    uint256 totalStaked,
    uint256 totalCoolingDown
  ) internal {
    (uint256 _stakedAmount, uint256 _coolingDownAmount, uint256 _cooldownStartTimestamp) =
      ethenaLpStaking.stakes(staker, token);
    assertEq(_stakedAmount, stakedAmount);
    assertEq(_coolingDownAmount, coolingDownAmount);
    assertEq(_cooldownStartTimestamp, cooldownStartTimestamp);
    (,, uint104 _totalStaked, uint104 _totalCoolingDown,) = ethenaLpStaking.stakeParametersByToken(token);
    assertEq(_totalStaked, totalStaked);
    assertEq(_totalCoolingDown, totalCoolingDown);
  }

  // --------------------- Deployment ----------------------

  function testDeploy() public {
    assertEq(ethenaLpStaking.owner(), owner);
  }

  function testFuzzDeploy(address possibleToken, address possibleStaker) public {
    (uint8 epoch, uint248 stakeLimit, uint104 totalStaked, uint104 totalCoolingDown, uint48 cooldown) =
      ethenaLpStaking.stakeParametersByToken(possibleToken);
    assertEq(epoch, 0);
    assertEq(stakeLimit, 0);
    assertEq(totalStaked, 0);
    assertEq(totalCoolingDown, 0);
    assertEq(cooldown, 0);
    (uint256 stakedAmount, uint152 coolingDownAmount, uint104 cooldownStartTimestamp) =
      ethenaLpStaking.stakes(possibleStaker, possibleToken);
    assertEq(stakedAmount, 0);
    assertEq(coolingDownAmount, 0);
    assertEq(cooldownStartTimestamp, 0);
  }

  // --------------------- Owner ----------------------

  // --------------------- ownership ----------------------

  function testCantInitWithNoOwner() public {
    vm.expectRevert(ZeroAddressException.selector);
    new EthenaLPStaking(address(0));
  }

  function testOwnershipCannotBeRenounced() public {
    vm.prank(owner);
    vm.expectRevert(CantRenounceOwnership.selector);
    ethenaLpStaking.renounceOwnership();
    assertEq(ethenaLpStaking.owner(), owner);
    assertNotEq(ethenaLpStaking.owner(), address(0));
  }

  function testOwnershipTransferRequiresTwoSteps() public {
    vm.prank(owner);
    ethenaLpStaking.transferOwnership(newOwner);
    assertEq(ethenaLpStaking.owner(), owner);
    assertNotEq(ethenaLpStaking.owner(), newOwner);
  }

  function testCanTransferOwnership() public {
    vm.prank(owner);
    ethenaLpStaking.transferOwnership(newOwner);
    vm.prank(newOwner);
    ethenaLpStaking.acceptOwnership();
    assertEq(ethenaLpStaking.owner(), newOwner);
    assertNotEq(ethenaLpStaking.owner(), owner);
  }

  function testCanCancelOwnershipChange() public {
    vm.startPrank(owner);
    ethenaLpStaking.transferOwnership(newOwner);
    ethenaLpStaking.transferOwnership(address(0));
    vm.stopPrank();

    vm.prank(newOwner);
    vm.expectRevert("Ownable2Step: caller is not the new owner");
    ethenaLpStaking.acceptOwnership();
    assertEq(ethenaLpStaking.owner(), owner);
    assertNotEq(ethenaLpStaking.owner(), newOwner);
  }

  // --------------------- setEpoch ----------------------

  function testFuzzOwnerCanSetEpoch(uint8 epoch) public {
    vm.assume(epoch != 0);
    _setEpochAndCheck(epoch, 0, owner, false);
  }

  function testFuzzOwnerCanUpdateEpoch(uint8 oldEpoch, uint8 newEpoch) public {
    vm.assume(oldEpoch != 0 && newEpoch != oldEpoch);
    _setEpochAndCheck(oldEpoch, 0, owner, false);
    _setEpochAndCheck(newEpoch, oldEpoch, owner, false);
  }

  function testFuzzNonOwnerCannotSetEpoch(uint8 epoch) public {
    vm.assume(epoch != 0);
    vm.expectRevert("Ownable: caller is not the owner");
    _setEpochAndCheck(epoch, 0, newOwner, true);
  }

  function testFuzzOwnerCantSetEpochToSameEpoch(uint8 epoch) public {
    vm.assume(epoch != 0);
    vm.expectRevert(IEthenaLPStakingDefinitions.InvalidEpoch.selector);
    _setEpochAndCheck(0, 0, owner, true);
    _setEpochAndCheck(epoch, 0, owner, false);
    vm.expectRevert(IEthenaLPStakingDefinitions.InvalidEpoch.selector);
    _setEpochAndCheck(epoch, epoch, owner, true);
  }

  // --------------------- updateStakeParameters ----------------------

  function testFuzzAddStakeParameters(address token, uint8 epoch, uint248 stakeLimit, uint48 cooldown) public {
    cooldown = uint48(bound(cooldown, 0, 90 days));
    _updateStakeParamsAndCheck(owner, token, epoch, stakeLimit, cooldown, false, 0, 0, 0, 0, 0);
  }

  function testFuzzNonOwnerCannotAddStakeParameters(
    address nonOwner,
    address token,
    uint8 epoch,
    uint248 stakeLimit,
    uint48 cooldown
  ) public {
    vm.assume(nonOwner != owner);
    vm.expectRevert("Ownable: caller is not the owner");
    _updateStakeParamsAndCheck(nonOwner, token, epoch, stakeLimit, cooldown, true, 0, 0, 0, 0, 0);
  }

  function testFuzzOwnerCanUpdateStakeParameters(
    address token,
    uint8 epoch,
    uint248 stakeLimit,
    uint48 cooldown,
    uint8 newEpoch,
    uint248 newStakeLimit,
    uint48 newCooldown
  ) public {
    cooldown = uint48(bound(cooldown, 0, 90 days));
    newCooldown = uint48(bound(newCooldown, 0, 90 days));
    _updateStakeParamsAndCheck(owner, token, epoch, stakeLimit, cooldown, false, 0, 0, 0, 0, 0);
    _updateStakeParamsAndCheck(
      owner, token, newEpoch, newStakeLimit, newCooldown, false, epoch, stakeLimit, 0, 0, cooldown
    );
  }

  function testFuzzOwnerCannotAddCooldownAboveMax(uint48 cooldown) public {
    cooldown = uint48(bound(cooldown, 90 days + 1, 2 ** 48 - 1));
    vm.expectRevert(IEthenaLPStakingDefinitions.MaxCooldownExceeded.selector);
    _updateStakeParamsAndCheck(owner, address(lpToken), 0, 0, cooldown, true, 0, 0, 0, 0, 0);
  }

  function testFuzzOwnerCannotModifyTotals(
    uint8 epoch,
    uint104 stakeLimit,
    uint104 unstakeAmount,
    uint48 cooldown,
    uint8 newEpoch,
    uint248 newStakeLimit,
    uint48 newCooldown
  ) public {
    cooldown = uint48(bound(cooldown, 0, 90 days));
    stakeLimit = uint104(bound(stakeLimit, 1, lpToken.totalSupply()));
    unstakeAmount = uint104(bound(unstakeAmount, 1, stakeLimit));
    newCooldown = uint48(bound(newCooldown, 0, 90 days));
    _updateStakeParamsAndCheck(owner, address(lpToken), epoch, stakeLimit, cooldown, false, 0, 0, 0, 0, 0);
    if (epoch != 0) _setEpochAndCheck(epoch, 0, owner, false);
    lpToken.transfer(alice, stakeLimit);
    vm.prank(alice);
    lpToken.approve(address(ethenaLpStaking), stakeLimit);
    _stakeAndCheck(alice, address(lpToken), stakeLimit, false, 0, 0, 0, 0, 0);
    _unstakeAndCheck(alice, address(lpToken), unstakeAmount, false, stakeLimit, 0, 0, stakeLimit, 0);
    _updateStakeParamsAndCheck(
      owner,
      address(lpToken),
      newEpoch,
      newStakeLimit,
      newCooldown,
      false,
      epoch,
      stakeLimit,
      stakeLimit - unstakeAmount,
      unstakeAmount,
      cooldown
    );
  }

  // --------------------- rescueTokens ----------------------

  function testFuzzOwnerCanRescueETH(uint256 balInContract, uint256 amountToRescue) public {
    vm.assume(balInContract > 0);
    amountToRescue = bound(amountToRescue, 1, balInContract);
    vm.deal(address(ethenaLpStaking), balInContract);
    vm.prank(owner);
    vm.expectEmit(true, true, true, true);
    emit TokensRescued(_ETH_ADDRESS, alice, amountToRescue);
    ethenaLpStaking.rescueTokens(_ETH_ADDRESS, alice, amountToRescue);
    assertEq(alice.balance, amountToRescue);
  }

  function testFuzzOwnerCannotRescueETHToAddressZero(uint256 balInContract, uint256 amountToRescue) public {
    vm.assume(balInContract > 0);
    amountToRescue = bound(amountToRescue, 1, balInContract);
    vm.deal(address(ethenaLpStaking), balInContract);
    vm.prank(owner);
    vm.expectRevert(ZeroAddressException.selector);
    ethenaLpStaking.rescueTokens(_ETH_ADDRESS, address(0), amountToRescue);
    assertEq(address(ethenaLpStaking).balance, balInContract);
  }

  function testFuzzOwnerCanRescueERC20(uint256 balInContract, uint256 amountToRescue) public {
    balInContract = bound(balInContract, 1, lpToken.totalSupply());
    amountToRescue = bound(amountToRescue, 1, balInContract);
    lpToken.transfer(address(ethenaLpStaking), balInContract);
    vm.prank(owner);
    vm.expectEmit(true, true, true, true);
    emit TokensRescued(address(lpToken), alice, amountToRescue);
    ethenaLpStaking.rescueTokens(address(lpToken), alice, amountToRescue);
    assertEq(IERC20(lpToken).balanceOf(alice), amountToRescue);
  }

  function testFuzzOwnerCantRescueERC20ToAddressZero(uint256 balInContract, uint256 amountToRescue) public {
    balInContract = bound(balInContract, 1, lpToken.totalSupply());
    amountToRescue = bound(amountToRescue, 1, balInContract);
    lpToken.transfer(address(ethenaLpStaking), balInContract);
    vm.prank(owner);
    vm.expectRevert(ZeroAddressException.selector);
    ethenaLpStaking.rescueTokens(address(lpToken), address(0), amountToRescue);
    assertEq(IERC20(lpToken).balanceOf(address(ethenaLpStaking)), balInContract);
  }

  function testFuzzOwnerCanRescueETH(address _nonOwner, uint256 balInContract, uint256 amountToRescue) public {
    vm.assume(_nonOwner != owner);
    vm.assume(balInContract > 0);
    amountToRescue = bound(amountToRescue, 1, balInContract);
    vm.deal(address(ethenaLpStaking), balInContract);
    vm.prank(_nonOwner);
    vm.expectRevert("Ownable: caller is not the owner");
    ethenaLpStaking.rescueTokens(_ETH_ADDRESS, alice, amountToRescue);
    assertEq(alice.balance, 0);
  }

  function testFuzzOwnerCanRescueERC20(address _nonOwner, uint256 balInContract, uint256 amountToRescue) public {
    vm.assume(_nonOwner != owner);
    balInContract = bound(balInContract, 1, lpToken.totalSupply());
    amountToRescue = bound(amountToRescue, 1, balInContract);
    lpToken.transfer(address(ethenaLpStaking), balInContract);
    vm.prank(_nonOwner);
    vm.expectRevert("Ownable: caller is not the owner");
    ethenaLpStaking.rescueTokens(address(lpToken), alice, amountToRescue);
    assertEq(IERC20(lpToken).balanceOf(alice), 0);
  }

  function testFuzzOwnerCannotRescueMoreThanExcessBalance(uint104 stakeLimit, uint48 cooldown, uint104 excessBalance)
    public
  {
    stakeLimit = uint104(bound(stakeLimit, 1, lpToken.totalSupply() - 1));
    excessBalance = uint104(bound(excessBalance, 1, lpToken.totalSupply() - stakeLimit));
    cooldown = uint48(bound(cooldown, 0, 90 days));
    _updateStakeParamsAndCheck(owner, address(lpToken), 0, stakeLimit, cooldown, false, 0, 0, 0, 0, 0);
    lpToken.transfer(alice, stakeLimit);
    vm.prank(alice);
    lpToken.approve(address(ethenaLpStaking), stakeLimit);
    _stakeAndCheck(alice, address(lpToken), stakeLimit, false, 0, 0, 0, 0, 0);
    lpToken.transfer(address(ethenaLpStaking), excessBalance);
    vm.prank(owner);
    vm.expectRevert(InvariantBroken.selector);
    ethenaLpStaking.rescueTokens(address(lpToken), alice, excessBalance + 1);
    assertEq(IERC20(lpToken).balanceOf(alice), 0);
    assertEq(IERC20(lpToken).balanceOf(address(ethenaLpStaking)), stakeLimit + excessBalance);
  }

  function testFuzzOwnerCannotRescueMoreThanExcessBalanceWithCoolingDown(
    uint104 stakeLimit,
    uint104 unstakeAmount,
    uint48 cooldown,
    uint104 excessBalance
  ) public {
    stakeLimit = uint104(bound(stakeLimit, 1, lpToken.totalSupply() - 1));
    unstakeAmount = uint104(bound(unstakeAmount, 1, stakeLimit));
    excessBalance = uint104(bound(excessBalance, 1, lpToken.totalSupply() - stakeLimit));
    cooldown = uint48(bound(cooldown, 0, 90 days));
    _updateStakeParamsAndCheck(owner, address(lpToken), 0, stakeLimit, cooldown, false, 0, 0, 0, 0, 0);
    lpToken.transfer(alice, stakeLimit);
    vm.prank(alice);
    lpToken.approve(address(ethenaLpStaking), stakeLimit);
    _stakeAndCheck(alice, address(lpToken), stakeLimit, false, 0, 0, 0, 0, 0);
    _unstakeAndCheck(alice, address(lpToken), unstakeAmount, false, stakeLimit, 0, 0, stakeLimit, 0);
    lpToken.transfer(address(ethenaLpStaking), excessBalance);
    vm.prank(owner);
    vm.expectRevert(InvariantBroken.selector);
    ethenaLpStaking.rescueTokens(address(lpToken), alice, excessBalance + 1);
    assertEq(IERC20(lpToken).balanceOf(alice), 0);
    assertEq(IERC20(lpToken).balanceOf(address(ethenaLpStaking)), stakeLimit + excessBalance);
  }

  function testFuzzOwnerCanRescueExcessBalanceWithCoolingDown(
    uint104 stakeLimit,
    uint104 unstakeAmount,
    uint48 cooldown,
    uint104 excessBalance
  ) public {
    stakeLimit = uint104(bound(stakeLimit, 1, lpToken.totalSupply() - 1));
    unstakeAmount = uint104(bound(unstakeAmount, 1, stakeLimit));
    excessBalance = uint104(bound(excessBalance, 1, lpToken.totalSupply() - stakeLimit));
    cooldown = uint48(bound(cooldown, 0, 90 days));
    _updateStakeParamsAndCheck(owner, address(lpToken), 0, stakeLimit, cooldown, false, 0, 0, 0, 0, 0);
    lpToken.transfer(alice, stakeLimit);
    vm.prank(alice);
    lpToken.approve(address(ethenaLpStaking), stakeLimit);
    _stakeAndCheck(alice, address(lpToken), stakeLimit, false, 0, 0, 0, 0, 0);
    _unstakeAndCheck(alice, address(lpToken), unstakeAmount, false, stakeLimit, 0, 0, stakeLimit, 0);
    lpToken.transfer(address(ethenaLpStaking), excessBalance);
    vm.prank(owner);
    vm.expectEmit(true, true, true, true);
    emit TokensRescued(address(lpToken), alice, excessBalance);
    ethenaLpStaking.rescueTokens(address(lpToken), alice, excessBalance);
    assertEq(IERC20(lpToken).balanceOf(alice), excessBalance);
    assertEq(IERC20(lpToken).balanceOf(address(ethenaLpStaking)), stakeLimit);
  }

  // --------------------- User ----------------------

  // --------------------- stake ----------------------

  function testFuzzStake(address staker, uint104 amount, uint104 stakeLimit, uint48 cooldown, uint8 stakeEpoch) public {
    vm.assume(staker != address(0) && staker != address(this) && staker != address(ethenaLpStaking));
    stakeLimit = uint104(bound(stakeLimit, 1, lpToken.totalSupply()));
    amount = uint104(bound(amount, 1, stakeLimit));
    cooldown = uint48(bound(cooldown, 0, 90 days));
    _updateStakeParamsAndCheck(owner, address(lpToken), stakeEpoch, amount, cooldown, false, 0, 0, 0, 0, 0);
    if (stakeEpoch != 0) _setEpochAndCheck(stakeEpoch, 0, owner, false);
    lpToken.transfer(staker, amount);
    vm.prank(staker);
    lpToken.approve(address(ethenaLpStaking), amount);
    _stakeAndCheck(staker, address(lpToken), amount, false, 0, 0, 0, 0, 0);
    assertEq(IERC20(lpToken).balanceOf(staker), 0);
    assertEq(IERC20(lpToken).balanceOf(address(ethenaLpStaking)), amount);
  }

  function testFuzzCantStakeWrongEpoch(
    address staker,
    uint104 amount,
    uint104 stakeLimit,
    uint48 cooldown,
    uint8 currentEpoch,
    uint8 stakeEpoch
  ) public {
    vm.assume(currentEpoch != stakeEpoch);
    vm.assume(staker != address(0) && staker != address(this) && staker != address(ethenaLpStaking));
    stakeLimit = uint104(bound(stakeLimit, 1, lpToken.totalSupply()));
    amount = uint104(bound(amount, 1, stakeLimit));
    cooldown = uint48(bound(cooldown, 0, 90 days));
    _updateStakeParamsAndCheck(owner, address(lpToken), stakeEpoch, amount, cooldown, false, 0, 0, 0, 0, 0);
    if (currentEpoch != 0) _setEpochAndCheck(currentEpoch, 0, owner, false);
    lpToken.transfer(staker, amount);
    vm.prank(staker);
    lpToken.approve(address(ethenaLpStaking), amount);
    vm.expectRevert(InvalidEpoch.selector);
    _stakeAndCheck(staker, address(lpToken), amount, true, 0, 0, 0, 0, 0);
    assertEq(IERC20(lpToken).balanceOf(staker), amount);
    assertEq(IERC20(lpToken).balanceOf(address(ethenaLpStaking)), 0);
  }

  function testFuzzCantStakeLimitExceeded(
    address staker,
    uint104 amount,
    uint104 stakeLimit,
    uint48 cooldown,
    uint8 stakeEpoch
  ) public {
    vm.assume(staker != address(0) && staker != address(this) && staker != address(ethenaLpStaking));
    stakeLimit = uint104(bound(stakeLimit, 1, lpToken.totalSupply() - 1));
    amount = uint104(bound(amount, stakeLimit + 1, lpToken.totalSupply()));
    cooldown = uint48(bound(cooldown, 0, 90 days));
    _updateStakeParamsAndCheck(owner, address(lpToken), stakeEpoch, stakeLimit, cooldown, false, 0, 0, 0, 0, 0);
    if (stakeEpoch != 0) _setEpochAndCheck(stakeEpoch, 0, owner, false);
    lpToken.transfer(staker, amount);
    vm.prank(staker);
    lpToken.approve(address(ethenaLpStaking), amount);
    vm.expectRevert(StakeLimitExceeded.selector);
    _stakeAndCheck(staker, address(lpToken), amount, true, 0, 0, 0, 0, 0);
    assertEq(IERC20(lpToken).balanceOf(staker), amount);
    assertEq(IERC20(lpToken).balanceOf(address(ethenaLpStaking)), 0);
  }

  function testFuzzCantStakeZero(address staker, uint104 stakeLimit, uint48 cooldown, uint8 stakeEpoch) public {
    vm.assume(staker != address(0) && staker != address(this) && staker != address(ethenaLpStaking));
    stakeLimit = uint104(bound(stakeLimit, 1, lpToken.totalSupply() - 1));
    cooldown = uint48(bound(cooldown, 0, 90 days));
    _updateStakeParamsAndCheck(owner, address(lpToken), stakeEpoch, stakeLimit, cooldown, false, 0, 0, 0, 0, 0);
    if (stakeEpoch != 0) _setEpochAndCheck(stakeEpoch, 0, owner, false);
    lpToken.transfer(staker, 1);
    vm.prank(staker);
    lpToken.approve(address(ethenaLpStaking), 1);
    vm.expectRevert(InvalidAmount.selector);
    _stakeAndCheck(staker, address(lpToken), 0, true, 0, 0, 0, 0, 0);
    assertEq(IERC20(lpToken).balanceOf(staker), 1);
    assertEq(IERC20(lpToken).balanceOf(address(ethenaLpStaking)), 0);
  }

  // --------------------- unstake ----------------------

  function testFuzzCanUnstake(
    address staker,
    uint104 stakeAmount,
    uint104 unstakeAmount,
    uint104 stakeLimit,
    uint48 cooldown,
    uint8 stakeEpoch
  ) public {
    vm.assume(staker != address(0) && staker != address(this) && staker != address(ethenaLpStaking));
    stakeLimit = uint104(bound(stakeLimit, 1, lpToken.totalSupply()));
    stakeAmount = uint104(bound(stakeAmount, 1, stakeLimit));
    unstakeAmount = uint104(bound(unstakeAmount, 1, stakeAmount));
    cooldown = uint48(bound(cooldown, 0, 90 days));
    _updateStakeParamsAndCheck(owner, address(lpToken), stakeEpoch, stakeLimit, cooldown, false, 0, 0, 0, 0, 0);
    if (stakeEpoch != 0) _setEpochAndCheck(stakeEpoch, 0, owner, false);
    lpToken.transfer(staker, stakeAmount);
    vm.prank(staker);
    lpToken.approve(address(ethenaLpStaking), stakeAmount);
    _stakeAndCheck(staker, address(lpToken), stakeAmount, false, 0, 0, 0, 0, 0);
    _unstakeAndCheck(staker, address(lpToken), unstakeAmount, false, stakeAmount, 0, 0, stakeAmount, 0);
    assertEq(IERC20(lpToken).balanceOf(staker), 0);
    assertEq(IERC20(lpToken).balanceOf(address(ethenaLpStaking)), stakeAmount);
  }

  function testFuzzCantUnstakeZero(
    address staker,
    uint104 stakeAmount,
    uint104 stakeLimit,
    uint48 cooldown,
    uint8 stakeEpoch
  ) public {
    vm.assume(staker != address(0) && staker != address(this) && staker != address(ethenaLpStaking));
    stakeLimit = uint104(bound(stakeLimit, 1, lpToken.totalSupply()));
    stakeAmount = uint104(bound(stakeAmount, 1, stakeLimit));
    cooldown = uint48(bound(cooldown, 0, 90 days));
    _updateStakeParamsAndCheck(owner, address(lpToken), stakeEpoch, stakeLimit, cooldown, false, 0, 0, 0, 0, 0);
    if (stakeEpoch != 0) _setEpochAndCheck(stakeEpoch, 0, owner, false);
    lpToken.transfer(staker, stakeAmount);
    vm.prank(staker);
    lpToken.approve(address(ethenaLpStaking), stakeAmount);
    _stakeAndCheck(staker, address(lpToken), stakeAmount, false, 0, 0, 0, 0, 0);
    vm.expectRevert(InvalidAmount.selector);
    _unstakeAndCheck(staker, address(lpToken), 0, true, stakeAmount, 0, 0, stakeAmount, 0);
    assertEq(IERC20(lpToken).balanceOf(staker), 0);
    assertEq(IERC20(lpToken).balanceOf(address(ethenaLpStaking)), stakeAmount);
  }

  function testFuzzCantUnstakeMoreThanStake(
    address staker,
    uint104 stakeAmount,
    uint104 unstakeAmount,
    uint104 stakeLimit,
    uint48 cooldown,
    uint8 stakeEpoch
  ) public {
    vm.assume(staker != address(0) && staker != address(this) && staker != address(ethenaLpStaking));
    stakeLimit = uint104(bound(stakeLimit, 1, lpToken.totalSupply()));
    stakeAmount = uint104(bound(stakeAmount, 1, stakeLimit));
    unstakeAmount = uint104(bound(unstakeAmount, stakeAmount + 1, lpToken.totalSupply()));
    cooldown = uint48(bound(cooldown, 0, 90 days));
    _updateStakeParamsAndCheck(owner, address(lpToken), stakeEpoch, stakeLimit, cooldown, false, 0, 0, 0, 0, 0);
    if (stakeEpoch != 0) _setEpochAndCheck(stakeEpoch, 0, owner, false);
    lpToken.transfer(staker, stakeAmount);
    vm.prank(staker);
    lpToken.approve(address(ethenaLpStaking), stakeAmount);
    _stakeAndCheck(staker, address(lpToken), stakeAmount, false, 0, 0, 0, 0, 0);
    vm.expectRevert(InvalidAmount.selector);
    _unstakeAndCheck(staker, address(lpToken), 0, true, stakeAmount, 0, 0, stakeAmount, 0);
    assertEq(IERC20(lpToken).balanceOf(staker), 0);
    assertEq(IERC20(lpToken).balanceOf(address(ethenaLpStaking)), stakeAmount);
  }

  function testFuzzCanUnstakeEntireStake(
    address staker,
    uint104 stakeAmount,
    uint104 stakeLimit,
    uint48 cooldown,
    uint8 stakeEpoch
  ) public {
    vm.assume(staker != address(0) && staker != address(this) && staker != address(ethenaLpStaking));
    stakeLimit = uint104(bound(stakeLimit, 1, lpToken.totalSupply()));
    stakeAmount = uint104(bound(stakeAmount, 1, stakeLimit));
    cooldown = uint48(bound(cooldown, 0, 90 days));
    _updateStakeParamsAndCheck(owner, address(lpToken), stakeEpoch, stakeLimit, cooldown, false, 0, 0, 0, 0, 0);
    if (stakeEpoch != 0) _setEpochAndCheck(stakeEpoch, 0, owner, false);
    lpToken.transfer(staker, stakeAmount);
    vm.prank(staker);
    lpToken.approve(address(ethenaLpStaking), stakeAmount);
    _stakeAndCheck(staker, address(lpToken), stakeAmount, false, 0, 0, 0, 0, 0);
    _unstakeAndCheck(staker, address(lpToken), stakeAmount, false, stakeAmount, 0, 0, stakeAmount, 0);
    assertEq(IERC20(lpToken).balanceOf(staker), 0);
    assertEq(IERC20(lpToken).balanceOf(address(ethenaLpStaking)), stakeAmount);
  }

  function testFuzzCantUnstakeWithoutExistingStake(
    address staker,
    uint104 stakeAmount,
    uint104 stakeLimit,
    uint48 cooldown,
    uint8 stakeEpoch
  ) public {
    vm.assume(staker != address(0) && staker != address(this) && staker != address(ethenaLpStaking));
    stakeLimit = uint104(bound(stakeLimit, 1, lpToken.totalSupply()));
    stakeAmount = uint104(bound(stakeAmount, 1, stakeLimit));
    cooldown = uint48(bound(cooldown, 0, 90 days));
    _updateStakeParamsAndCheck(owner, address(lpToken), stakeEpoch, stakeLimit, cooldown, false, 0, 0, 0, 0, 0);
    if (stakeEpoch != 0) _setEpochAndCheck(stakeEpoch, 0, owner, false);
    lpToken.transfer(staker, stakeAmount);
    vm.prank(staker);
    lpToken.approve(address(ethenaLpStaking), stakeAmount);
    vm.expectRevert(InvalidAmount.selector);
    _unstakeAndCheck(staker, address(lpToken), stakeAmount, true, 0, 0, 0, 0, 0);
    assertEq(IERC20(lpToken).balanceOf(staker), stakeAmount);
    assertEq(IERC20(lpToken).balanceOf(address(ethenaLpStaking)), 0);
  }

  // --------------------- withdraw ----------------------

  function testFuzzCanWithdraw(
    address staker,
    uint104 stakeAmount,
    uint104 unstakeAmount,
    uint104 withdrawAmount,
    uint104 stakeLimit,
    uint48 cooldown,
    uint48 waitTime,
    uint8 stakeEpoch
  ) public {
    vm.assume(staker != address(0) && staker != address(this) && staker != address(ethenaLpStaking));
    stakeLimit = uint104(bound(stakeLimit, 1, lpToken.totalSupply()));
    stakeAmount = uint104(bound(stakeAmount, 1, stakeLimit));
    unstakeAmount = uint104(bound(unstakeAmount, 1, stakeAmount));
    withdrawAmount = uint104(bound(withdrawAmount, 1, unstakeAmount));
    cooldown = uint48(bound(cooldown, 0, 90 days));
    waitTime = uint48(bound(waitTime, cooldown, 2 ** 48 - 1));
    _updateStakeParamsAndCheck(owner, address(lpToken), stakeEpoch, stakeLimit, cooldown, false, 0, 0, 0, 0, 0);
    if (stakeEpoch != 0) _setEpochAndCheck(stakeEpoch, 0, owner, false);
    lpToken.transfer(staker, stakeAmount);
    vm.prank(staker);
    lpToken.approve(address(ethenaLpStaking), stakeAmount);
    _stakeAndCheck(staker, address(lpToken), stakeAmount, false, 0, 0, 0, 0, 0);
    _unstakeAndCheck(staker, address(lpToken), unstakeAmount, false, stakeAmount, 0, 0, stakeAmount, 0);
    uint256 totalStaked = stakeAmount - unstakeAmount;
    vm.warp(block.timestamp + waitTime);
    _withdrawAndCheck(
      staker,
      address(lpToken),
      withdrawAmount,
      false,
      totalStaked,
      unstakeAmount,
      block.timestamp - waitTime,
      totalStaked,
      unstakeAmount
    );
    assertEq(IERC20(lpToken).balanceOf(staker), withdrawAmount);
    assertEq(IERC20(lpToken).balanceOf(address(ethenaLpStaking)), stakeAmount - withdrawAmount);
  }

  function testFuzzCantWithdrawZero(
    address staker,
    uint104 stakeAmount,
    uint104 unstakeAmount,
    uint104 stakeLimit,
    uint48 cooldown,
    uint48 waitTime,
    uint8 stakeEpoch
  ) public {
    vm.assume(staker != address(0) && staker != address(this) && staker != address(ethenaLpStaking));
    stakeLimit = uint104(bound(stakeLimit, 1, lpToken.totalSupply()));
    stakeAmount = uint104(bound(stakeAmount, 1, stakeLimit));
    unstakeAmount = uint104(bound(unstakeAmount, 1, stakeAmount));
    cooldown = uint48(bound(cooldown, 0, 90 days));
    waitTime = uint48(bound(waitTime, cooldown, 2 ** 48 - 1));
    _updateStakeParamsAndCheck(owner, address(lpToken), stakeEpoch, stakeLimit, cooldown, false, 0, 0, 0, 0, 0);
    if (stakeEpoch != 0) _setEpochAndCheck(stakeEpoch, 0, owner, false);
    lpToken.transfer(staker, stakeAmount);
    vm.prank(staker);
    lpToken.approve(address(ethenaLpStaking), stakeAmount);
    _stakeAndCheck(staker, address(lpToken), stakeAmount, false, 0, 0, 0, 0, 0);
    _unstakeAndCheck(staker, address(lpToken), unstakeAmount, false, stakeAmount, 0, 0, stakeAmount, 0);
    uint256 totalStaked = stakeAmount - unstakeAmount;
    vm.warp(block.timestamp + waitTime);
    vm.expectRevert(InvalidAmount.selector);
    _withdrawAndCheck(
      staker,
      address(lpToken),
      0,
      true,
      totalStaked,
      unstakeAmount,
      block.timestamp - waitTime,
      totalStaked,
      unstakeAmount
    );
    assertEq(IERC20(lpToken).balanceOf(staker), 0);
    assertEq(IERC20(lpToken).balanceOf(address(ethenaLpStaking)), stakeAmount);
  }

  function testFuzzCantWithdrawBeforeCooldown(
    address staker,
    uint104 stakeAmount,
    uint104 unstakeAmount,
    uint104 withdrawAmount,
    uint104 stakeLimit,
    uint48 cooldown,
    uint48 waitTime,
    uint8 stakeEpoch
  ) public {
    vm.assume(staker != address(0) && staker != address(this) && staker != address(ethenaLpStaking));
    stakeLimit = uint104(bound(stakeLimit, 1, lpToken.totalSupply()));
    stakeAmount = uint104(bound(stakeAmount, 1, stakeLimit));
    unstakeAmount = uint104(bound(unstakeAmount, 1, stakeAmount));
    withdrawAmount = uint104(bound(withdrawAmount, 1, unstakeAmount));
    cooldown = uint48(bound(cooldown, 1, 90 days));
    waitTime = uint48(bound(waitTime, 0, cooldown - 1));
    _updateStakeParamsAndCheck(owner, address(lpToken), stakeEpoch, stakeLimit, cooldown, false, 0, 0, 0, 0, 0);
    if (stakeEpoch != 0) _setEpochAndCheck(stakeEpoch, 0, owner, false);
    lpToken.transfer(staker, stakeAmount);
    vm.prank(staker);
    lpToken.approve(address(ethenaLpStaking), stakeAmount);
    _stakeAndCheck(staker, address(lpToken), stakeAmount, false, 0, 0, 0, 0, 0);
    _unstakeAndCheck(staker, address(lpToken), unstakeAmount, false, stakeAmount, 0, 0, stakeAmount, 0);
    uint256 totalStaked = stakeAmount - unstakeAmount;
    vm.warp(block.timestamp + waitTime);
    vm.expectRevert(CooldownNotOver.selector);
    _withdrawAndCheck(
      staker,
      address(lpToken),
      withdrawAmount,
      true,
      totalStaked,
      unstakeAmount,
      block.timestamp - waitTime,
      totalStaked,
      unstakeAmount
    );
    assertEq(IERC20(lpToken).balanceOf(staker), 0);
    assertEq(IERC20(lpToken).balanceOf(address(ethenaLpStaking)), stakeAmount);
  }

  function testFuzzWithdrawDoesNotResetCooldown(
    address staker,
    uint104 stakeAmount,
    uint104 unstakeAmount,
    uint104 withdrawAmount,
    uint104 stakeLimit,
    uint48 cooldown,
    uint48 waitTime,
    uint8 stakeEpoch
  ) public {
    vm.assume(staker != address(0) && staker != address(this) && staker != address(ethenaLpStaking));
    stakeLimit = uint104(bound(stakeLimit, 2, lpToken.totalSupply()));
    stakeAmount = uint104(bound(stakeAmount, 2, stakeLimit));
    unstakeAmount = uint104(bound(unstakeAmount, 2, stakeAmount));
    withdrawAmount = uint104(bound(withdrawAmount, 1, unstakeAmount / 2));
    cooldown = uint48(bound(cooldown, 0, 90 days));
    waitTime = uint48(bound(waitTime, cooldown, 2 ** 48 - 1));
    _updateStakeParamsAndCheck(owner, address(lpToken), stakeEpoch, stakeLimit, cooldown, false, 0, 0, 0, 0, 0);
    if (stakeEpoch != 0) _setEpochAndCheck(stakeEpoch, 0, owner, false);
    lpToken.transfer(staker, stakeAmount);
    vm.prank(staker);
    lpToken.approve(address(ethenaLpStaking), stakeAmount);
    _stakeAndCheck(staker, address(lpToken), stakeAmount, false, 0, 0, 0, 0, 0);
    _unstakeAndCheck(staker, address(lpToken), unstakeAmount, false, stakeAmount, 0, 0, stakeAmount, 0);
    uint256 totalStaked = stakeAmount - unstakeAmount;
    vm.warp(block.timestamp + waitTime);
    _withdrawAndCheck(
      staker,
      address(lpToken),
      withdrawAmount,
      false,
      totalStaked,
      unstakeAmount,
      block.timestamp - waitTime,
      totalStaked,
      unstakeAmount
    );
    assertEq(IERC20(lpToken).balanceOf(staker), withdrawAmount);
    assertEq(IERC20(lpToken).balanceOf(address(ethenaLpStaking)), stakeAmount - withdrawAmount);
    unstakeAmount -= withdrawAmount;
    _withdrawAndCheck(
      staker,
      address(lpToken),
      withdrawAmount,
      false,
      totalStaked,
      unstakeAmount,
      block.timestamp - waitTime,
      totalStaked,
      unstakeAmount
    );
    assertEq(IERC20(lpToken).balanceOf(staker), withdrawAmount * 2);
    assertEq(IERC20(lpToken).balanceOf(address(ethenaLpStaking)), stakeAmount - withdrawAmount * 2);
  }

  function testFuzzCantWithdrawBeforeUnstaking(
    address staker,
    uint104 stakeAmount,
    uint104 withdrawAmount,
    uint104 stakeLimit,
    uint48 cooldown,
    uint48 waitTime,
    uint8 stakeEpoch
  ) public {
    vm.assume(staker != address(0) && staker != address(this) && staker != address(ethenaLpStaking));
    stakeLimit = uint104(bound(stakeLimit, 1, lpToken.totalSupply()));
    stakeAmount = uint104(bound(stakeAmount, 1, stakeLimit));
    withdrawAmount = uint104(bound(withdrawAmount, 1, stakeAmount));
    cooldown = uint48(bound(cooldown, 0, 90 days));
    waitTime = uint48(bound(waitTime, cooldown, 2 ** 48 - 1));
    _updateStakeParamsAndCheck(owner, address(lpToken), stakeEpoch, stakeLimit, cooldown, false, 0, 0, 0, 0, 0);
    if (stakeEpoch != 0) _setEpochAndCheck(stakeEpoch, 0, owner, false);
    lpToken.transfer(staker, stakeAmount);
    vm.prank(staker);
    lpToken.approve(address(ethenaLpStaking), stakeAmount);
    _stakeAndCheck(staker, address(lpToken), stakeAmount, false, 0, 0, 0, 0, 0);
    vm.warp(block.timestamp + waitTime);
    vm.expectRevert(InvalidAmount.selector);
    _withdrawAndCheck(staker, address(lpToken), withdrawAmount, true, stakeAmount, 0, 0, stakeAmount, 0);
    assertEq(IERC20(lpToken).balanceOf(staker), 0);
    assertEq(IERC20(lpToken).balanceOf(address(ethenaLpStaking)), stakeAmount);
  }

  function testUSDeAsLockingToken() public {
    USDe usde = new USDe(owner);
    vm.startPrank(owner);
    usde.setMinter(owner);
    usde.mint(alice, 100 ether);
    vm.stopPrank();
    vm.prank(alice);
    usde.approve(address(ethenaLpStaking), 100 ether);
    vm.expectRevert(StakeLimitExceeded.selector);
    _stakeAndCheck(alice, address(usde), 100 ether, true, 0, 0, 0, 0, 0);
    assertEq(usde.balanceOf(alice), 100 ether);
    assertEq(usde.balanceOf(address(ethenaLpStaking)), 0);
    vm.startPrank(owner);
    ethenaLpStaking.setEpoch(1);
    ethenaLpStaking.updateStakeParameters(address(usde), 1, 100 ether, 20);
    vm.stopPrank();
    _stakeAndCheck(alice, address(usde), 100 ether, false, 0, 0, 0, 0, 0);
    assertEq(usde.balanceOf(alice), 0);
    assertEq(usde.balanceOf(address(ethenaLpStaking)), 100 ether);
    _unstakeAndCheck(alice, address(usde), 100 ether, false, 100 ether, 0, block.timestamp, 100 ether, 0);
    assertEq(usde.balanceOf(alice), 0);
    assertEq(usde.balanceOf(address(ethenaLpStaking)), 100 ether);
    vm.expectRevert(CooldownNotOver.selector);
    uint48 cooldownStart = uint48(block.timestamp);
    _withdrawAndCheck(alice, address(usde), 100 ether, true, 0, 100 ether, cooldownStart, 0, 100 ether);
    assertEq(usde.balanceOf(alice), 0);
    assertEq(usde.balanceOf(address(ethenaLpStaking)), 100 ether);
    vm.warp(block.timestamp + 20);
    _withdrawAndCheck(alice, address(usde), 100 ether, false, 0, 100 ether, cooldownStart, 0, 100 ether);
    assertEq(usde.balanceOf(alice), 100 ether);
    assertEq(usde.balanceOf(address(ethenaLpStaking)), 0);
  }
}
