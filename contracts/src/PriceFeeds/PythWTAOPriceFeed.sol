// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./PythPriceFeedBase.sol";
import "../Interfaces/ITAOPriceFeed.sol";

/*
 * PriceFeed for WTAO token.
 * Fetches the price of TAO in USD.
 */
contract PythWTAOPriceFeed is PythPriceFeedBase, ITAOPriceFeed {
    constructor(
        address _taoUsdAggregator,
        uint256 _taoUsdStalenessThreshold,
        address _borrowOperationsAddress
    ) PythPriceFeedBase(_taoUsdAggregator, _taoUsdStalenessThreshold, _borrowOperationsAddress) {
        // Fetch the price to ensure the oracle is working
        _fetchPricePrimary();
        assert(priceSource == PriceSource.primary);
    }

    // Compatibility function for the interface
    function ethUsdOracle() external view override returns (AggregatorV3Interface, uint256, uint8) {
        // Return the TAO/USD oracle (since we're using TAO as the base), staleness threshold, and decimals
        return (taoUsdOracleData.aggregator, taoUsdOracleData.stalenessThreshold, taoUsdOracleData.decimals);
    }

    // Compatibility function for the interface
    function taoUsdOracle() external view override(ITAOPriceFeed) returns (AggregatorV3Interface, uint256, uint8) {
        // Return the TAO/USD oracle, staleness threshold, and decimals
        return (taoUsdOracleData.aggregator, taoUsdOracleData.stalenessThreshold, taoUsdOracleData.decimals);
    }

    function fetchPrice() public returns (uint256, bool) {
        // If branch is live and the primary oracle setup has been working, try to use it
        if (priceSource == PriceSource.primary) return _fetchPricePrimary();

        // Otherwise if branch is shut down and already using the lastGoodPrice, continue with it
        assert(priceSource == PriceSource.lastGoodPrice);
        return (lastGoodPrice, false);
    }

    function fetchRedemptionPrice() external returns (uint256, bool) {
        // Use same price for redemption as all other ops in WTAO branch
        return fetchPrice();
    }

    //  _fetchPricePrimary returns:
    // - The price
    // - A bool indicating whether a new oracle failure was detected in the call
    function _fetchPricePrimary() internal returns (uint256, bool) {
        assert(priceSource == PriceSource.primary);
        (uint256 taoUsdPrice, bool taoUsdOracleDown) = _getOracleAnswer(taoUsdOracleData);

        // If the TAO-USD oracle response was invalid in this transaction, return the last good TAO-USD price calculated
        if (taoUsdOracleDown) return (_shutDownAndSwitchToLastGoodPrice(address(taoUsdOracleData.aggregator)), true);

        lastGoodPrice = taoUsdPrice;
        return (taoUsdPrice, false);
    }
}