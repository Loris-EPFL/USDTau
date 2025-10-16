// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/**
 * @title BittensorPrecompileMock
 * @dev Mock contract that emulates the Bittensor precompile at address 0x805
 * This mock simulates the vTAO to TAO conversion functionality
 */
contract BittensorPrecompileMock {
    /**
     * @dev Emulates the Bittensor precompile conversion function
     * For input 1e18 (1 vTAO), returns 1003942352 (approximately 1.003942352 TAO)
     * This represents a conversion rate where 1 vTAO = ~1.003942352 TAO
     * @param amount The amount of vTAO to convert (in wei)
     * @return The equivalent amount in TAO (in wei)
     */
    function convert(uint256 amount) external pure returns (uint256) {
        if (amount == 0) return 0;
        
        // For 1e18 input, return 1003942352
        // This gives us a rate of approximately 1.003942352 TAO per vTAO
        // We scale this proportionally for other amounts
        return (amount * 1003942352) / 1e18;
    }

    /**
     * @dev Handle the specific function selector e3b598fa that the vTAO contract calls
     * This appears to be the getStake function in the Bittensor precompile
     */
    function e3b598fa(bytes32, uint256) external pure returns (uint256) {
        // Return the expected conversion value for 1 vTAO = 1003942352 TAO
        return 1003942352;
    }

    /**
     * @dev Fallback function to handle any calls to the precompile
     * This ensures compatibility with different call patterns
     */
    fallback() external payable {
        // For any unrecognized call, return the default conversion value
        uint256 result = 1003942352;
        
        // Return the result
        assembly {
            mstore(0x00, result)
            return(0x00, 0x20)
        }
    }

    /**
     * @dev Receive function to handle plain ETH transfers
     */
    receive() external payable {
        // For plain ETH transfers, assume 1e18 input
        uint256 result = 1003942352;
        assembly {
            mstore(0x00, result)
            return(0x00, 0x20)
        }
    }
}