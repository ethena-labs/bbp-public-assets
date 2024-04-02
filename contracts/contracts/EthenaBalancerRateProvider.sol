// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import "./StakedUSDeV2.sol";
import "./interfaces/IEthenaBalancerRateProvider.sol";

/**
 * @title EthenaBalancerRateProvider
 * @notice Exposes a getRate function to enable sUSDe use in the Balancer protocol
 */
contract EthenaBalancerRateProvider is IEthenaBalancerRateProvider {
  /// @notice StakedUSDe contract that this rate provider is for
  StakedUSDeV2 public immutable stakedUSDe;

  constructor(address _stakedUSDeAddress) {
    if (_stakedUSDeAddress == address(0)) revert ZeroAddressException();
    stakedUSDe = StakedUSDeV2(_stakedUSDeAddress);
  }

  /**
   * @notice Returns the USDe per sUSDe
   */
  function getRate() external view returns (uint256) {
    uint256 _totalSupply = stakedUSDe.totalSupply();
    if (_totalSupply == 0) {
      return 0;
    } else {
      return stakedUSDe.totalAssets() * 1 ether / _totalSupply;
    }
  }
}
