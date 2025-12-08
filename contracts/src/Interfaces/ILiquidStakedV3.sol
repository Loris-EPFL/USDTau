// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

interface ILiquidStakedV3 {
    error AccessControlBadConfirmation();
    error AccessControlUnauthorizedAccount(address account, bytes32 neededRole);
    error AddressEmptyCode(address target);
    error CallFailed();
    error ChangePending();
    error DeadlineExpired();
    error ERC1967InvalidImplementation(address implementation);
    error ERC1967NonPayable();
    error ERC20InsufficientAllowance(address spender, uint256 allowance, uint256 needed);
    error ERC20InsufficientBalance(address sender, uint256 balance, uint256 needed);
    error ERC20InvalidApprover(address approver);
    error ERC20InvalidReceiver(address receiver);
    error ERC20InvalidSender(address sender);
    error ERC20InvalidSpender(address spender);
    error EnforcedPause();
    error ExceedsAvailable();
    error ExpectedPause();
    error FailedCall();
    error FeeExceedsMax();
    error InsufficientBalance();
    error InvalidAddress();
    error InvalidAmount();
    error InvalidInitialization();
    error InvalidMinAmount();
    error InvalidRate();
    error InvalidRecipient();
    error NoPendingWithdrawal();
    error NoStake();
    error NotInitializing();
    error OwnableInvalidOwner(address owner);
    error OwnableUnauthorizedAccount(address account);
    error ReentrancyGuardReentrantCall();
    error SameAddress();
    error SlippageTooHigh();
    error TimelockActive();
    error TransferFailed();
    error UUPSUnauthorizedCallContext();
    error UUPSUnsupportedProxiableUUID(bytes32 slot);
    error Unauthorized();
    error WithdrawalPending();

    event AlphaRedeemed(
        address indexed user,
        bytes32 indexed recipient,
        uint256 lsaAmountBurned,
        uint256 calculatedAlphaAmount,
        uint256 actualAlphaTransferred,
        uint256 treasuryAlphaFee,
        uint256 exchangeRate,
        uint256 timestamp,
        uint256 totalSupplyBefore,
        uint256 totalSupplyAfter
    );
    event Approval(address indexed owner, address indexed spender, uint256 value);
    event CommunityRepresentativeChangeCancelled(
        address indexed owner, address indexed cancelledRepresentative, uint256 timestamp
    );
    event CommunityRepresentativeChangeInitiated(
        address indexed owner,
        address indexed currentRepresentative,
        address indexed newRepresentative,
        uint256 availableAt,
        uint256 timestamp
    );
    event CommunityRepresentativeUpdated(
        address indexed oldRepresentative, address indexed newRepresentative, address indexed updatedBy
    );
    event ContractSS58PubUpdated(
        bytes32 indexed oldContractSS58Pub, bytes32 indexed newContractSS58Pub, address indexed updatedBy
    );
    event EmergencyTaoWithdrawal(
        address indexed owner,
        address indexed recipient,
        uint256 taoAmount,
        uint256 balanceBefore,
        uint256 balanceAfter,
        uint256 timestamp
    );
    event EmergencyTaoWithdrawalCancelled(
        address indexed owner, address indexed recipient, uint256 taoAmount, uint256 timestamp
    );
    event EmergencyTaoWithdrawalInitiated(
        address indexed owner, address indexed recipient, uint256 taoAmount, uint256 availableAt, uint256 timestamp
    );
    event EmergencyWithdrawal(
        address indexed owner,
        uint256 alphaAmount,
        uint256 stakeBefore,
        uint256 stakeAfter,
        uint256 lsaSupply,
        uint256 timestamp
    );
    event EmergencyWithdrawalCancelled(address indexed owner, uint256 alphaAmount, uint256 timestamp);
    event EmergencyWithdrawalInitiated(
        address indexed owner, uint256 alphaAmount, uint256 availableAt, uint256 timestamp
    );
    event FeesClaimed(
        bytes32 indexed treasury,
        uint256 treasuryAlphaAmount,
        uint256 yieldAlphaAmount,
        uint256 totalAlphaAmount,
        address indexed claimedBy,
        uint256 timestamp
    );
    event Initialized(uint64 version);
    event NetworkFeeUpdated(uint256 oldNetworkFeeBPS, uint256 newNetworkFeeBPS, address indexed updatedBy);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event Paused(address account);
    event Redeemed(
        address indexed user,
        uint256 lsaAmountBurned,
        uint256 taoReceived,
        uint256 alphaRemoved,
        uint256 exchangeRate,
        uint256 treasuryFee,
        uint256 timestamp,
        uint256 totalStakedBefore,
        uint256 totalStakedAfter,
        uint256 pendingTreasuryAlphaFeesBefore,
        uint256 pendingTreasuryAlphaFeesAfter
    );
    event RoleAdminChanged(bytes32 indexed role, bytes32 indexed previousAdminRole, bytes32 indexed newAdminRole);
    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);
    event Staked(
        address indexed user,
        bytes32 indexed hotkey,
        uint256 taoAmount,
        uint256 alphaAmount,
        uint256 lsaAmount,
        uint256 exchangeRate,
        uint256 treasuryFee,
        uint256 timestamp
    );
    event TVLUpdated(
        uint256 totalAlphaStaked,
        uint256 totalTaoValue,
        uint256 totalLsaSupply,
        uint256 exchangeRate,
        uint256 alphaPrice,
        uint256 backingRatio,
        uint256 utilizationRate,
        uint256 timestamp,
        address indexed triggeredBy,
        string indexed updateReason
    );
    event Transfer(address indexed from, address indexed to, uint256 value);
    event TreasuryBytes32Updated(
        bytes32 indexed oldTreasuryBytes32, bytes32 indexed newTreasuryBytes32, address indexed updatedBy
    );
    event TreasuryFeeUpdated(uint256 oldFeeBPS, uint256 newFeeBPS, address indexed updatedBy);
    event TreasuryUpdated(bytes32 indexed oldTreasury, bytes32 indexed newTreasury, address indexed updatedBy);
    event Unpaused(address account);
    event Upgraded(address indexed implementation);
    event YieldCollected(uint256 yieldAmount, uint256 feeAmount, uint256 netYield, address indexed triggeredBy);
    event YieldDistributed(
        uint256 totalYieldInAlpha,
        uint256 totalYieldInTao,
        uint256 treasuryYieldInAlpha,
        uint256 holderYieldInAlpha,
        uint256 totalSupplyBefore,
        uint256 totalSupplyAfter,
        uint256 exchangeRateBefore,
        uint256 exchangeRateAfter,
        uint256 timestamp,
        address indexed triggeredBy
    );
    event YieldFeeUpdated(uint256 oldYieldFeeBPS, uint256 newYieldFeeBPS, address indexed updatedBy);
    event YieldMintedToLSA(
        uint256 yieldAmount, uint256 lsaMinted, uint256 totalSupplyAfter, address indexed triggeredBy
    );

    fallback() external payable;

    receive() external payable;

    function DEFAULT_ADMIN_ROLE() external view returns (bytes32);
    function EMERGENCY_TIMELOCK() external view returns (uint256);
    function FEE_CLAIMER_ROLE() external view returns (bytes32);
    function FEE_SCALED() external view returns (uint256);
    function NETUID() external view returns (uint256);
    function RAO() external view returns (uint256);
    function UPGRADE_INTERFACE_VERSION() external view returns (string memory);
    function VALIDATOR_HOTKEY() external view returns (bytes32);
    function WAD() external view returns (uint256);
    function accumulatedYieldFees() external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function alpha() external view returns (address);
    function approve(address spender, uint256 value) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function calculateAlphaFromTao(uint256 taoAmount) external view returns (uint256 alphaAmount);
    function calculateMinAlphaWithSlippage(uint256 lsaAmount, uint256 slippagePercent)
        external
        view
        returns (uint256 minAlphaAmount);
    function calculateMinLsaFromAlphaWithSlippage(uint256 alphaAmount, uint256 slippagePercent)
        external
        view
        returns (uint256 minLsaAmount);
    function calculateMinLsaWithSlippage(uint256 taoAmount, uint256 slippagePercent)
        external
        view
        returns (uint256 minLsaAmount);
    function calculateMinTaoWithSlippage(uint256 lsaAmount, uint256 slippagePercent)
        external
        view
        returns (uint256 minTaoAmount);
    function calculateTaoFromAlpha(uint256 alphaAmount) external view returns (uint256 taoAmount);
    function canExecuteCommunityRepresentativeChange() external view returns (bool canExecute);
    function canExecuteEmergencyTaoWithdraw() external view returns (bool canExecute);
    function canExecuteEmergencyWithdraw() external view returns (bool canExecute);
    function cancelCommunityRepresentativeChange() external;
    function cancelEmergencyWithdrawAlpha() external;
    function cancelEmergencyWithdrawTao() external;
    function claimFee() external;
    function communityRepresentative() external view returns (address);
    function communityRepresentativeChangeInitiated() external view returns (uint256);
    function communityRepresentativeChangePending() external view returns (bool);
    function contractSS58Pub() external view returns (bytes32);
    function decimals() external view returns (uint8);
    function depositAlphaWithSlippage(uint256 alphaAmount, uint256 minLsaAmount, uint256 deadline)
        external
        returns (uint256);
    function emergencyTaoWithdrawAmount() external view returns (uint256);
    function emergencyTaoWithdrawInitiated() external view returns (uint256);
    function emergencyTaoWithdrawPending() external view returns (bool);
    function emergencyTaoWithdrawRecipient() external view returns (address);
    function emergencyWithdrawAmount() external view returns (uint256);
    function emergencyWithdrawInitiated() external view returns (uint256);
    function emergencyWithdrawPending() external view returns (bool);
    function estimatedLsaFromAlphaDeposit(uint256 alphaAmount) external view returns (uint256 estimatedLsa);
    function estimatedLsaToMint(uint256 amount) external view returns (uint256);
    function estimatedMintingFee(uint256 amount) external view returns (uint256);
    function estimatedMintingFeeInTao(uint256 amount) external view returns (uint256);
    function estimatedRedemptionFees(uint256 lsaAmount)
        external
        view
        returns (uint256 treasuryFee, uint256 networkFeeBuffer);
    function estimatedRedemptionFeesInTao(uint256 lsaAmount)
        external
        view
        returns (uint256 treasuryFeeInTao, uint256 networkFeeBufferInTao);
    function estimatedTaoFromLsa(uint256 lsaAmount) external view returns (uint256);
    function exchangeRate() external view returns (uint256);
    function executeCommunityRepresentativeChange() external;
    function executeEmergencyWithdrawAlpha(bytes32 recipient) external;
    function executeEmergencyWithdrawTao() external;
    function fee() external view returns (uint256);
    function getAccumulatedYieldFees() external view returns (uint256);
    function getAlphaPrice() external view returns (uint256);
    function getCommunityRepresentative() external view returns (address);
    function getCommunityRepresentativeChangeStatus()
        external
        view
        returns (
            bool isPending,
            address newRepresentative,
            uint256 initiatedAt,
            uint256 availableAt,
            uint256 timeRemaining
        );
    function getCurrentTVLInTao() external view returns (uint256);
    function getEmergencyTaoWithdrawStatus()
        external
        view
        returns (
            bool isPending,
            uint256 amount,
            address recipient,
            uint256 initiatedAt,
            uint256 availableAt,
            uint256 timeRemaining
        );
    function getEmergencyWithdrawStatus()
        external
        view
        returns (bool isPending, uint256 amount, uint256 initiatedAt, uint256 availableAt, uint256 timeRemaining);
    function getFeeClaimerRole() external pure returns (bytes32);
    function getLastRecordedAlphaBalance() external view returns (uint256);
    function getMovingAlphaPrice() external view returns (uint256);
    function getMyStakeBalance(bytes32 coldkey) external view returns (uint256);
    function getNetworkFee() external view returns (uint256);
    function getPendingTreasuryFees() external view returns (uint256);
    function getPendingYieldFees() external view returns (uint256);
    function getRoleAdmin(bytes32 role) external view returns (bytes32);
    function getTVL() external view returns (uint256 alphaAmount, uint256 taoValue, uint256 lastUpdated);
    function getTVLWithLSA()
        external
        view
        returns (uint256 alphaAmount, uint256 taoValue, uint256 lsaSupply, uint256 lastUpdated);
    function getTotalContractStake() external view returns (uint256);
    function getTotalLSASupply() external view returns (uint256);
    function getTotalPendingFees() external view returns (uint256);
    function getTreasuryFee() external view returns (uint256);
    function getUserLsaValue(address user)
        external
        view
        returns (uint256 lsaBalance, uint256 alphaValue, uint256 taoValue, uint256 currentExchangeRate);
    function getValidatorHotkey() external view returns (bytes32);
    function getYieldFee() external view returns (uint256);
    function grantRole(bytes32 role, address account) external;
    function hasRole(bytes32 role, address account) external view returns (bool);
    function initialize(
        string memory _name,
        string memory _symbol,
        uint16 _netuid,
        bytes32 _validatorHotkey,
        bytes32 _contractSS58Pub
    ) external;
    function initiateCommunityRepresentativeChange(address _newCommunityRepresentative) external;
    function initiateEmergencyWithdrawAlpha(uint256 amount) external;
    function initiateEmergencyWithdrawTao(address payable recipient, uint256 amount) external;
    function lastRecordedAlphaBalance() external view returns (uint256);
    function metagraph() external view returns (address);
    function name() external view returns (string memory);
    function networkFee() external view returns (uint256);
    function owner() external view returns (address);
    function pause() external;
    function paused() external view returns (bool);
    function pendingCommunityRepresentative() external view returns (address);
    function pendingTreasuryAlphaFees() external view returns (uint256);
    function pendingYieldFee() external view returns (uint256);
    function proxiableUUID() external view returns (bytes32);
    function redeemAsAlphaWithSlippage(uint256 lsaAmount, bytes32 to, uint256 minAlphaAmount, uint256 deadline) external;
    function redeemWithSlippage(uint256 lsaAmount, uint256 minTaoAmount, uint256 deadline) external;
    function renounceOwnership() external;
    function renounceRole(bytes32 role, address callerConfirmation) external;
    function revokeRole(bytes32 role, address account) external;
    function setContractSS58Pub(bytes32 _contractSS58Pub) external;
    function setNetworkFee(uint256 _networkFee) external;
    function setTreasuryBytes32(bytes32 _treasuryBytes32) external;
    function setTreasuryFee(uint256 _fee) external;
    function setYieldFee(uint256 _yieldFee) external;
    function stakeWithSlippage(uint256 minLsaAmount, uint256 deadline) external payable;
    function staking() external view returns (address);
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
    function symbol() external view returns (string memory);
    function taoToLsaRate() external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function totalUserLsaAmount() external view returns (uint256);
    function totalValueLockedInAlpha() external view returns (uint256);
    function totalValueLockedInTao() external view returns (uint256);
    function transfer(address to, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
    function transferOwnership(address newOwner) external;
    function treasuryBytes32() external view returns (bytes32);
    function treasuryEvm() external view returns (address);
    function tvlLastUpdated() external view returns (uint256);
    function unpause() external;
    function updateTVL() external;
    function upgradeToAndCall(address newImplementation, bytes memory data) external payable;
    function version() external pure returns (string memory);
    function yieldFee() external view returns (uint256);
}
