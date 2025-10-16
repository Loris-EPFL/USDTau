// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import "./PythCompositePriceFeed.sol";
import "../Tokens/IvTAO.sol";
import "../Interfaces/IVTAOPriceFeed.sol";
import "../Dependencies/LiquityMath.sol";

// import "forge-std/console2.sol";

contract PythVTAOPriceFeed is PythCompositePriceFeed, IVTAOPriceFeed {
    AggregatorV3Interface public vTaoUsdAggregator;
    uint256 public vTaoUsdStalenessThreshold;
    uint8 public vTaoUsdDecimals;

    uint256 public constant VTAO_USD_DEVIATION_THRESHOLD = 1e16; // 1%

    constructor(
        address _taoUsdAggregator,
        address _vTaoUsdAggregator,
        address _vTaoTokenAddress,
        uint256 _taoUsdStalenessThreshold,
        uint256 _vTaoUsdStalenessThreshold,
        address _borrowerOperationsAddress
    )
        PythCompositePriceFeed(
            _taoUsdAggregator,
            _vTaoTokenAddress,
            _taoUsdStalenessThreshold,
            _borrowerOperationsAddress
        )
    {
        vTaoUsdAggregator = AggregatorV3Interface(_vTaoUsdAggregator);
        vTaoUsdStalenessThreshold = _vTaoUsdStalenessThreshold;
        vTaoUsdDecimals = vTaoUsdAggregator.decimals();

        _fetchPricePrimary(false);

        // Check the oracle didn't already fail
        assert(priceSource == PriceSource.primary);
    }

    // Compatibility function for the interface
    function ethUsdOracle() external view override returns (AggregatorV3Interface, uint256, uint8) {
        // Return the TAO/USD oracle (since we're using TAO as the base), staleness threshold, and decimals
        return (taoUsdOracleData.aggregator, taoUsdOracleData.stalenessThreshold, taoUsdOracleData.decimals);
    }

    // Compatibility function for the interface
    function taoUsdOracle() external view override returns (AggregatorV3Interface, uint256, uint8) {
        // Return the TAO/USD oracle, staleness threshold, and decimals
        return (taoUsdOracleData.aggregator, taoUsdOracleData.stalenessThreshold, taoUsdOracleData.decimals);
    }

    // Compatibility function for the IVTAOPriceFeed interface
    function vTaoUsdOracle() external view override returns (AggregatorV3Interface, uint256, uint8) {
        // Return the vTAO/USD oracle, staleness threshold, and decimals
        return (vTaoUsdAggregator, vTaoUsdStalenessThreshold, vTaoUsdDecimals);
    }

    function _fetchPricePrimary(bool _isRedemption) internal override returns (uint256, bool) {
        assert(priceSource == PriceSource.primary);
        
        // Get vTAO-USD price
        ChainlinkResponse memory vTaoUsdResponse = _getCurrentChainlinkResponse(vTaoUsdAggregator);
        bool vTaoUsdOracleDown = !_isValidChainlinkPrice(vTaoUsdResponse, vTaoUsdStalenessThreshold);
        uint256 vTaoUsdPrice = _scaleChainlinkPriceTo18decimals(vTaoUsdResponse.answer, vTaoUsdDecimals);
        
        // Get canonical exchange rate
        (uint256 taoPerVTao, bool exchangeRateIsDown) = _getCanonicalRate();
        
        // Get TAO-USD price
        (uint256 taoUsdPrice, bool taoUsdOracleDown) = _getOracleAnswer(taoUsdOracleData);

        // - If exchange rate or TAO-USD is down, shut down and switch to last good price. Reasoning:
        // - Exchange rate is used in all price calcs
        // - TAO-USD is used in the fallback calc, and for redemptions in the primary price calc
        if (exchangeRateIsDown) {
            return (_shutDownAndSwitchToLastGoodPrice(rateProviderAddress), true);
        }
        if (taoUsdOracleDown) {
            return (_shutDownAndSwitchToLastGoodPrice(address(taoUsdOracleData.aggregator)), true);
        }

        // If the vTAO-USD feed is down, shut down and try to substitute it with the TAO-USD price
        if (vTaoUsdOracleDown) {
            return (_shutDownAndSwitchToETHUSDxCanonical(address(vTaoUsdAggregator), taoUsdPrice), true);
        }

        // Otherwise, use the primary price calculation:
        uint256 vTaoUsdPriceCalculated;

        if (_isRedemption && _withinDeviationThreshold(vTaoUsdPrice, taoUsdPrice, VTAO_USD_DEVIATION_THRESHOLD)) {
            // If it's a redemption and within 1%, take the max of (vTAO-USD, TAO-USD) to mitigate unwanted redemption arb and convert to vTAO-USD
            vTaoUsdPriceCalculated = LiquityMath._max(vTaoUsdPrice, taoUsdPrice) * taoPerVTao / 1e18;
        } else {
            // Otherwise, just calculate vTAO-USD price: USD_per_vTAO = USD_per_TAO * TAO_per_vTAO
            vTaoUsdPriceCalculated = taoUsdPrice * taoPerVTao / 1e18;
        }

        lastGoodPrice = vTaoUsdPriceCalculated;

        return (vTaoUsdPriceCalculated, false);
    }

    function _getCanonicalRate() internal view override returns (uint256, bool) {
        uint256 gasBefore = gasleft();

        try IvTAO(payable(rateProviderAddress)).vTAOtoTAO(1e18) returns (uint256 taoAmount) {
            // If rate is 0, return true (invalid)
            if (taoAmount == 0) return (0, true);

            return (taoAmount, false);
        } catch {
            // Require that enough gas was provided to prevent an OOG revert in the external call
            // causing a shutdown. Instead, just revert. Slightly conservative, as it includes gas used
            // in the check itself.
            if (gasleft() <= gasBefore / 64) revert InsufficientGasForExternalCall();

            // If call to exchange rate reverted for another reason, return true
            return (0, true);
        }
    }
}