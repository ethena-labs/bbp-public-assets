// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../EthenaMinting.utils.sol";

contract EthenaMintingDelegateTest is EthenaMintingUtils {
  function setUp() public override {
    super.setUp();
  }

  function testDelegateSuccessfulMint() public {
    (IEthenaMinting.Order memory order,, IEthenaMinting.Route memory route) =
      mint_setup(_usdeToMint, _stETHToDeposit, stETHToken, 1, false);

    // request delegation
    vm.prank(benefactor);
    vm.expectEmit();
    emit DelegatedSignerInitiated(trader2, benefactor);
    EthenaMintingContract.setDelegatedSigner(trader2);

    assertEq(
      uint256(EthenaMintingContract.delegatedSigner(trader2, benefactor)),
      uint256(IEthenaMinting.DelegatedSignerStatus.PENDING),
      "The delegation status should be pending"
    );

    bytes32 digest1 = EthenaMintingContract.hashOrder(order);

    // accept delegation
    vm.prank(trader2);
    vm.expectEmit();
    emit DelegatedSignerAdded(trader2, benefactor);
    EthenaMintingContract.confirmDelegatedSigner(benefactor);

    assertEq(
      uint256(EthenaMintingContract.delegatedSigner(trader2, benefactor)),
      uint256(IEthenaMinting.DelegatedSignerStatus.ACCEPTED),
      "The delegation status should be accepted"
    );

    IEthenaMinting.Signature memory trader2Sig =
      signOrder(trader2PrivateKey, digest1, IEthenaMinting.SignatureType.EIP712);

    assertEq(
      stETHToken.balanceOf(address(EthenaMintingContract)), 0, "Mismatch in Minting contract stETH balance before mint"
    );
    assertEq(stETHToken.balanceOf(benefactor), _stETHToDeposit, "Mismatch in benefactor stETH balance before mint");
    assertEq(usdeToken.balanceOf(beneficiary), 0, "Mismatch in beneficiary USDe balance before mint");

    vm.prank(minter);
    EthenaMintingContract.mint(order, route, trader2Sig);

    assertEq(
      stETHToken.balanceOf(address(EthenaMintingContract)),
      _stETHToDeposit,
      "Mismatch in Minting contract stETH balance after mint"
    );
    assertEq(stETHToken.balanceOf(beneficiary), 0, "Mismatch in beneficiary stETH balance after mint");
    assertEq(usdeToken.balanceOf(beneficiary), _usdeToMint, "Mismatch in beneficiary USDe balance after mint");
  }

  function testDelegateFailureMint() public {
    (IEthenaMinting.Order memory order,, IEthenaMinting.Route memory route) =
      mint_setup(_usdeToMint, _stETHToDeposit, stETHToken, 1, false);

    bytes32 digest1 = EthenaMintingContract.hashOrder(order);
    vm.prank(trader2);
    IEthenaMinting.Signature memory trader2Sig =
      signOrder(trader2PrivateKey, digest1, IEthenaMinting.SignatureType.EIP712);

    assertEq(
      stETHToken.balanceOf(address(EthenaMintingContract)), 0, "Mismatch in Minting contract stETH balance before mint"
    );
    assertEq(stETHToken.balanceOf(benefactor), _stETHToDeposit, "Mismatch in benefactor stETH balance before mint");
    assertEq(usdeToken.balanceOf(beneficiary), 0, "Mismatch in beneficiary USDe balance before mint");

    // assert that the delegation is rejected
    assertEq(
      uint256(EthenaMintingContract.delegatedSigner(minter, trader2)),
      uint256(IEthenaMinting.DelegatedSignerStatus.REJECTED),
      "The delegation status should be rejected"
    );

    vm.prank(minter);
    vm.expectRevert(InvalidSignature);
    EthenaMintingContract.mint(order, route, trader2Sig);

    assertEq(
      stETHToken.balanceOf(address(EthenaMintingContract)), 0, "Mismatch in Minting contract stETH balance after mint"
    );
    assertEq(stETHToken.balanceOf(benefactor), _stETHToDeposit, "Mismatch in beneficiary stETH balance after mint");
    assertEq(usdeToken.balanceOf(beneficiary), 0, "Mismatch in beneficiary USDe balance after mint");
  }

  function testDelegateSuccessfulRedeem() public {
    (IEthenaMinting.Order memory order,) = redeem_setup(_usdeToMint, _stETHToDeposit, stETHToken, 1, false);

    // request delegation
    vm.prank(beneficiary);
    vm.expectEmit();
    emit DelegatedSignerInitiated(trader2, beneficiary);
    EthenaMintingContract.setDelegatedSigner(trader2);

    assertEq(
      uint256(EthenaMintingContract.delegatedSigner(trader2, beneficiary)),
      uint256(IEthenaMinting.DelegatedSignerStatus.PENDING),
      "The delegation status should be pending"
    );

    bytes32 digest1 = EthenaMintingContract.hashOrder(order);

    // accept delegation
    vm.prank(trader2);
    vm.expectEmit();
    emit DelegatedSignerAdded(trader2, beneficiary);
    EthenaMintingContract.confirmDelegatedSigner(beneficiary);

    assertEq(
      uint256(EthenaMintingContract.delegatedSigner(trader2, beneficiary)),
      uint256(IEthenaMinting.DelegatedSignerStatus.ACCEPTED),
      "The delegation status should be accepted"
    );

    IEthenaMinting.Signature memory trader2Sig =
      signOrder(trader2PrivateKey, digest1, IEthenaMinting.SignatureType.EIP712);

    assertEq(
      stETHToken.balanceOf(address(EthenaMintingContract)),
      _stETHToDeposit,
      "Mismatch in Minting contract stETH balance before mint"
    );
    assertEq(stETHToken.balanceOf(beneficiary), 0, "Mismatch in beneficiary stETH balance before mint");
    assertEq(usdeToken.balanceOf(beneficiary), _usdeToMint, "Mismatch in beneficiary USDe balance before mint");

    vm.prank(redeemer);
    EthenaMintingContract.redeem(order, trader2Sig);

    assertEq(
      stETHToken.balanceOf(address(EthenaMintingContract)), 0, "Mismatch in Minting contract stETH balance after mint"
    );
    assertEq(stETHToken.balanceOf(beneficiary), _stETHToDeposit, "Mismatch in beneficiary stETH balance after mint");
    assertEq(usdeToken.balanceOf(beneficiary), 0, "Mismatch in beneficiary USDe balance after mint");
  }

  function testDelegateFailureRedeem() public {
    (IEthenaMinting.Order memory order,) = redeem_setup(_usdeToMint, _stETHToDeposit, stETHToken, 1, false);

    bytes32 digest1 = EthenaMintingContract.hashOrder(order);
    vm.prank(trader2);
    IEthenaMinting.Signature memory trader2Sig =
      signOrder(trader2PrivateKey, digest1, IEthenaMinting.SignatureType.EIP712);

    assertEq(
      stETHToken.balanceOf(address(EthenaMintingContract)),
      _stETHToDeposit,
      "Mismatch in Minting contract stETH balance before mint"
    );
    assertEq(stETHToken.balanceOf(beneficiary), 0, "Mismatch in beneficiary stETH balance before mint");
    assertEq(usdeToken.balanceOf(beneficiary), _usdeToMint, "Mismatch in beneficiary USDe balance before mint");

    // assert that the delegation is rejected
    assertEq(
      uint256(EthenaMintingContract.delegatedSigner(redeemer, trader2)),
      uint256(IEthenaMinting.DelegatedSignerStatus.REJECTED),
      "The delegation status should be rejected"
    );

    vm.prank(redeemer);
    vm.expectRevert(InvalidSignature);
    EthenaMintingContract.redeem(order, trader2Sig);

    assertEq(
      stETHToken.balanceOf(address(EthenaMintingContract)),
      _stETHToDeposit,
      "Mismatch in Minting contract stETH balance after mint"
    );
    assertEq(stETHToken.balanceOf(beneficiary), 0, "Mismatch in beneficiary stETH balance after mint");
    assertEq(usdeToken.balanceOf(beneficiary), _usdeToMint, "Mismatch in beneficiary USDe balance after mint");
  }

  function testCanUndelegate() public {
    (IEthenaMinting.Order memory order,, IEthenaMinting.Route memory route) =
      mint_setup(_usdeToMint, _stETHToDeposit, stETHToken, 1, false);

    // delegate request
    vm.prank(benefactor);
    vm.expectEmit();
    emit DelegatedSignerInitiated(trader2, benefactor);
    EthenaMintingContract.setDelegatedSigner(trader2);

    assertEq(
      uint256(EthenaMintingContract.delegatedSigner(trader2, benefactor)),
      uint256(IEthenaMinting.DelegatedSignerStatus.PENDING),
      "The delegation status should be pending"
    );

    // accept the delegation
    vm.prank(trader2);
    vm.expectEmit();
    emit DelegatedSignerAdded(trader2, benefactor);
    EthenaMintingContract.confirmDelegatedSigner(benefactor);

    assertEq(
      uint256(EthenaMintingContract.delegatedSigner(trader2, benefactor)),
      uint256(IEthenaMinting.DelegatedSignerStatus.ACCEPTED),
      "The delegation status should be accepted"
    );

    // remove the delegation
    vm.prank(benefactor);
    vm.expectEmit();
    emit DelegatedSignerRemoved(trader2, benefactor);
    EthenaMintingContract.removeDelegatedSigner(trader2);

    assertEq(
      uint256(EthenaMintingContract.delegatedSigner(trader2, benefactor)),
      uint256(IEthenaMinting.DelegatedSignerStatus.REJECTED),
      "The delegation status should be accepted"
    );

    bytes32 digest1 = EthenaMintingContract.hashOrder(order);
    vm.prank(trader2);
    IEthenaMinting.Signature memory trader2Sig =
      signOrder(trader2PrivateKey, digest1, IEthenaMinting.SignatureType.EIP712);

    assertEq(
      stETHToken.balanceOf(address(EthenaMintingContract)), 0, "Mismatch in Minting contract stETH balance before mint"
    );
    assertEq(stETHToken.balanceOf(benefactor), _stETHToDeposit, "Mismatch in benefactor stETH balance before mint");
    assertEq(usdeToken.balanceOf(beneficiary), 0, "Mismatch in beneficiary USDe balance before mint");

    vm.prank(minter);
    vm.expectRevert(InvalidSignature);
    EthenaMintingContract.mint(order, route, trader2Sig);

    assertEq(
      stETHToken.balanceOf(address(EthenaMintingContract)), 0, "Mismatch in Minting contract stETH balance after mint"
    );
    assertEq(stETHToken.balanceOf(benefactor), _stETHToDeposit, "Mismatch in beneficiary stETH balance after mint");
    assertEq(usdeToken.balanceOf(beneficiary), 0, "Mismatch in beneficiary USDe balance after mint");
  }
}
