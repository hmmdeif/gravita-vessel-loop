// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../libraries/PoolAddress.sol";
import "../libraries/TransferHelper.sol";

interface IFlashVessel {
    enum SwapType {
        Uniswap,
        Curve
    }

    struct LoopParams {
        address asset;
        address token1;
        uint24 fee;
        uint256 flashAmount;
        uint256 debtAmount;
        uint256 maxDeposit;
        address upperHint;
        address lowerHint;
        bytes swapPath;
        SwapType swapType;

    }

    struct FlashCallbackData {
        address asset;
        uint256 flashAmount;
        uint256 debtAmount;
        uint256 maxDeposit;
        uint24 fee;
        address payer;
        PoolAddress.PoolKey poolKey;
        address upperHint;
        address lowerHint;
        bytes swapPath;
        SwapType swapType;
    }

    function loop(
        LoopParams calldata params
    ) external;

    function unlockDebt(
        address asset,
        uint256 amount,
        address upperHint,
        address lowerHint
    ) external;

    function close(
        address asset,
        uint256 debt
    ) external;
}