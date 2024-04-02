// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "./interfaces/IENADefinitions.sol";

/**
 * @title ENA
 * @notice Governance token for the Ethena protocol
 */
contract ENA is Ownable2Step, ERC20Burnable, ERC20Permit, IENADefinitions {
  /// @notice Maximum inflation rate per year (percentage) expressed as an integer
  uint8 public constant MAX_INFLATION = 10;

  /// @notice The maximum frequency of inflationary mint invocations
  uint32 public constant MINT_WAIT_PERIOD = 365 days;

  /// @notice The last time the mint function was called
  uint40 public lastMintTimestamp;

  constructor(address _initialOwner, address _treasury, address _foundation) ERC20("ENA", "ENA") ERC20Permit("ENA") {
    // first mint not allowed until 1 year after deployment
    lastMintTimestamp = uint40(block.timestamp);
    if (_initialOwner == address(0) || _treasury == address(0) || _foundation == address(0)) {
      revert ZeroAddressException();
    }
    _transferOwnership(_initialOwner);
    // initial supply of 15 billion tokens
    _mint(_treasury, 3_750_000_000 * 10 ** 18);
    _mint(_foundation, 11_250_000_000 * 10 ** 18);
  }

  /**
   * @notice Mints new ENA tokens
   * @param to The address to mint tokens to
   * @param amount The amount of tokens to mint
   * @dev Only callable by the owner once per year and amount must be less than max inflation rate
   */
  function mint(address to, uint256 amount) external onlyOwner {
    if (block.timestamp - lastMintTimestamp < MINT_WAIT_PERIOD) revert MintWaitPeriodInProgress();
    uint256 _maxInflationAmount = totalSupply() * MAX_INFLATION / 100;
    if (amount > _maxInflationAmount) revert MaxInflationExceeded();
    lastMintTimestamp = uint40(block.timestamp);
    _mint(to, amount);
    emit Mint(to, amount);
  }

  /// @notice Prevents the owner from renouncing ownership
  function renounceOwnership() public view override onlyOwner {
    revert CantRenounceOwnership();
  }
}
