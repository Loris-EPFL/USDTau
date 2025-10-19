// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../../src/Dependencies/AggregatorV3Interface.sol";

/**
 * @title PythMockWrapper
 * @dev A simple mock that implements AggregatorV3Interface for testing
 * This allows us to use the same vm.etch pattern as ChainlinkOracleMock
 * without the complexity of wrapping MockPyth
 */
contract PythMockWrapper is AggregatorV3Interface {
    uint8 private _decimals;
    int256 private _price;
    uint256 private _updatedAt;
    
    constructor() {
        _decimals = 8; // Default to 8 decimals like Chainlink
        _updatedAt = block.timestamp;
    }
    
    /**
     * @dev Returns the number of decimals used by the price feed
     */
    function decimals() external view returns (uint8) {
        return _decimals;
    }
    
    /**
     * @dev Returns the latest round data
     * This mimics ChainlinkOracleMock's behavior for easy testing
     */
    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        return (1, _price, _updatedAt, _updatedAt, 1);
    }
    
    /**
     * @dev Set the number of decimals (matches ChainlinkOracleMock interface)
     */
    function setDecimals(uint8 decimals_) external {
        _decimals = decimals_;
    }
    
    /**
     * @dev Set the price (matches ChainlinkOracleMock interface)
     */
    function setPrice(int256 price_) external {
        _price = price_;
    }
    
    /**
     * @dev Set the updated timestamp (matches ChainlinkOracleMock interface)
     */
    function setUpdatedAt(uint256 updatedAt_) external {
        _updatedAt = updatedAt_;
    }
    
    /**
     * @dev Initialize with stale data (convenience function for tests)
     */
    function initializeStale(int256 price_, uint8 decimals_) external {
        _price = price_;
        _decimals = decimals_;
        _updatedAt = block.timestamp - 7 days; // Make it stale
    }
    
    /**
     * @dev Initialize with fresh data (convenience function for tests)
     */
    function initializeFresh(int256 price_, uint8 decimals_) external {
        _price = price_;
        _decimals = decimals_;
        _updatedAt = block.timestamp; // Make it fresh
    }
}