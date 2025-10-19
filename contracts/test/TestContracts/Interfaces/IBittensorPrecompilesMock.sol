// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

interface IBittensorPrecompilesMock {
    function addProxy(bytes32 delegate) external;
    function addStake(bytes32 hotkey, uint256 amount, uint256 netuid) external payable;
    function addStakeLimit(bytes32 hotkey, uint256 amount, uint256 limit_price, bool allow_partial, uint256 netuid)
        external
        payable;
    function getAlphaStakedValidators(bytes32 hotkey, uint256 netuid) external view returns (uint256[] memory);
    function getNominatorMinRequiredStake() external view returns (uint256);
    function getStake(bytes32 hotkey, bytes32 coldkey, uint256 netuid) external view returns (uint256);
    function getTotalAlphaStaked(bytes32 hotkey, uint256 netuid) external view returns (uint256);
    function getTotalColdkeyStake(bytes32 coldkey) external view returns (uint256);
    function getTotalHotkeyStake(bytes32 hotkey) external view returns (uint256);
    function moveStake(
        bytes32 origin_hotkey,
        bytes32 destination_hotkey,
        uint256 origin_netuid,
        uint256 destination_netuid,
        uint256 amount
    ) external;
    function removeProxy(bytes32 delegate) external;
    function removeStake(bytes32 hotkey, uint256 amount, uint256 netuid) external;
    function removeStakeFull(bytes32 hotkey, uint256 netuid) external;
    function removeStakeFullLimit(bytes32 hotkey, uint256 netuid, uint256 limitPrice) external;
    function removeStakeLimit(bytes32 hotkey, uint256 amount, uint256 limit_price, bool allow_partial, uint256 netuid)
        external;
    function transferStake(
        bytes32 destination_coldkey,
        bytes32 hotkey,
        uint256 origin_netuid,
        uint256 destination_netuid,
        uint256 amount
    ) external;
}
