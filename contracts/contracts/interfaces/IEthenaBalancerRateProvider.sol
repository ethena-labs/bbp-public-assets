// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

/**
 * @dev Interface for EthenaBalancerRateProvider
 */
interface IEthenaBalancerRateProvider {
  /// @notice Error emitted when contract instantiated with no sUSDe address
  error ZeroAddressException();

  /**
   * @notice Returns the USDe per sUSDe
   */
  function getRate() external view returns (uint256);
}
