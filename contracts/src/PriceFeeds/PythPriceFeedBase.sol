// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import "../Dependencies/AggregatorV3Interface.sol";
import "../Interfaces/IMainnetPriceFeed.sol";
import "../BorrowerOperations.sol";
import "../Tokens/IPythOracle.sol";

// import "forge-std/console2.sol";

abstract contract PythPriceFeedBase is IMainnetPriceFeed {
    // Determines where the PriceFeed sources data from. Possible states:
    // - primary: Uses the primary price calculation, which depends on the specific feed
    // - TAOUSDxCanonical: Uses Pyth's TAO-USD multiplied by the LST' canonical rate
    // - lastGoodPrice: the last good price recorded by this PriceFeed.
    PriceSource public priceSource;

    // Last good price tracker for the derived USD price
    uint256 public lastGoodPrice;

    struct Oracle {
        IPythOracle pythContract;
        bytes32 priceId;
        uint256 stalenessThreshold;
        uint8 decimals;
    }

    struct PythResponse {
        int64 price;
        uint256 timestamp;
        bool success;
    }

    error InsufficientGasForExternalCall();

    event ShutDownFromOracleFailure(address _failedOracleAddr);

    Oracle internal taoUsdOracleData;

    IBorrowerOperations borrowerOperations;

    constructor(
        address _pythContractAddress,
        bytes32 _taoUsdPriceId,
        uint256 _taoUsdStalenessThreshold,
        address _borrowOperationsAddress
    ) {
        // Store TAO-USD oracle
        taoUsdOracleData.pythContract = IPythOracle(_pythContractAddress);
        taoUsdOracleData.priceId = _taoUsdPriceId;
        taoUsdOracleData.stalenessThreshold = _taoUsdStalenessThreshold;
        
        // Get decimals from Pyth price feed
        PythStructs.Price memory priceData = taoUsdOracleData.pythContract.getPriceUnsafe(_taoUsdPriceId);
        taoUsdOracleData.decimals = uint8(uint32(-priceData.expo));

        borrowerOperations = IBorrowerOperations(_borrowOperationsAddress);

        // Pyth typically uses 8 decimals for USD pairs
        assert(taoUsdOracleData.decimals == 8);
    }

    function _getOracleAnswer(Oracle memory _oracle) internal view returns (uint256, bool) {
        PythResponse memory pythResponse = _getCurrentPythResponse(_oracle.pythContract, _oracle.priceId);

        uint256 scaledPrice;
        bool oracleIsDown;
        // Check oracle is serving an up-to-date and sensible price. If not, shut down this collateral branch.
        if (!_isValidPythPrice(pythResponse, _oracle.stalenessThreshold)) {
            oracleIsDown = true;
        } else {
            scaledPrice = _scalePythPriceTo18decimals(pythResponse.price, _oracle.decimals);
        }

        return (scaledPrice, oracleIsDown);
    }

    function _shutDownAndSwitchToLastGoodPrice(address _failedOracleAddr) internal returns (uint256) {
        // Shut down the branch
        borrowerOperations.shutdownFromOracleFailure();

        priceSource = PriceSource.lastGoodPrice;

        emit ShutDownFromOracleFailure(_failedOracleAddr);
        return lastGoodPrice;
    }

    function _getCurrentPythResponse(IPythOracle _pythContract, bytes32 _priceId)
        internal
        view
        returns (PythResponse memory pythResponse)
    {
        uint256 gasBefore = gasleft();

        // Try to get latest price data:
        try _pythContract.getPriceUnsafe(_priceId) returns (PythStructs.Price memory priceData) {
            // If call to Pyth succeeds, return the response and success = true
            pythResponse.price = priceData.price;
            pythResponse.timestamp = priceData.publishTime;
            pythResponse.success = true;

            return pythResponse;
        } catch {
            // Require that enough gas was provided to prevent an OOG revert in the call to Pyth
            // causing a shutdown. Instead, just revert. Slightly conservative, as it includes gas used
            // in the check itself.
            if (gasleft() <= gasBefore / 64) revert InsufficientGasForExternalCall();

            // If call to Pyth aggregator reverts, return a zero response with success = false
            return pythResponse;
        }
    }

    // False if:
    // - Call to Pyth aggregator reverts
    // - price is too stale, i.e. older than the oracle's staleness threshold
    // - Price answer is 0 or negative
    function _isValidPythPrice(PythResponse memory pythResponse, uint256 _stalenessThreshold)
        internal
        view
        returns (bool)
    {
        return pythResponse.success && block.timestamp - pythResponse.timestamp < _stalenessThreshold
            && pythResponse.price > 0;
    }

    // Scale a Pyth price to 18 decimals
    function _scalePythPriceTo18decimals(int64 _price, uint256 _decimals) internal pure returns (uint256) {
        // Scale an int price to a uint with 18 decimals
        return uint256(uint64(_price)) * 10 ** (18 - _decimals);
    }

    // Compatibility function to match Chainlink interface
    function getEthUsdOracle() external view returns (AggregatorV3Interface, uint256, uint8) {
        // Return compatibility interface for tests - this is a mock implementation
        // since Pyth doesn't use AggregatorV3Interface
        return (AggregatorV3Interface(address(0)), taoUsdOracleData.stalenessThreshold, taoUsdOracleData.decimals);
    }
}