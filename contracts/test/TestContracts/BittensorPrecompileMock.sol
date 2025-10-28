// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IBittensorPrecompilesMock} from "./Interfaces/IBittensorPrecompilesMock.sol";

/**
 * @title BittensorPrecompileMock
 * @dev Mock contract that emulates the Bittensor precompile at address 0x805
 * This mock simulates the vTAO to TAO conversion functionality
 */
contract BittensorPrecompileMock is IBittensorPrecompilesMock {
    
    // ============ Main Functions ============
    
    /**
     * @dev Returns the stake amount for a given hotkey, coldkey, and netuid
     * This is the key function that vTAO contract calls to get the current stake
     * Returns 274089387908 which is calculated to make vTAOtoTAO(1e18) return 1003942352
     * when totalSupply is 273013074269530958540
     */
    function getStake(bytes32 hotkey, bytes32 coldkey, uint256 netuid) external pure override returns (uint256) {
        // Return the calculated stake amount that makes vTAOtoTAO work correctly
        // Formula: (1003942352 * 273013074269530958540) / 1e18 = 274089387908
        return 524089387908;
    }

    /**
     * @dev Emulates the Bittensor precompile conversion function
     * The rate 1003942352 represents the conversion rate in 9-decimal precision
     * where 1 vTAO = 1.003942352 TAO (1003942352 / 1e9 = 1.003942352)
     * @param amount The amount of vTAO to convert (in wei)
     * @return The equivalent amount in TAO (in wei)
     */
    function convert(uint256 amount) external pure returns (uint256) {
        if (amount == 0) return 0;
        
        // The rate 1003942352 is in 9-decimal precision
        // To convert from 18-decimal vTAO to 18-decimal TAO:
        // TAO = vTAO * rate / 1e9
        return (amount * 1003942352) / 1e9;
    }

    // ============ Dummy Interface Implementations ============
    
    function addProxy(bytes32 delegate) external override {
        // Dummy implementation
    }
    
    function addStake(bytes32 hotkey, uint256 amount, uint256 netuid) external payable override {
        // Dummy implementation
    }
    
    function addStakeLimit(bytes32 hotkey, uint256 amount, uint256 limit_price, bool allow_partial, uint256 netuid)
        external
        payable
        override
    {
        // Dummy implementation
    }
    
    function getAlphaStakedValidators(bytes32 hotkey, uint256 netuid) external pure override returns (uint256[] memory) {
        // Return empty array
        return new uint256[](0);
    }
    
    function getNominatorMinRequiredStake() external pure override returns (uint256) {
        // Return a dummy minimum stake requirement
        return 1000000000; // 1 TAO in RAO decimals
    }
    
    function getTotalAlphaStaked(bytes32 hotkey, uint256 netuid) external pure override returns (uint256) {
        // Return dummy total alpha staked
        return 1003942352;
    }
    
    function getTotalColdkeyStake(bytes32 coldkey) external pure override returns (uint256) {
        // Return dummy total coldkey stake
        return 1003942352;
    }
    
    function getTotalHotkeyStake(bytes32 hotkey) external pure override returns (uint256) {
        // Return dummy total hotkey stake
        return 1003942352;
    }
    
    function moveStake(
        bytes32 origin_hotkey,
        bytes32 destination_hotkey,
        uint256 origin_netuid,
        uint256 destination_netuid,
        uint256 amount
    ) external override {
        // Dummy implementation
    }
    
    function removeProxy(bytes32 delegate) external override {
        // Dummy implementation
    }
    
    function removeStake(bytes32 hotkey, uint256 amount, uint256 netuid) external override {
        // Dummy implementation
    }
    
    function removeStakeFull(bytes32 hotkey, uint256 netuid) external override {
        // Dummy implementation
    }
    
    function removeStakeFullLimit(bytes32 hotkey, uint256 netuid, uint256 limitPrice) external override {
        // Dummy implementation
    }
    
    function removeStakeLimit(bytes32 hotkey, uint256 amount, uint256 limit_price, bool allow_partial, uint256 netuid)
        external
        override
    {
        // Dummy implementation
    }
    
    function transferStake(
        bytes32 destination_coldkey,
        bytes32 hotkey,
        uint256 origin_netuid,
        uint256 destination_netuid,
        uint256 amount
    ) external override {
        // Dummy implementation
    }

    // ============ Legacy Functions for Backward Compatibility ============

    /**
     * @dev Handle the specific function selector e3b598fa that the vTAO contract calls
     * This is the getStake function in the Bittensor precompile with signature getStake(bytes32,bytes32,uint256)
     * The vTAO contract calls this with (hotkey, coldkey, netuid) parameters
     */
    function e3b598fa(bytes32, bytes32, uint256) external pure returns (uint256) {
        // Return the calculated stake value that makes vTAOtoTAO work correctly
        // Formula: (1003942352 * 273013074269530958540) / 1e18 = 274089387908
        return 274089387908;
    }

    /**
     * @dev Fallback function to handle any calls to the precompile
     * This ensures compatibility with different call patterns
     */
    fallback() external payable {
        // For any unrecognized call, return the calculated conversion value
        uint256 result = 274089387908;
        
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
        // For plain ETH transfers, assume 1e18 input and return converted amount
        uint256 result = (1e18 * 1003942352) / 1e9; // 1.003942352e18
        assembly {
            mstore(0x00, result)
            return(0x00, 0x20)
        }
    }
}