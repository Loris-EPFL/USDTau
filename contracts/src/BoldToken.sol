// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "./Interfaces/IBoldToken.sol";
import {OFTCore} from "@layerzerolabs/oft-evm/contracts/OFTCore.sol";

/*
 * --- Functionality added specific to the BoldToken ---
 *
 * 1) Transfer protection: blacklist of addresses that are invalid recipients (i.e. core Liquity contracts) in external
 * transfer() and transferFrom() calls. The purpose is to protect users from losing tokens by mistakenly sending BOLD directly to a Liquity
 * core contract, when they should rather call the right function.
 *
 * 2) sendToPool() and returnFromPool(): functions callable only Liquity core contracts, which move BOLD tokens between Liquity <-> user.
 */

contract BoldToken is OFTCore, IBoldToken, ERC20Permit {
    string internal constant _NAME = "USDTau Stablecoin";
    string internal constant _SYMBOL = "USDTau";

    // --- Addresses ---
    address public immutable lzEndpoint = 0x6F475642a6e85809B1c36Fa62763669b1b48DD5B; // LayerZero endpoint on Subtensor EVM
    address public collateralRegistryAddress;
    mapping(address => bool) _troveManagerAddresses;
    mapping(address => bool) _stabilityPoolAddresses;
    mapping(address => bool) _borrowerOperationsAddresses;
    mapping(address => bool) _activePoolAddresses;

    // --- Events ---
    event CollateralRegistryAddressChanged(address _newCollateralRegistryAddress);
    event TroveManagerAddressAdded(address _newTroveManagerAddress);
    event StabilityPoolAddressAdded(address _newStabilityPoolAddress);
    event BorrowerOperationsAddressAdded(address _newBorrowerOperationsAddress);
    event ActivePoolAddressAdded(address _newActivePoolAddress);

    constructor(address _owner) OFTCore(decimals(), lzEndpoint, _owner) ERC20(_NAME, _SYMBOL) ERC20Permit(_NAME) {
        transferOwnership(_owner); //Ownable has no parameter owner here, so ownership is transferred to msg.sender first. We then transfer back to the actual deployer
    }

    function setBranchAddresses(
        address _troveManagerAddress,
        address _stabilityPoolAddress,
        address _borrowerOperationsAddress,
        address _activePoolAddress
    ) external override onlyOwner {
        _troveManagerAddresses[_troveManagerAddress] = true;
        emit TroveManagerAddressAdded(_troveManagerAddress);

        _stabilityPoolAddresses[_stabilityPoolAddress] = true;
        emit StabilityPoolAddressAdded(_stabilityPoolAddress);

        _borrowerOperationsAddresses[_borrowerOperationsAddress] = true;
        emit BorrowerOperationsAddressAdded(_borrowerOperationsAddress);

        _activePoolAddresses[_activePoolAddress] = true;
        emit ActivePoolAddressAdded(_activePoolAddress);
    }

    function setCollateralRegistry(address _collateralRegistryAddress) external override onlyOwner {
        collateralRegistryAddress = _collateralRegistryAddress;
        emit CollateralRegistryAddressChanged(_collateralRegistryAddress);

        renounceOwnership();
    }

    // --- Functions for intra-Liquity calls ---

    function mint(address _account, uint256 _amount) external override {
        _requireCallerIsBOorAP();
        _mint(_account, _amount);
    }

    function burn(address _account, uint256 _amount) external override {
        _requireCallerIsCRorBOorTMorSP();
        _burn(_account, _amount);
    }

    function sendToPool(address _sender, address _poolAddress, uint256 _amount) external override {
        _requireCallerIsStabilityPool();
        _transfer(_sender, _poolAddress, _amount);
    }

    function returnFromPool(address _poolAddress, address _receiver, uint256 _amount) external override {
        _requireCallerIsStabilityPool();
        _transfer(_poolAddress, _receiver, _amount);
    }

    // --- External functions ---

    function transfer(address recipient, uint256 amount) public override(ERC20, IERC20) returns (bool) {
        _requireValidRecipient(recipient);
        return super.transfer(recipient, amount);
    }

    function transferFrom(address sender, address recipient, uint256 amount)
        public
        override(ERC20, IERC20)
        returns (bool)
    {
        _requireValidRecipient(recipient);
        return super.transferFrom(sender, recipient, amount);
    }

    // --- Override functions to resolve inheritance conflicts ---

    function nonces(address owner) public view virtual override(ERC20Permit, IERC20Permit) returns (uint256) {
        return super.nonces(owner);
    }

    // --- 'require' functions ---

    function _requireValidRecipient(address _recipient) internal view {
        require(
            _recipient != address(0) && _recipient != address(this),
            "BoldToken: Cannot transfer tokens directly to the Bold token contract or the zero address"
        );
    }

    function _requireCallerIsBOorAP() internal view {
        require(
            _borrowerOperationsAddresses[msg.sender] || _activePoolAddresses[msg.sender],
            "BoldToken: Caller is not BO or AP"
        );
    }

    function _requireCallerIsCRorBOorTMorSP() internal view {
        require(
            msg.sender == collateralRegistryAddress || _borrowerOperationsAddresses[msg.sender]
                || _troveManagerAddresses[msg.sender] || _stabilityPoolAddresses[msg.sender],
            "BoldToken: Caller is neither CR nor BorrowerOperations nor TroveManager nor StabilityPool"
        );
    }

    function _requireCallerIsStabilityPool() internal view {
        require(_stabilityPoolAddresses[msg.sender], "BoldToken: Caller is not the StabilityPool");
    }

    /**
     * @dev Overrides the _msgSender() function from Context.sol to resolve the inheritance conflict
     * between OFTCore (via Ownable) and ERC20Permit (via ERC20). Both base contracts use the same
     * implementation, so calling super._msgSender() is safe.
     */
    function _msgSender() internal view virtual override returns (address) {
        return super._msgSender();
    }

    /**
     * @dev Overrides the _msgData() function from Context.sol to resolve the inheritance conflict.
     */
    function _msgData() internal view virtual override returns (bytes calldata) {
        return super._msgData();
    }

    /**
     * @dev Overrides the _contextSuffixLength() function from Context.sol to resolve the inheritance conflict.
     */
    function _contextSuffixLength() internal view virtual override returns (uint256) {
        return super._contextSuffixLength();
    }

    
    /**
     * @dev Retrieves the address of the underlying ERC20 implementation.
     * @return The address of the OFT token.
     *
     * @dev In the case of OFT, address(this) and erc20 are the same contract.
     */
    function token() public view returns (address) {
        return address(this);
    }

    
    /**
     * @notice Indicates whether the OFT contract requires approval of the 'token()' to send.
     * @return requiresApproval Needs approval of the underlying token implementation.
     *
     * @dev In the case of OFT where the contract IS the token, approval is NOT required.
     */
    function approvalRequired() external pure virtual returns (bool) {
        return false;
    }

    /**
     * @dev Burns tokens from the sender's specified balance.
     * @param _from The address to debit the tokens from.
     * @param _amountLD The amount of tokens to send in local decimals.
     * @param _minAmountLD The minimum amount to send in local decimals.
     * @param _dstEid The destination chain ID.
     * @return amountSentLD The amount sent in local decimals.
     * @return amountReceivedLD The amount received in local decimals on the remote.
     */
    function _debit(
        address _from,
        uint256 _amountLD,
        uint256 _minAmountLD,
        uint32 _dstEid
    ) internal virtual override returns (uint256 amountSentLD, uint256 amountReceivedLD) {
        (amountSentLD, amountReceivedLD) = _debitView(_amountLD, _minAmountLD, _dstEid);

        // @dev In NON-default OFT, amountSentLD could be 100, with a 10% fee, the amountReceivedLD amount is 90,
        // therefore amountSentLD CAN differ from amountReceivedLD.

        // @dev Default OFT burns on src.
        _burn(_from, amountSentLD);
    }

    /**
     * @dev Credits tokens to the specified address.
     * @param _to The address to credit the tokens to.
     * @param _amountLD The amount of tokens to credit in local decimals.
     * @dev _srcEid The source chain ID.
     * @return amountReceivedLD The amount of tokens ACTUALLY received in local decimals.
     */
    function _credit(
        address _to,
        uint256 _amountLD,
        uint32 /*_srcEid*/
    ) internal virtual override returns (uint256 amountReceivedLD) {
        if (_to == address(0x0)) _to = address(0xdead); // _mint(...) does not support address(0x0)
        // @dev Default OFT mints on dst.
        _mint(_to, _amountLD);
        // @dev In the case of NON-default OFT, the _amountLD MIGHT not be == amountReceivedLD.
        return _amountLD;
    }
}
