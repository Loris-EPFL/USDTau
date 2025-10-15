// SPDX-License-Identifier: MIT
import "./ITAOPriceFeed.sol";
import "../Dependencies/AggregatorV3Interface.sol";

pragma solidity ^0.8.0;

interface IVTAOPriceFeed is ITAOPriceFeed {
    function vTaoUsdOracle() external view returns (AggregatorV3Interface, uint256, uint8);
}