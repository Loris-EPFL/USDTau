// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import "./PythPriceFeedBase.sol";
import "../Interfaces/ITAOPriceFeed.sol";

// import "forge-std/console2.sol";

contract PythWTAOPriceFeed is PythPriceFeedBase, ITAOPriceFeed {
    constructor(
        address _pythContractAddress,
        bytes32 _taoUsdPriceId,
        uint256 _taoUsdStalenessThreshold,
        address _borrowerOperationsAddress
    ) PythPriceFeedBase(_pythContractAddress, _taoUsdPriceId, _taoUsdStalenessThreshold, _borrowerOperationsAddress) {
        _fetchPricePrimary();

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

        // If the TAO-USD Pyth response was invalid in this transaction, return the last good TAO-USD price calculated
        if (taoUsdOracleDown) return (_shutDownAndSwitchToLastGoodPrice(address(taoUsdOracleData.pythContract)), true);

        lastGoodPrice = taoUsdPrice;
        return (taoUsdPrice, false);
    }
}