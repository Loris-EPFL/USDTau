// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "src/Dependencies/AggregatorV3Interface.sol";

// Mock Pyth oracle that implements AggregatorV3Interface for testing
// This mock can capture the real oracle's price initially and then become stale
contract PythAggregatorV3Mock is AggregatorV3Interface {
    uint8 decimal;
    int256 price;
    uint256 lastUpdateTime;

    // We use 8 decimals unless set to 18
    function decimals() external view returns (uint8) {
        return decimal;
    }

    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        return (1, int256(price), lastUpdateTime, lastUpdateTime, 1);
    }

    function setDecimals(uint8 _decimals) external {
        decimal = _decimals;
    }

    function setPrice(int256 _price) external {
        price = _price;
    }

    function setUpdatedAt(uint256 _updatedAt) external {
        lastUpdateTime = _updatedAt;
    }

    // Initialize the mock with data from a real oracle, then make it stale
    function initializeFromOracle(AggregatorV3Interface _realOracle) external {
        // Get current data from the real oracle
        (,int256 realPrice,,uint256 realUpdatedAt,) = _realOracle.latestRoundData();
        uint8 realDecimals = _realOracle.decimals();
        
        // Set the mock to use the real oracle's current data
        decimal = realDecimals;
        price = realPrice;
        lastUpdateTime = realUpdatedAt;
    }

    // Make the oracle stale by setting timestamp to 7 days ago
    function makeStale() external {
        lastUpdateTime = block.timestamp - 7 days;
    }
}