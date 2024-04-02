// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

interface IEthenaLPStakingDefinitions {
  /// @notice information about staking for a particular LP token
  struct StakeParameters {
    uint8 epoch;
    uint248 stakeLimit;
    uint104 totalStaked; // total deposited and not in cooldown
    uint104 totalCoolingDown;
    uint48 cooldown;
  }

  /// @notice information about a particular stake by user and LP token
  struct StakeData {
    uint256 stakedAmount;
    uint152 coolingDownAmount;
    uint104 cooldownStartTimestamp;
  }

  /// @notice emitted when an epoch begins
  event NewEpoch(uint8 indexed newEpoch, uint8 indexed previousEpoch);

  /// @notice emitted when staking parameters are added/updated for an LP token
  event StakeParametersUpdated(address indexed lpToken, uint8 indexed epoch, uint248 stakeLimit, uint104 cooldown);

  /// @notice emitted when a user stakes
  event Stake(address indexed user, address indexed lpToken, uint256 amount);

  /// @notice emitted when a user unstakes
  event Unstake(address indexed user, address indexed lpToken, uint256 amount);

  /// @notice emitted when a user withdraws
  event Withdraw(address indexed user, address indexed lpToken, uint256 amount);

  /// @notice emitted when tokens are rescued by owner
  event TokensRescued(address indexed token, address indexed to, uint256 amount);

  /// @notice ownership cannot be renounced
  error CantRenounceOwnership();

  /// @notice Error returned when a user tries staking more than the limit for a given token
  error StakeLimitExceeded();

  /// @notice Error returned when staking LP token during wrong epoch
  error InvalidEpoch();

  /// @notice zero amount or amount greater than a max such as amount staked
  error InvalidAmount();

  /// @notice Error returned when native ETH transfer fails
  error TransferFailed();

  /// @notice Error returned when excess balance of an LP token is less than 0
  error InvariantBroken();

  /// @notice Error returned when owner sets cooldown > 1 year
  error MaxCooldownExceeded();

  /// @notice Error returned when user attempts to withdraw before cooldown period is over
  error CooldownNotOver();

  /// @notice This error is returned if the zero address is used
  error ZeroAddressException();
}
