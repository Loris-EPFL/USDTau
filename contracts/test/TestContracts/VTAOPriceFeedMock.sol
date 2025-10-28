// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "src/PriceFeeds/PythVTAOPriceFeed.sol";
import "src/PriceFeeds/PythWTAOPriceFeed.sol";
import "src/Interfaces/IMainnetPriceFeed.sol";
import "src/Dependencies/AggregatorV3Interface.sol";

// Mock VTAO price feed that implements IVTAOPriceFeed for testing
// This mock can control oracle failure behavior and price source state
contract VTAOPriceFeedMock is IVTAOPriceFeed {
    uint256 private _lastGoodPrice;
    IMainnetPriceFeed.PriceSource private _priceSource;
    bool private _shouldOracleFail;
    
    AggregatorV3Interface private _taoUsdAggregator;
    AggregatorV3Interface private _vTaoUsdAggregator;
    uint256 private _taoUsdStalenessThreshold;
    uint256 private _vTaoUsdStalenessThreshold;
    uint8 private _taoUsdDecimals;
    uint8 private _vTaoUsdDecimals;

    constructor() {
        _priceSource = IMainnetPriceFeed.PriceSource.primary;
        _shouldOracleFail = false;
        _taoUsdStalenessThreshold = 3600; // 1 hour
        _vTaoUsdStalenessThreshold = 3600; // 1 hour
        _taoUsdDecimals = 8;
        _vTaoUsdDecimals = 8;
    }

    // IPriceFeed interface methods
    function fetchPrice() external returns (uint256, bool) {
        if (_shouldOracleFail) {
            _priceSource = IMainnetPriceFeed.PriceSource.lastGoodPrice;
            return (_lastGoodPrice, true); // Return true to indicate oracle failed
        }
        
        _priceSource = IMainnetPriceFeed.PriceSource.primary;
        return (_lastGoodPrice, false); // Return false to indicate oracle succeeded
    }

    function fetchRedemptionPrice() external returns (uint256, bool) {
        return this.fetchPrice();
    }

    function lastGoodPrice() external view returns (uint256) {
        return _lastGoodPrice;
    }

    // IMainnetPriceFeed interface methods
    function ethUsdOracle() external view returns (AggregatorV3Interface, uint256, uint8) {
        return (_taoUsdAggregator, _taoUsdStalenessThreshold, _taoUsdDecimals);
    }

    function priceSource() external view returns (IMainnetPriceFeed.PriceSource) {
        return _priceSource;
    }

    // ITAOPriceFeed interface methods
    function taoUsdOracle() external view returns (AggregatorV3Interface, uint256, uint8) {
        return (_taoUsdAggregator, _taoUsdStalenessThreshold, _taoUsdDecimals);
    }

    // IVTAOPriceFeed interface methods
    function vTaoUsdOracle() external view returns (AggregatorV3Interface, uint256, uint8) {
        return (_vTaoUsdAggregator, _vTaoUsdStalenessThreshold, _vTaoUsdDecimals);
    }

    // Mock control methods
    function setPrice(uint256 price) external {
        _lastGoodPrice = price;
    }
    
    function setOracleWorking(bool working) external {
        _shouldOracleFail = !working;
    }

    function setLastGoodPrice(uint256 price) external {
        _lastGoodPrice = price;
    }

    function setPriceSource(IMainnetPriceFeed.PriceSource source) external {
        _priceSource = source;
    }

    function setShouldOracleFail(bool shouldFail) external {
        _shouldOracleFail = shouldFail;
    }

    function initializeFromRealPriceFeed(PythVTAOPriceFeed realPriceFeed) external {
        _lastGoodPrice = realPriceFeed.lastGoodPrice();
        _priceSource = IMainnetPriceFeed.PriceSource.primary;
        _shouldOracleFail = false;
    }
}