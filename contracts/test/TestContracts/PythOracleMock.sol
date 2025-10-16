// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.24;

// Mock Pyth oracle that returns configurable price data.
// This contract code is etched over mainnet oracle addresses in mainnet fork tests.
contract PythOracleMock {
    struct Price {
        // Price
        int64 price;
        // Confidence interval around the price
        uint64 conf;
        // Price exponent
        int32 expo;
        // Unix timestamp describing when the price was published
        uint publishTime;
    }

    mapping(bytes32 => Price) private prices;

    function getPriceUnsafe(bytes32 id) external view returns (Price memory price) {
        return prices[id];
    }

    function setPrice(bytes32 id, int64 _price) external {
        prices[id].price = _price;
    }

    function setExpo(bytes32 id, int32 _expo) external {
        prices[id].expo = _expo;
    }

    function setConf(bytes32 id, uint64 _conf) external {
        prices[id].conf = _conf;
    }

    function setPublishTime(bytes32 id, uint256 _publishTime) external {
        prices[id].publishTime = _publishTime;
    }

    function setPriceData(
        bytes32 id,
        int64 _price,
        uint64 _conf,
        int32 _expo,
        uint256 _publishTime
    ) external {
        prices[id] = Price({
            price: _price,
            conf: _conf,
            expo: _expo,
            publishTime: _publishTime
        });
    }
}