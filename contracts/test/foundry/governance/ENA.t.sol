// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "forge-std/console.sol";
import "ds-test/test.sol";
import "forge-std/Test.sol";
import "../../../test/utils/SigUtils.sol";

import "../../../contracts/ENA.sol";
import "../../../contracts/interfaces/IENADefinitions.sol";

/**
 * solhint-disable private-vars-leading-underscore
 */

contract ENATest is DSTest, Test, IENADefinitions {
  ENA public ena;
  SigUtils public sigUtils;

  address public owner;
  address public newOwner;
  address public treasury;
  address public foundation;
  address public alice;
  uint256 public treasuryPk;
  uint256 public foundationPk;
  address public bob;
  address public greg;

  uint256 constant TREASURY_MINT = 3_750_000_000 * 10 ** 18;
  uint256 constant FOUNDATION_MINT = 11_250_000_000 * 10 ** 18;
  uint256 constant TOTAL_SUPPLY = TREASURY_MINT + FOUNDATION_MINT;
  uint256 constant MAX_INFLATION = 10;
  uint256 constant TEST_MINT_SIZE = 10_000_000 * 10 ** 18;

  function setUp() public virtual {
    treasuryPk = 0xB44DE;
    foundationPk = 0xB44DA;
    alice = vm.addr(0x1DEA);
    bob = vm.addr(0x1DE);
    greg = vm.addr(0x6ED);
    owner = vm.addr(0xA11CE);
    treasury = vm.addr(treasuryPk);
    foundation = vm.addr(foundationPk);
    vm.label(alice, "alice");
    vm.label(bob, "bob");
    vm.label(greg, "greg");
    vm.label(owner, "owner");
    vm.label(treasury, "treasury");
    vm.label(foundation, "foundation");

    ena = new ENA(owner, treasury, foundation);

    sigUtils = new SigUtils(ena.DOMAIN_SEPARATOR());
  }

  function testDeploy() public {
    assertEq(ena.owner(), owner);
    assertEq(ena.balanceOf(treasury), TREASURY_MINT);
    assertEq(ena.balanceOf(foundation), FOUNDATION_MINT);
    assertEq(ena.totalSupply(), TREASURY_MINT + FOUNDATION_MINT);
    assertEq(ena.balanceOf(owner), 0);
    assertEq(ena.balanceOf(address(this)), 0);
    assertEq(ena.decimals(), 18);
    assertEq(ena.lastMintTimestamp(), block.timestamp);
    assertEq(ena.MAX_INFLATION(), 10);
  }

  function testCantMintBeforeWait() public {
    vm.expectRevert(MintWaitPeriodInProgress.selector);
    vm.prank(owner);
    ena.mint(owner, TEST_MINT_SIZE);
    assertEq(ena.balanceOf(owner), 0);
    assertEq(ena.totalSupply(), TOTAL_SUPPLY);
  }

  function testCanMintAfterWait() public {
    vm.warp(block.timestamp + 365 days);
    vm.prank(owner);
    vm.expectEmit(true, true, true, true);
    emit Mint(owner, TEST_MINT_SIZE);
    ena.mint(owner, TEST_MINT_SIZE);
    assertEq(ena.balanceOf(owner), TEST_MINT_SIZE);
    assertEq(ena.totalSupply(), TEST_MINT_SIZE + TOTAL_SUPPLY);
  }

  function testCantMintMoreThanMaxInflation() public {
    vm.warp(block.timestamp + 365 days);
    vm.expectRevert(MaxInflationExceeded.selector);
    vm.prank(owner);
    ena.mint(owner, TOTAL_SUPPLY * MAX_INFLATION / 100 + 1);
    assertEq(ena.balanceOf(owner), 0);
    assertEq(ena.totalSupply(), TOTAL_SUPPLY);
  }

  function testCanMintUpToMaxInflation() public {
    uint256 maxMintBelowMaxInflation = TOTAL_SUPPLY * MAX_INFLATION / 100;
    vm.warp(block.timestamp + 365 days);
    vm.prank(owner);
    ena.mint(owner, maxMintBelowMaxInflation);
    assertEq(ena.balanceOf(owner), maxMintBelowMaxInflation);
    assertEq(ena.totalSupply(), TOTAL_SUPPLY + maxMintBelowMaxInflation);
  }

  function testCantMintMoreThanOncePerYear() public {
    vm.warp(block.timestamp + 365 days);
    vm.startPrank(owner);
    ena.mint(owner, TEST_MINT_SIZE);
    assertEq(ena.balanceOf(owner), TEST_MINT_SIZE);
    assertEq(ena.totalSupply(), TEST_MINT_SIZE + TOTAL_SUPPLY);
    vm.expectRevert(MintWaitPeriodInProgress.selector);
    ena.mint(owner, TEST_MINT_SIZE);
    assertEq(ena.balanceOf(owner), TEST_MINT_SIZE);
    assertEq(ena.totalSupply(), TEST_MINT_SIZE + TOTAL_SUPPLY);
    vm.warp(block.timestamp + 364 days);
    vm.expectRevert(MintWaitPeriodInProgress.selector);
    ena.mint(owner, TEST_MINT_SIZE);
    assertEq(ena.balanceOf(owner), TEST_MINT_SIZE);
    assertEq(ena.totalSupply(), TEST_MINT_SIZE + TOTAL_SUPPLY);
    vm.warp(block.timestamp + 1 days);
    ena.mint(owner, TEST_MINT_SIZE);
    assertEq(ena.balanceOf(owner), TEST_MINT_SIZE * 2);
    assertEq(ena.totalSupply(), TEST_MINT_SIZE * 2 + TOTAL_SUPPLY);
  }

  function testCantMintFromNonOwner() public {
    vm.warp(block.timestamp + 365 days);
    vm.expectRevert("Ownable: caller is not the owner");
    vm.prank(alice);
    ena.mint(alice, 10_000_000 * 10 ** 18);
    assertEq(ena.balanceOf(alice), 0);
    assertEq(ena.totalSupply(), TREASURY_MINT + FOUNDATION_MINT);
  }

  function testFuzzNoOneOtherThanOwnerCanMint(address nonOwner) public {
    vm.assume(nonOwner != owner);
    vm.assume(nonOwner != treasury);
    vm.warp(block.timestamp + 365 days);
    vm.expectRevert("Ownable: caller is not the owner");
    vm.startPrank(nonOwner);
    ena.mint(nonOwner, TEST_MINT_SIZE);
    vm.expectRevert("Ownable: caller is not the owner");
    ena.mint(treasury, TEST_MINT_SIZE);
    if (nonOwner != foundation) {
      assertEq(ena.balanceOf(nonOwner), 0);
    } else {
      assertEq(ena.balanceOf(nonOwner), FOUNDATION_MINT);
    }
    assertEq(ena.totalSupply(), TOTAL_SUPPLY);
  }

  // test burning
  function testCanBurn() public {
    vm.prank(treasury);
    ena.burn(TEST_MINT_SIZE);
    assertEq(ena.balanceOf(treasury), TREASURY_MINT - TEST_MINT_SIZE);
    assertEq(ena.totalSupply(), TOTAL_SUPPLY - TEST_MINT_SIZE);
  }

  function testBurnFrom() public {
    vm.prank(treasury);
    ena.approve(alice, TEST_MINT_SIZE);
    vm.prank(alice);
    ena.burnFrom(treasury, TEST_MINT_SIZE);
    assertEq(ena.balanceOf(treasury), TREASURY_MINT - TEST_MINT_SIZE);
    assertEq(ena.balanceOf(foundation), FOUNDATION_MINT);
    assertEq(ena.totalSupply(), TOTAL_SUPPLY - TEST_MINT_SIZE);
  }

  function testBurnFromWithoutApprovalFails() public {
    vm.expectRevert("ERC20: insufficient allowance");
    vm.prank(alice);
    ena.burnFrom(treasury, 10_000_000 * 10 ** 18);
    assertEq(ena.balanceOf(treasury), TREASURY_MINT);
    assertEq(ena.totalSupply(), TOTAL_SUPPLY);
  }

  // test permit
  function testBurnFromWithPermit() public {
    uint256 timestamp = block.timestamp + 1000;
    SigUtils.Permit memory _permit =
      SigUtils.Permit({owner: treasury, spender: alice, value: TEST_MINT_SIZE, nonce: 0, deadline: timestamp});
    bytes32 digest = sigUtils.getTypedDataHash(_permit);
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(treasuryPk, digest);
    vm.startPrank(alice);
    ena.permit(treasury, alice, TEST_MINT_SIZE, timestamp, v, r, s);
    ena.burnFrom(treasury, TEST_MINT_SIZE);
    assertEq(ena.balanceOf(treasury), TREASURY_MINT - TEST_MINT_SIZE);
    assertEq(ena.balanceOf(foundation), FOUNDATION_MINT);
    assertEq(ena.totalSupply(), TOTAL_SUPPLY - TEST_MINT_SIZE);
  }

  function testBurnFromWithInvalidPermit() public {
    uint256 timestamp = block.timestamp + 1000;
    SigUtils.Permit memory _permit =
      SigUtils.Permit({owner: treasury, spender: alice, value: TEST_MINT_SIZE, nonce: 0, deadline: timestamp});
    bytes32 digest = sigUtils.getTypedDataHash(_permit);
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(0x34982, digest);
    vm.startPrank(alice);
    vm.expectRevert("ERC20Permit: invalid signature");
    ena.permit(treasury, alice, TEST_MINT_SIZE, timestamp, v, r, s);
    vm.expectRevert("ERC20: insufficient allowance");
    ena.burnFrom(treasury, TEST_MINT_SIZE);
    assertEq(ena.balanceOf(treasury), TREASURY_MINT);
    assertEq(ena.balanceOf(foundation), FOUNDATION_MINT);
    assertEq(ena.totalSupply(), TOTAL_SUPPLY);
  }

  // test ownership transfers
  function testCantInitWithNoOwner() public {
    vm.expectRevert(ZeroAddressException.selector);
    new ENA(address(0), treasury, foundation);
  }

  function testCantInitWithNoTreasury() public {
    vm.expectRevert(ZeroAddressException.selector);
    new ENA(owner, address(0), foundation);
  }

  function testCantInitWithNoFoundation() public {
    vm.expectRevert(ZeroAddressException.selector);
    new ENA(owner, treasury, address(0));
  }

  function testOwnershipCannotBeRenounced() public {
    vm.prank(owner);
    vm.expectRevert(CantRenounceOwnership.selector);
    ena.renounceOwnership();
    assertEq(ena.owner(), owner);
    assertNotEq(ena.owner(), address(0));
  }

  function testOwnershipTransferRequiresTwoSteps() public {
    vm.prank(owner);
    ena.transferOwnership(bob);
    assertEq(ena.owner(), owner);
    assertNotEq(ena.owner(), bob);
  }

  function testCanTransferOwnership() public {
    vm.prank(owner);
    ena.transferOwnership(bob);
    vm.prank(bob);
    ena.acceptOwnership();
    assertEq(ena.owner(), bob);
    assertNotEq(ena.owner(), owner);
  }

  function testCanCancelOwnershipChange() public {
    vm.startPrank(owner);
    ena.transferOwnership(bob);
    ena.transferOwnership(address(0));
    vm.stopPrank();

    vm.prank(bob);
    vm.expectRevert("Ownable2Step: caller is not the new owner");
    ena.acceptOwnership();
    assertEq(ena.owner(), owner);
    assertNotEq(ena.owner(), bob);
  }

  // test owner can be inittreasury
  function testOwnerCanBeTreasury() public {
    ENA _ena = new ENA(treasury, treasury, foundation);
    assertEq(_ena.owner(), treasury);
    assertEq(_ena.balanceOf(_ena.owner()), TREASURY_MINT);
  }
}
