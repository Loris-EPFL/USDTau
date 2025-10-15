// SPDX-License-Identifier: MIT
import "../Interfaces/IPriceFeed.sol";
import "../Dependencies/AggregatorV3Interface.sol";
import "../Interfaces/IMainnetPriceFeed.sol";

pragma solidity ^0.8.0;

interface ITAOPriceFeed is IPriceFeed {
    function taoUsdOracle() external view returns (AggregatorV3Interface, uint256, uint8);
}