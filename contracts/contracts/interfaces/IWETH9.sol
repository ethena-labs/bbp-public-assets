// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.20;

interface IWETH9 {
  function deposit() external payable;
  function withdraw(uint256 wad) external payable;
  function totalSupply() external returns (uint256);
  function approve(address guy, uint256 wad) external returns (bool);
}
