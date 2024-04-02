// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

/* solhint-disable var-name-mixedcase  */

interface IEthenaMintingEvents {
  /// @notice Event emitted when contract receives ETH
  event Received(address, uint256);

  /// @notice Event emitted when USDe is minted
  event Mint(
    address indexed minter,
    address indexed benefactor,
    address indexed beneficiary,
    address collateral_asset,
    uint256 collateral_amount,
    uint256 usde_amount
  );

  /// @notice Event emitted when funds are redeemed
  event Redeem(
    address indexed redeemer,
    address indexed benefactor,
    address indexed beneficiary,
    address collateral_asset,
    uint256 collateral_amount,
    uint256 usde_amount
  );

  /// @notice Event emitted when a supported asset is added
  event AssetAdded(address indexed asset);

  /// @notice Event emitted when a supported asset is removed
  event AssetRemoved(address indexed asset);

  // @notice Event emitted when a custodian address is added
  event CustodianAddressAdded(address indexed custodian);

  // @notice Event emitted when a custodian address is removed
  event CustodianAddressRemoved(address indexed custodian);

  /// @notice Event emitted when assets are moved to custody provider wallet
  event CustodyTransfer(address indexed wallet, address indexed asset, uint256 amount);

  /// @notice Event emitted when USDe is set
  event USDeSet(address indexed USDe);

  /// @notice Event emitted when the max mint per block is changed
  event MaxMintPerBlockChanged(uint256 oldMaxMintPerBlock, uint256 newMaxMintPerBlock);

  /// @notice Event emitted when the max redeem per block is changed
  event MaxRedeemPerBlockChanged(uint256 oldMaxRedeemPerBlock, uint256 newMaxRedeemPerBlock);

  /// @notice Event emitted when a delegated signer is added, enabling it to sign orders on behalf of another address
  event DelegatedSignerAdded(address indexed signer, address indexed delegator);

  /// @notice Event emitted when a delegated signer is removed
  event DelegatedSignerRemoved(address indexed signer, address indexed delegator);

  /// @notice Event emitted when a delegated signer is initiated
  event DelegatedSignerInitiated(address indexed signer, address indexed delegator);
}
