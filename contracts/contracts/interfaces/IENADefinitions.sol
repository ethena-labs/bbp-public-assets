// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

interface IENADefinitions {
  /// @notice Event emitted when a new ENA token is minted (inflation) by the owner
  event Mint(address indexed to, uint256 amount);

  /// @notice This error is returned if the zero address is used
  error ZeroAddressException();
  /// @notice This error is returned if mint is called within 1 year of last mint
  error MintWaitPeriodInProgress();
  /// @notice This error is returned if the owner tries to renounce ownership
  error CantRenounceOwnership();
  /// @notice This error is returned if the max inflation rate is exceeded on mint
  error MaxInflationExceeded();
}
