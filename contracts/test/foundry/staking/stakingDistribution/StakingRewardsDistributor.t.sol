// SPDX-License-Identifier: MIT
pragma solidity >=0.8;

/* solhint-disable private-vars-leading-underscore  */
/* solhint-disable var-name-mixedcase  */
/* solhint-disable func-name-mixedcase  */

import {console} from "forge-std/console.sol";
import "forge-std/Test.sol";
import {SigUtils} from "../../../utils/SigUtils.sol";

import "../../../../contracts/USDe.sol";
import "../../../../contracts/StakedUSDeV2.sol";
import "../../../../contracts/StakingRewardsDistributor.sol";
import "../../../../contracts/interfaces/IStakedUSDe.sol";
import "../../../../contracts/interfaces/IStakingRewardsDistributor.sol";
import "../../../../contracts/interfaces/IUSDe.sol";
import "../../../../contracts/interfaces/IERC20Events.sol";
import "../../minting/EthenaMinting.utils.sol";

contract StakingRewardsDistributorTest is IERC20Events, EthenaMintingUtils {
  StakedUSDeV2 public stakedUSDe;
  StakingRewardsDistributor public stakingRewardsDistributor;

  uint256 public _amount = 100 ether;

  address public operator;
  address public mockRewarder;

  bytes32 OPERATOR_ROLE;
  bytes32 DEFAULT_ADMIN_ROLE;
  bytes32 REWARDER_ROLE;

  uint256 private operatorPrivateKey = uint256(keccak256(abi.encodePacked("operator")));

  // Staking distributor events
  event RewardsReceived(uint256 amount);
  /// @notice Event emitted when tokens are rescued by owner
  event TokensRescued(address indexed token, address indexed to, uint256 amount);
  /// @notice This event is fired when the operator changes
  event OperatorUpdated(address indexed newOperator, address indexed previousOperator);
  /// @notice This event is fired when the mint contract changes
  event MintingContractUpdated(address indexed newMintingContract, address indexed previousMintingContract);

  function setUp() public virtual override {
    super.setUp();

    DEFAULT_ADMIN_ROLE = 0x00;
    REWARDER_ROLE = keccak256("REWARDER_ROLE");

    operator = vm.addr(operatorPrivateKey);
    mockRewarder = makeAddr("mock_rewarder");

    vm.startPrank(owner);

    // The rewarder has to be the stakingRewardsDistributor, so we have a circular dependency
    stakedUSDe = new StakedUSDeV2(IUSDe(address(usdeToken)), mockRewarder, owner);

    // Remove the native token entry since it's not an ERC20
    assets.pop();

    stakingRewardsDistributor = new StakingRewardsDistributor(
      EthenaMintingContract, stakedUSDe, IUSDe(address(usdeToken)), assets, owner, operator
    );

    // Revoke the mock rewarder needed for the circular dependency
    stakedUSDe.revokeRole(REWARDER_ROLE, mockRewarder);

    // Update the rewarder to be the stakingRewardsDistributor
    stakedUSDe.grantRole(REWARDER_ROLE, address(stakingRewardsDistributor));

    // Mint stEth to the staking rewards distributor contract
    stETHToken.mint(_stETHToDeposit, address(stakingRewardsDistributor));

    vm.stopPrank();
  }

  // Delegated mint performed by the operator using the available funds from
  // the staking rewards distributor. The USDe minted is sent to the staking contract
  // calling transferInRewards by the operator, as the staking rewards distributor has the rewarder role
  function test_full_workflow() public {
    test_transfer_rewards_setup();

    // Since the USDe already landed on the staking rewards contract, send it to the staking contract
    vm.prank(operator);
    vm.expectEmit();
    emit RewardsReceived(_usdeToMint);
    stakingRewardsDistributor.transferInRewards(_usdeToMint);

    assertEq(
      usdeToken.balanceOf(address(stakingRewardsDistributor)),
      0,
      "The staking rewards distributor USDe balance should be 0"
    );
    assertEq(
      usdeToken.balanceOf(address(stakedUSDe)), _usdeToMint, "The staking contract should have the transfered USDe"
    );
  }

  function test_transfer_rewards_setup() public {
    IEthenaMinting.Order memory customOrder = IEthenaMinting.Order({
      order_type: IEthenaMinting.OrderType.MINT,
      expiry: block.timestamp + 10 minutes,
      nonce: 1,
      benefactor: address(stakingRewardsDistributor),
      beneficiary: address(stakingRewardsDistributor),
      collateral_asset: address(stETHToken),
      usde_amount: _usdeToMint,
      collateral_amount: _stETHToDeposit
    });

    address[] memory targets = new address[](1);
    targets[0] = address(EthenaMintingContract);

    uint256[] memory ratios = new uint256[](1);
    ratios[0] = 10_000;

    IEthenaMinting.Route memory route = IEthenaMinting.Route({addresses: targets, ratios: ratios});

    assertEq(
      uint256(EthenaMintingContract.delegatedSigner(operator, address(stakingRewardsDistributor))),
      uint256(IEthenaMinting.DelegatedSignerStatus.PENDING),
      "The delegation status should be pending"
    );

    bytes32 digest1 = EthenaMintingContract.hashOrder(customOrder);

    // accept delegation
    vm.prank(operator);
    vm.expectEmit();
    emit DelegatedSignerAdded(operator, address(stakingRewardsDistributor));
    EthenaMintingContract.confirmDelegatedSigner(address(stakingRewardsDistributor));

    assertEq(
      uint256(EthenaMintingContract.delegatedSigner(operator, address(stakingRewardsDistributor))),
      uint256(IEthenaMinting.DelegatedSignerStatus.ACCEPTED),
      "The delegation status should be accepted"
    );

    IEthenaMinting.Signature memory operatorSig =
      signOrder(operatorPrivateKey, digest1, IEthenaMinting.SignatureType.EIP712);

    assertEq(
      stETHToken.balanceOf(address(EthenaMintingContract)), 0, "Mismatch in Minting contract stETH balance before mint"
    );
    assertEq(
      stETHToken.balanceOf(address(stakingRewardsDistributor)),
      _stETHToDeposit,
      "Mismatch in benefactor stETH balance before mint"
    );
    assertEq(
      usdeToken.balanceOf(address(stakingRewardsDistributor)), 0, "Mismatch in beneficiary USDe balance before mint"
    );

    vm.prank(minter);
    EthenaMintingContract.mint(customOrder, route, operatorSig);

    assertEq(
      stETHToken.balanceOf(address(EthenaMintingContract)),
      _stETHToDeposit,
      "Mismatch in Minting contract stETH balance after mint"
    );
    assertEq(
      stETHToken.balanceOf(address(stakingRewardsDistributor)), 0, "Mismatch in beneficiary stETH balance after mint"
    );
    assertEq(
      usdeToken.balanceOf(address(stakingRewardsDistributor)),
      _usdeToMint,
      "Mismatch in beneficiary USDe balance after mint"
    );
  }

  /**
   * Access control
   */
  function test_set_operator_and_accept_delegation_by_owner() public {
    vm.startPrank(owner);

    vm.expectEmit();
    emit DelegatedSignerInitiated(bob, address(stakingRewardsDistributor));
    emit DelegatedSignerRemoved(operator, address(stakingRewardsDistributor));
    stakingRewardsDistributor.setOperator(bob);

    assertEq(
      uint256(EthenaMintingContract.delegatedSigner(bob, address(stakingRewardsDistributor))),
      uint256(IEthenaMinting.DelegatedSignerStatus.PENDING),
      "The delegation status should be pending"
    );

    vm.stopPrank();

    assertEq(stakingRewardsDistributor.operator(), bob);

    assertEq(
      uint256(EthenaMintingContract.delegatedSigner(bob, address(stakingRewardsDistributor))),
      uint256(IEthenaMinting.DelegatedSignerStatus.PENDING),
      "The delegation status should be pending"
    );

    vm.prank(bob);
    vm.expectEmit();
    emit DelegatedSignerAdded(bob, address(stakingRewardsDistributor));
    EthenaMintingContract.confirmDelegatedSigner(address(stakingRewardsDistributor));

    assertEq(stakingRewardsDistributor.operator(), bob);
  }

  function test_non_admin_cannot_set_operator_revert(address notAdmin) public {
    vm.assume(notAdmin != owner);

    vm.startPrank(notAdmin);

    vm.expectRevert("Ownable: caller is not the owner");

    stakingRewardsDistributor.setOperator(bob);

    vm.stopPrank();

    assertNotEq(stakingRewardsDistributor.operator(), bob);
  }

  function test_remove_operator() public {
    vm.startPrank(owner);

    stakingRewardsDistributor.setOperator(bob);

    assertEq(stakingRewardsDistributor.operator(), bob);

    stakingRewardsDistributor.setOperator(randomer);

    assertNotEq(stakingRewardsDistributor.operator(), bob);

    vm.stopPrank();
  }

  function test_fuzz_change_operator_role_by_other_reverts(address notAdmin) public {
    vm.assume(notAdmin != owner);

    vm.startPrank(owner);

    stakingRewardsDistributor.setOperator(bob);

    vm.stopPrank();

    vm.startPrank(notAdmin);

    vm.expectRevert("Ownable: caller is not the owner");

    stakingRewardsDistributor.setOperator(randomer);

    vm.stopPrank();

    assertEq(stakingRewardsDistributor.operator(), bob);
  }

  function test_revoke_operator_by_myself_reverts() public {
    vm.startPrank(owner);

    stakingRewardsDistributor.setOperator(bob);

    vm.stopPrank();

    vm.startPrank(bob);

    vm.expectRevert("Ownable: caller is not the owner");

    stakingRewardsDistributor.setOperator(randomer);

    vm.stopPrank();

    assertEq(stakingRewardsDistributor.operator(), bob);
  }

  function test_admin_cannot_renounce() public {
    vm.prank(owner);

    vm.expectRevert(IStakingRewardsDistributor.CantRenounceOwnership.selector);
    stakingRewardsDistributor.renounceOwnership();

    assertEq(stakingRewardsDistributor.owner(), owner);
  }

  function test_non_admin_cannot_give_admin_revert(address notAdmin) public {
    vm.assume(notAdmin != owner);

    vm.startPrank(notAdmin);

    vm.expectRevert("Ownable: caller is not the owner");
    stakingRewardsDistributor.transferOwnership(bob);

    vm.stopPrank();

    assertEq(stakingRewardsDistributor.owner(), owner);
  }

  function test_operator_cannot_transfer_rewards_insufficient_funds_revert() public {
    vm.prank(operator);

    vm.expectRevert(IStakingRewardsDistributor.InsufficientFunds.selector);
    stakingRewardsDistributor.transferInRewards(1);

    assertEq(usdeToken.balanceOf(address(stakedUSDe)), 0, "The staking contract should hold no funds");
  }

  function test_non_operator_cannot_transfer_rewards(address notOperator) public {
    vm.assume(notOperator != operator);

    test_transfer_rewards_setup();

    vm.prank(notOperator);

    vm.expectRevert(IStakingRewardsDistributor.OnlyOperator.selector);
    stakingRewardsDistributor.transferInRewards(_usdeToMint);

    assertEq(usdeToken.balanceOf(address(stakedUSDe)), 0, "The staking contract should hold no funds");
  }

  function test_operator_cannot_transfer_more_rewards_than_available() public {
    test_transfer_rewards_setup();

    vm.prank(operator);

    vm.expectRevert(IStakingRewardsDistributor.InsufficientFunds.selector);
    stakingRewardsDistributor.transferInRewards(_usdeToMint + 1);

    assertEq(usdeToken.balanceOf(address(stakedUSDe)), 0, "The staking contract should hold no funds");
  }

  function test_fuzz_non_owner_cannot_approve_tokens_revert(address notAdmin) public {
    vm.assume(notAdmin != owner);

    vm.prank(notAdmin);

    address[] memory asset = new address[](1);
    asset[0] = address(0);

    vm.expectRevert("Ownable: caller is not the owner");

    stakingRewardsDistributor.approveToMintContract(asset);
  }

  function test_owner_can_approve_tokens() public {
    address testToken = address(new MockToken("Test", "T", 18, owner));
    address testToken2 = address(new MockToken("Test2", "T2", 18, owner));
    address[] memory asset = new address[](2);
    asset[0] = testToken;
    asset[1] = testToken2;

    vm.prank(owner);
    stakingRewardsDistributor.approveToMintContract(asset);
  }

  // Only when using test forks
  //function test_owner_can_approve_token_usdt() public {
  //  vm.prank(owner);
  //
  //  address[] memory asset = new address[](1);
  //  asset[0] = address(0xdAC17F958D2ee523a2206206994597C13D831ec7);
  //
  //  stakingRewardsDistributor.approveToMintContract(asset);
  //}

  function test_assert_correct_owner() public {
    vm.prank(owner);

    assertEq(stakingRewardsDistributor.owner(), owner);
  }

  function test_owner_set_minting_contract() public {
    vm.prank(owner);

    address payable mockAddress = payable(address(1));

    vm.expectEmit();
    emit MintingContractUpdated(mockAddress, address(EthenaMintingContract));
    stakingRewardsDistributor.setMintingContract(EthenaMinting(mockAddress));

    assertEq(address(stakingRewardsDistributor.mintContract()), mockAddress);
  }

  function test_fuzz_non_owner_cannot_set_minting_contract(address notAdmin) public {
    vm.assume(notAdmin != owner);

    vm.prank(notAdmin);

    vm.expectRevert("Ownable: caller is not the owner");
    stakingRewardsDistributor.setMintingContract(EthenaMinting(payable(address(1))));

    assertEq(address(stakingRewardsDistributor.mintContract()), address(EthenaMintingContract));
  }

  function test_fuzz_non_owner_cannot_rescue_tokens(address notAdmin) public {
    vm.assume(notAdmin != owner);

    vm.prank(notAdmin);

    vm.expectRevert("Ownable: caller is not the owner");

    stakingRewardsDistributor.rescueTokens(address(usdeToken), randomer, _usdeToMint);

    assertTrue(usdeToken.balanceOf(notAdmin) != _usdeToMint);
  }

  function test_owner_can_rescue_tokens() public {
    test_transfer_rewards_setup();

    vm.prank(owner);

    vm.expectEmit();
    emit TokensRescued(address(usdeToken), randomer, _usdeToMint);
    stakingRewardsDistributor.rescueTokens(address(usdeToken), randomer, _usdeToMint);

    assertEq(usdeToken.balanceOf(randomer), _usdeToMint);
  }

  function test_owner_can_rescue_ETH() public {
    address ethPlaceholder = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    vm.deal(address(stakingRewardsDistributor), 1e18);
    vm.prank(owner);

    vm.expectEmit();
    emit TokensRescued(ethPlaceholder, randomer, 1e18);
    stakingRewardsDistributor.rescueTokens(ethPlaceholder, randomer, 1e18);

    assertEq(randomer.balance, 1e18);
  }

  function test_correct_initial_config() public {
    assertEq(stakingRewardsDistributor.owner(), owner);
    assertEq(address(stakingRewardsDistributor.mintContract()), address(EthenaMintingContract));
    assertEq(address(stakingRewardsDistributor.USDE_TOKEN()), address(usdeToken));
  }

  function test_revoke_erc20_approvals() public {
    vm.startPrank(owner);

    address oldMintContract = address(stakingRewardsDistributor.mintContract());

    // Change the current minting contract address
    stakingRewardsDistributor.setMintingContract(EthenaMinting(payable(address(1))));

    stakingRewardsDistributor.revokeApprovals(assets, oldMintContract);

    for (uint256 i = 0; i < assets.length; i++) {
      assertEq(IERC20(assets[i]).allowance(address(stakingRewardsDistributor), oldMintContract), 0);
    }

    vm.stopPrank();
  }

  function test_cannot_revoke_erc20_approvals_from_current_mint_contract_revert() public {
    vm.startPrank(owner);

    address currentMintContract = address(stakingRewardsDistributor.mintContract());

    vm.expectRevert(IStakingRewardsDistributor.InvalidAddressCurrentMintContract.selector);
    stakingRewardsDistributor.revokeApprovals(assets, currentMintContract);

    for (uint256 i = 0; i < assets.length; i++) {
      assertEq(IERC20(assets[i]).allowance(address(stakingRewardsDistributor), currentMintContract), type(uint256).max);
    }

    vm.stopPrank();
  }

  function test_non_admin_cannot_revoke_erc20_approvals_revert(address notAdmin) public {
    vm.assume(notAdmin != owner);
    vm.startPrank(notAdmin);

    address currentMintContract = address(stakingRewardsDistributor.mintContract());

    vm.expectRevert("Ownable: caller is not the owner");
    stakingRewardsDistributor.revokeApprovals(assets, currentMintContract);

    for (uint256 i = 0; i < assets.length; i++) {
      assertEq(IERC20(assets[i]).allowance(address(stakingRewardsDistributor), currentMintContract), type(uint256).max);
    }

    vm.stopPrank();
  }
}
