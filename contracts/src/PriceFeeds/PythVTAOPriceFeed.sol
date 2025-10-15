// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import "./PythCompositePriceFeed.sol";
import "../Tokens/IvTAO.sol";
import "../Interfaces/IVTAOPriceFeed.sol";
import "../Dependencies/LiquityMath.sol";

// import "forge-std/console2.sol";

contract PythVTAOPriceFeed is PythCompositePriceFeed, IVTAOPriceFeed {
    Oracle public vTaoUsdOracleData;

    uint256 public constant VTAO_USD_DEVIATION_THRESHOLD = 1e16; // 1%

    constructor(
        address _pythContractAddress,
        bytes32 _taoUsdPriceId,
        bytes32 _vTaoUsdPriceId,
        address _vTaoTokenAddress,
        uint256 _taoUsdStalenessThreshold,
        uint256 _vTaoUsdStalenessThreshold,
        address _borrowerOperationsAddress
    )
        PythCompositePriceFeed(
            _pythContractAddress,
            _taoUsdPriceId,
            _vTaoTokenAddress,
            _taoUsdStalenessThreshold,
            _borrowerOperationsAddress
        )
    {
        vTaoUsdOracleData.priceId = _vTaoUsdPriceId;
        vTaoUsdOracleData.stalenessThreshold = _vTaoUsdStalenessThreshold;
        vTaoUsdOracleData.decimals = 8; // Pyth prices are typically 8 decimals

        _fetchPricePrimary(false);

        // Check the oracle didn't already fail
        assert(priceSource == PriceSource.primary);
    }

    // Compatibility function for the interface
    function ethUsdOracle() external view override returns (AggregatorV3Interface, uint256, uint8) {
        // Return a dummy AggregatorV3Interface (address(0)), staleness threshold, and decimals
        return (AggregatorV3Interface(address(0)), taoUsdOracleData.stalenessThreshold, taoUsdOracleData.decimals);
    }

    // Compatibility function for the interface
    function taoUsdOracle() external view override returns (AggregatorV3Interface, uint256, uint8) {
        // Return a dummy AggregatorV3Interface (address(0)), staleness threshold, and decimals
        return (AggregatorV3Interface(address(0)), taoUsdOracleData.stalenessThreshold, taoUsdOracleData.decimals);
    }

    // Compatibility function for the IVTAOPriceFeed interface
    function vTaoUsdOracle() external view override returns (AggregatorV3Interface, uint256, uint8) {
        // Return a dummy AggregatorV3Interface (address(0)), staleness threshold, and decimals
        return (AggregatorV3Interface(address(0)), vTaoUsdOracleData.stalenessThreshold, vTaoUsdOracleData.decimals);
    }

    function _fetchPricePrimary(bool _isRedemption) internal override returns (uint256, bool) {
        assert(priceSource == PriceSource.primary);
        (uint256 vTaoUsdPrice, bool vTaoUsdOracleDown) = _getOracleAnswer(vTaoUsdOracleData);
        (uint256 taoPerVTao, bool exchangeRateIsDown) = _getCanonicalRate();
        (uint256 taoUsdPrice, bool taoUsdOracleDown) = _getOracleAnswer(taoUsdOracleData);

        // - If exchange rate or TAO-USD is down, shut down and switch to last good price. Reasoning:
        // - Exchange rate is used in all price calcs
        // - TAO-USD is used in the fallback calc, and for redemptions in the primary price calc
        if (exchangeRateIsDown) {
            return (_shutDownAndSwitchToLastGoodPrice(rateProviderAddress), true);
        }
        if (taoUsdOracleDown) {
            return (_shutDownAndSwitchToLastGoodPrice(address(taoUsdOracleData.pythContract)), true);
        }

        // If the vTAO-USD feed is down, shut down and try to substitute it with the TAO-USD price
        if (vTaoUsdOracleDown) {
            return (_shutDownAndSwitchToETHUSDxCanonical(address(vTaoUsdOracleData.pythContract), taoUsdPrice), true);
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

        try Interface(payable(rateProviderAddress)).vTAOtoTAO(1e18) returns (uint256 taoAmount) {
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