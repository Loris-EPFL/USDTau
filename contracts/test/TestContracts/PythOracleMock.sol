// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../../src/Dependencies/AggregatorV3Interface.sol";

/**
 * @title PythOracleMock
 * @dev A mock oracle that implements AggregatorV3Interface for testing
 * This allows us to use the same vm.etch pattern as ChainlinkOracleMock
 * while having full control over price and staleness for testing
 */
contract PythOracleMock is AggregatorV3Interface {
    uint8 private _decimals;
    int256 private _price;
    uint256 private _updatedAt;
    uint80 private _roundId;
    
    constructor() {
        _decimals = 8; // Default to 8 decimals like Chainlink
        _price = 0;
        _updatedAt = block.timestamp;
        _roundId = 1;
    }
    
    /**
     * @dev Returns the number of decimals used by the price feed
     */
    function decimals() external view override returns (uint8) {
        return _decimals;
    }
    
    /**
     * @dev Returns the description of the price feed
     */
    function description() external pure returns (string memory) {
        return "Mock Pyth Oracle";
    }
    
    /**
     * @dev Returns the version of the price feed
     */
    function version() external pure returns (uint256) {
        return 1;
    }
    
    /**
     * @dev Returns the latest round data
     */
    function latestRoundData()
        external
        view
        override
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        return (_roundId, _price, _updatedAt, _updatedAt, _roundId);
    }
    
    /**
     * @dev Returns round data for a specific round ID
     */
    function getRoundData(uint80 _roundId_)
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        return (_roundId_, _price, _updatedAt, _updatedAt, _roundId_);
    }
    
    // Mock configuration functions
    
    /**
     * @dev Sets the number of decimals
     */
    function setDecimals(uint8 decimals_) external {
        _decimals = decimals_;
    }
    
    /**
     * @dev Sets the price
     */
    function setPrice(int256 price_) external {
        _price = price_;
        _roundId++;
    }
    
    /**
     * @dev Sets the updated timestamp
     */
    function setUpdatedAt(uint256 updatedAt_) external {
        _updatedAt = updatedAt_;
    }
    
    /**
     * @dev Sets the round ID
     */
    function setRoundId(uint80 roundId_) external {
        _roundId = roundId_;
    }
    
    /**
     * @dev Initialize with stale data for testing
     */
    function initializeStale() external {
        _decimals = 8;
        _price = 500 * 10**8; // 500 USD
        _updatedAt = block.timestamp - 7 days; // 7 days old
        _roundId = 1;
    }
    
    /**
     * @dev Initialize with fresh data for testing
     */
    function initializeFresh() external {
        _decimals = 8;
        _price = 500 * 10**8; // 500 USD
        _updatedAt = block.timestamp; // Current timestamp
        _roundId = 1;
    }
}