// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import "../Tokens/IvTAO.sol";
import "../Interfaces/IVTAOPriceFeed.sol";
import "../Dependencies/LiquityMath.sol";
import "./MainnetPriceFeedBase.sol";
import "./CompositePriceFeed.sol";
import "../Interfaces/IWSTETHPriceFeed.sol";

// import "forge-std/console2.sol";

contract PythVTAOPriceFeed is CompositePriceFeed, IWSTETHPriceFeed {
    Oracle public stEthUsdOracle;

    AggregatorV3Interface public vTaoUsdAggregator;
    uint256 public vTaoUsdStalenessThreshold;
    uint8 public vTaoUsdDecimals;

    uint256 public constant VTAO_USD_DEVIATION_THRESHOLD = 1e16; // 1%

    constructor(
        address _taoUsdAggregator,
        address _vTaoTokenAddress,
        uint256 _taoUsdStalenessThreshold,
        address _borrowerOperationsAddress
    )
        CompositePriceFeed(
            _taoUsdAggregator,
            _vTaoTokenAddress,
            _taoUsdStalenessThreshold,
            _borrowerOperationsAddress
        )
    {
        // vTAO-USD aggregator is not used since we always calculate from canonical rate
        stEthUsdOracle.aggregator = AggregatorV3Interface(_taoUsdAggregator);
        stEthUsdOracle.stalenessThreshold = _taoUsdStalenessThreshold;
        stEthUsdOracle.decimals = stEthUsdOracle.aggregator.decimals();


        _fetchPricePrimary(false);

        // Check the oracle didn't already fail
        assert(priceSource == PriceSource.primary);
    }

    function _fetchPricePrimary(bool _isRedemption) internal override returns (uint256, bool) {
        assert(priceSource == PriceSource.primary);
        
        // Get canonical exchange rate
        (uint256 taoPerVTao, bool exchangeRateIsDown) = _getCanonicalRate();
        
        // Get TAO-USD price
        (uint256 taoUsdPrice, bool taoUsdOracleDown) = _getOracleAnswer(ethUsdOracle);

        // - If exchange rate or TAO-USD is down, shut down and switch to last good price. Reasoning:
        // - Exchange rate is used in all price calcs
        // - TAO-USD is used in the fallback calc, and for redemptions in the primary price calc
        if (exchangeRateIsDown) {
            return (_shutDownAndSwitchToLastGoodPrice(rateProviderAddress), true);
        }
        if (taoUsdOracleDown) {
            return (_shutDownAndSwitchToLastGoodPrice(address(ethUsdOracle.aggregator)), true);
        }

        // Always calculate vTAO-USD price using canonical rate: USD_per_vTAO = USD_per_TAO * TAO_per_vTAO
        uint256 vTaoUsdPriceCalculated = taoUsdPrice * taoPerVTao / 1e18;

        lastGoodPrice = vTaoUsdPriceCalculated;

        return (vTaoUsdPriceCalculated, false);
    }

    function _getCanonicalRate() internal view override returns (uint256, bool) {
        uint256 gasBefore = gasleft();

        try IvTAO(payable(rateProviderAddress)).vTAOtoTAO(1e18) returns (uint256 taoAmount) {
            // If rate is 0, fallback to 1:1 ratio (1 vTAO = 1 TAO)
            // This handles cases where the RPC may incorrectly return 0
            if (taoAmount == 0) {
                // Return 1e18 (1:1 ratio in 18 decimals)
                return (1e18, false);
            }

            // The vTAOtoTAO function returns the TAO amount in 9-decimal precision (e.g., 1003980796 for ~1.003980796 TAO)
            // We need to convert this to 18-decimal precision for our calculations
            // Since we called vTAOtoTAO(1e18), the returned value represents TAO per 1 vTAO in 9-decimal precision
            // Convert from 9-decimal to 18-decimal: multiply by 1e9
            uint256 taoPerVTaoIn18Decimals = taoAmount * 1e9;

            return (taoPerVTaoIn18Decimals, false);
        } catch {
            // Require that enough gas was provided to prevent an OOG revert in the external call
            // causing a shutdown. Instead, just revert. Slightly conservative, as it includes gas used
            // in the check itself.
            if (gasleft() <= gasBefore / 64) revert InsufficientGasForExternalCall();

            // If vTAOtoTAO call fails, fallback to 1:1 ratio (1 vTAO = 1 TAO)
            // This handles cases where the external call reverts
            return (1e18, false);
        }
    }

}