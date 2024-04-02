// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "../EthenaMinting.sol";

interface IStakingRewardsDistributor {
  // Events //
  /// @notice Event emitted when tokens are rescued by owner
  event TokensRescued(address indexed token, address indexed to, uint256 amount);
  /// @notice This event is fired when the operator changes
  event OperatorUpdated(address indexed newOperator, address indexed previousOperator);
  /// @notice This event is fired when the mint contract changes
  event MintingContractUpdated(address indexed newMintingContract, address indexed previousMintingContract);

  // Errors //
  /// @notice Error emitted when there is not a single asset at constructor time
  error NoAssetsProvided();
  /// @notice Error emitted when the address(0) is passed as an argument
  error InvalidZeroAddress();
  /// @notice Error emitted when the amount is equal to 0
  error InvalidAmount();
  /// @notice Error emitted when the address to revoke ERC20 approvals from is the actual minting contract
  error InvalidAddressCurrentMintContract();
  /// @notice Error returned when native ETH transfer fails
  error TransferFailed();
  /// @notice It's not possible to renounce the ownership
  error CantRenounceOwnership();
  /// @notice Only the current operator can perform an action
  error OnlyOperator();
  /// @notice Insufficient funds to transfer to the staking contract
  error InsufficientFunds();

  function transferInRewards(uint256 _rewardsAmount) external;

  function rescueTokens(address _token, address _to, uint256 _amount) external;

  function setOperator(address _newOperator) external;

  function setMintingContract(EthenaMinting _newMintingContract) external;

  function approveToMintContract(address[] memory _assets) external;
}
