// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IUniswapV3Pool} from "../Exchanges/UniswapV3/IUniswapV3Pool.sol";
import "./Balancer/vault/IFlashLoanRecipient.sol";
import "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "../../Interfaces/ILeverageZapper.sol";
import "../../Interfaces/IFlashLoanReceiver.sol";
import "../../Interfaces/IFlashLoanProvider.sol";

//TODO test this shit
contract UniswapFlashLoan is IFlashLoanRecipient, IFlashLoanProvider {
    using SafeERC20 for IERC20;

    IFlashLoanReceiver public receiver;

    struct FlashCallbackData {
        IERC20 requestedToken;
        uint256 requestedAmount;
        Operation operation;
        bytes params;
        address caller;
    }

    IUniswapV3Pool private immutable pool;
    IERC20 private immutable token0;
    IERC20 private immutable token1;

    constructor(address _pool) {
        pool = IUniswapV3Pool(_pool);
        token0 = IERC20(pool.token0());
        token1 = IERC20(pool.token1());
    }

    function makeFlashLoan(IERC20 _token, uint256 _amount, Operation _operation, bytes calldata _params) external {
        // Determine which token is being requested and set amounts accordingly
        uint256 amount0 = 0;
        uint256 amount1 = 0;
        
        if (address(_token) == address(token0)) {
            amount0 = _amount;
        } else if (address(_token) == address(token1)) {
            amount1 = _amount;
        } else {
            revert("Token not supported by this pool");
        }

        // Data for the callback
        bytes memory userData;
        if (_operation == Operation.OpenTrove) {
            ILeverageZapper.OpenLeveragedTroveParams memory openTroveParams =
                abi.decode(_params, (ILeverageZapper.OpenLeveragedTroveParams));
            userData = abi.encode(_operation, openTroveParams);
        } else if (_operation == Operation.LeverUpTrove) {
            ILeverageZapper.LeverUpTroveParams memory leverUpTroveParams =
                abi.decode(_params, (ILeverageZapper.LeverUpTroveParams));
            userData = abi.encode(_operation, leverUpTroveParams);
        } else if (_operation == Operation.LeverDownTrove) {
            ILeverageZapper.LeverDownTroveParams memory leverDownTroveParams =
                abi.decode(_params, (ILeverageZapper.LeverDownTroveParams));
            userData = abi.encode(_operation, leverDownTroveParams);
        } else if (_operation == Operation.CloseTrove) {
            IZapper.CloseTroveParams memory closeTroveParams = abi.decode(_params, (IZapper.CloseTroveParams));
            userData = abi.encode(_operation, closeTroveParams);
        } else {
            revert("LZ: Wrong Operation");
        }

        // Store the receiver for the callback
        receiver = IFlashLoanReceiver(msg.sender);

        // Encode callback data
        bytes memory callbackData = abi.encode(
            FlashCallbackData({
                requestedToken: _token,
                requestedAmount: _amount,
                operation: _operation,
                params: userData,
                caller: msg.sender
            })
        );

        // Initiate flash loan
        pool.flash(address(this), amount0, amount1, callbackData);
    }

    function uniswapV3FlashCallback(
        uint256 fee0,
        uint256 fee1,
        bytes calldata data
    ) external {
        require(msg.sender == address(pool), "Caller is not pool");
        require(address(receiver) != address(0), "Flash loan not properly initiated");

        FlashCallbackData memory decoded = abi.decode(data, (FlashCallbackData));

        // Calculate fees for the requested token
        uint256 feeAmount = 0;
        if (address(decoded.requestedToken) == address(token0)) {
            feeAmount = fee0;
        } else if (address(decoded.requestedToken) == address(token1)) {
            feeAmount = fee1;
        }

        // Prepare arrays for compatibility with Balancer interface
        IERC20[] memory tokens = new IERC20[](1);
        tokens[0] = decoded.requestedToken;
        
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = decoded.requestedAmount;
        
        uint256[] memory feeAmounts = new uint256[](1);
        feeAmounts[0] = feeAmount;

        // Call the standard receiveFlashLoan function to maintain compatibility
        this.receiveFlashLoan(tokens, amounts, feeAmounts, decoded.params);
    }

    function receiveFlashLoan(
        IERC20[] calldata tokens,
        uint256[] calldata amounts,
        uint256[] calldata feeAmounts,
        bytes calldata userData
    ) external override {
        require(msg.sender == address(this), "Only self can call");
        require(address(receiver) != address(0), "Flash loan not properly initiated");

        // Cache and reset receiver for CEI pattern
        IFlashLoanReceiver receiverCached = receiver;
        receiver = IFlashLoanReceiver(address(0));

        // Decode operation
        Operation operation = abi.decode(userData[0:32], (Operation));

        if (operation == Operation.OpenTrove) {
            // Open trove
            ILeverageZapper.OpenLeveragedTroveParams memory openTroveParams =
                abi.decode(userData[32:], (ILeverageZapper.OpenLeveragedTroveParams));
            // Flash loan minus fees
            uint256 effectiveFlashLoanAmount = amounts[0] - feeAmounts[0];
            // Send effective flash loan to receiver, keeping fees here
            tokens[0].safeTransfer(address(receiverCached), effectiveFlashLoanAmount);
            // Zapper callback
            receiverCached.receiveFlashLoanOnOpenLeveragedTrove(openTroveParams, effectiveFlashLoanAmount);
        } else if (operation == Operation.LeverUpTrove) {
            // Lever up
            ILeverageZapper.LeverUpTroveParams memory leverUpTroveParams =
                abi.decode(userData[32:], (ILeverageZapper.LeverUpTroveParams));
            // Flash loan minus fees
            uint256 effectiveFlashLoanAmount = amounts[0] - feeAmounts[0];
            // Send effective flash loan to receiver, keeping fees here
            tokens[0].safeTransfer(address(receiverCached), effectiveFlashLoanAmount);
            // Zapper callback
            receiverCached.receiveFlashLoanOnLeverUpTrove(leverUpTroveParams, effectiveFlashLoanAmount);
        } else if (operation == Operation.LeverDownTrove) {
            // Lever down
            ILeverageZapper.LeverDownTroveParams memory leverDownTroveParams =
                abi.decode(userData[32:], (ILeverageZapper.LeverDownTroveParams));
            // Flash loan minus fees
            uint256 effectiveFlashLoanAmount = amounts[0] - feeAmounts[0];
            // Send effective flash loan to receiver, keeping fees here
            tokens[0].safeTransfer(address(receiverCached), effectiveFlashLoanAmount);
            // Zapper callback
            receiverCached.receiveFlashLoanOnLeverDownTrove(leverDownTroveParams, effectiveFlashLoanAmount);
        } else if (operation == Operation.CloseTrove) {
            // Close trove
            IZapper.CloseTroveParams memory closeTroveParams = abi.decode(userData[32:], (IZapper.CloseTroveParams));
            // Flash loan minus fees
            uint256 effectiveFlashLoanAmount = amounts[0] - feeAmounts[0];
            // Send effective flash loan to receiver, keeping fees here
            tokens[0].safeTransfer(address(receiverCached), effectiveFlashLoanAmount);
            // Zapper callback
            receiverCached.receiveFlashLoanOnCloseTroveFromCollateral(closeTroveParams, effectiveFlashLoanAmount);
        } else {
            revert("LZ: Wrong Operation");
        }

        // Repay flash loan with fees to the pool
        // Determine which token to repay and calculate total repayment
        if (address(tokens[0]) == address(token0)) {
            token0.safeTransfer(address(pool), amounts[0] + feeAmounts[0]);
        } else if (address(tokens[0]) == address(token1)) {
            token1.safeTransfer(address(pool), amounts[0] + feeAmounts[0]);
        }
    }
}