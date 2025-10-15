// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

interface Interface {
    error AddressEmptyCode(address target);
    error ECDSAInvalidSignature();
    error ECDSAInvalidSignatureLength(uint256 length);
    error ECDSAInvalidSignatureS(bytes32 s);
    error ERC1967InvalidImplementation(address implementation);
    error ERC1967NonPayable();
    error ERC20InsufficientAllowance(address spender, uint256 allowance, uint256 needed);
    error ERC20InsufficientBalance(address sender, uint256 balance, uint256 needed);
    error ERC20InvalidApprover(address approver);
    error ERC20InvalidReceiver(address receiver);
    error ERC20InvalidSender(address sender);
    error ERC20InvalidSpender(address spender);
    error ERC2612ExpiredSignature(uint256 deadline);
    error ERC2612InvalidSigner(address signer, address owner);
    error EnforcedPause();
    error ExpectedPause();
    error FailedInnerCall();
    error InvalidAccountNonce(address account, uint256 currentNonce);
    error InvalidInitialization();
    error NotInitializing();
    error OwnableInvalidOwner(address owner);
    error OwnableUnauthorizedAccount(address account);
    error ReentrancyGuardReentrantCall();
    error UUPSUnauthorizedCallContext();
    error UUPSUnsupportedProxiableUUID(bytes32 slot);

    event Approval(address indexed owner, address indexed spender, uint256 value);
    event EIP712DomainChanged();
    event Initialized(uint64 version);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event Paused(address account);
    event TAOStaked(address indexed signer, address indexed to, uint256 amountEvm, uint256 receivedAmount);
    event TAOUnstaked(address indexed signer, address indexed from, uint256 amountEvm, uint256 receivedAmount);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Unpaused(address account);
    event Upgraded(address indexed implementation);

    receive() external payable;

    function DOMAIN_SEPARATOR() external view returns (bytes32);
    function INITIAL_SUPPLY() external view returns (uint256);
    function MIN_STAKE_AMOUNT() external view returns (uint256);
    function MIN_STAKE_BALANCE() external view returns (uint256);
    function NAME() external view returns (string memory);
    function SYMBOL() external view returns (string memory);
    function TAOtovTAO(uint256 amountRaoDecimals) external view returns (uint256);
    function TAOtovTAO_with_current_stake(uint256 amountRaoDecimals, uint256 currentStakeRaoDecimals)
        external
        view
        returns (uint256);
    function UPGRADE_INTERFACE_VERSION() external view returns (string memory);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 value) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function burn(uint256 value) external;
    function burnFrom(address account, uint256 value) external;
    function decimals() external view returns (uint8);
    function eip712Domain()
        external
        view
        returns (
            bytes1 fields,
            string memory name,
            string memory version,
            uint256 chainId,
            address verifyingContract,
            bytes32 salt,
            uint256[] memory extensions
        );
    function getAddressAsPk() external view returns (bytes32);
    function getCurrentStake(uint16 netuid) external view returns (uint256);
    function initialize(address initialOwner) external;
    function name() external view returns (string memory);
    function nonces(address owner) external view returns (uint256);
    function owner() external view returns (address);
    function pause() external;
    function paused() external view returns (bool);
    function permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s)
        external;
    function proxiableUUID() external view returns (bytes32);
    function renounceOwnership() external;
    function stake(address to) external payable;
    function symbol() external view returns (string memory);
    function totalSupply() external view returns (uint256);
    function transfer(address to, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
    function transferOwnership(address newOwner) external;
    function unpause() external;
    function unstake(uint256 amountEvm) external;
    function upgradeToAndCall(address newImplementation, bytes memory data) external payable;
    function vTAOtoTAO(uint256 amountEvm) external view returns (uint256);
}
