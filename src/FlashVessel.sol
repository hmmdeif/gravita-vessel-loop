// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import 'openzeppelin-contracts/contracts/access/Ownable.sol';
import 'Gravita-SmartContracts/contracts/Interfaces/IBorrowerOperations.sol';

import './interfaces/IFlashVessel.sol';
import './interfaces/IUniswapV3FlashCallback.sol';
import './interfaces/IUniswapV3Pool.sol';
import './interfaces/ISwapRouter.sol';
import './interfaces/ICurveRegistry.sol';
import './interfaces/ICurveExchange.sol';

contract FlashVessel is IFlashVessel, IUniswapV3FlashCallback, Ownable {
    IBorrowerOperations private immutable _borrowerOperations;
    ISwapRouter private immutable _swapRouter;
    address private immutable _factory;
    address private immutable _grai;
    ICurveExchange private immutable _crvExchange;
    ICurveRegistry private _crvRegistry = ICurveRegistry(address(0x0000000022D53366457F9d5E68Ec105046FC4383));
    bool private _hasVessel = false;

    constructor(
        address borrowerOperations,
        address swapRouter,
        address factory,
        address grai,
        address owner
    ) {
        _borrowerOperations = IBorrowerOperations(borrowerOperations);
        _swapRouter = ISwapRouter(swapRouter);
        _factory = factory;
        _grai = grai;

        _crvExchange = ICurveExchange(_crvRegistry.get_address(2));

        transferOwnership(owner);
    }

    /// @notice Flashloan asset from Uniswap V3 pool and open a vessel with it
    /// @param params asset, token1, fee, flashAmount
    /// @dev token1 is the token that is not asset
    /// @dev fee is the pool fee (3000, 500, or 100)
    /// @dev flashAmount is the amount of asset to flashloan
    /// @dev debtAmount is the amount of grai to be minted
    /// @dev upperHint and lowerHint are the hints for insertion point (calculated off chain)
    /// @dev swapPath is the abi.encodeWithSignature swap route on curve for grai -> asset (calculated off chain)
    /// @dev maxDeposit is the max amount of asset the caller is willing to use (slippage protection)
    /// @dev opened vessel will approx. 4.5x leverage held amount
    function loop(
        LoopParams calldata params
    ) external override onlyOwner {
        PoolAddress.PoolKey memory poolKey =
            PoolAddress.getPoolKey(params.asset, params.token1, params.fee);
        IUniswapV3Pool pool = IUniswapV3Pool(PoolAddress.computeAddress(_factory, poolKey));

        uint256 amount0 = 0;
        uint256 amount1 = 0;
        if (pool.token0() == params.asset) {
            amount0 = params.flashAmount;
        } else {
            amount1 = params.flashAmount;
        }

        pool.flash(
            address(this),
            amount0,
            amount1,
            abi.encode(
                FlashCallbackData({
                    asset: params.asset,
                    flashAmount: params.flashAmount,
                    fee: params.fee,
                    payer: msg.sender,
                    poolKey: poolKey,
                    upperHint: params.upperHint,
                    lowerHint: params.lowerHint,
                    debtAmount: params.debtAmount,
                    maxDeposit: params.maxDeposit,
                    swapPath: params.swapPath,
                    swapType: params.swapType
                })
            )
        );
    }

    function uniswapV3FlashCallback(
        uint256 fee0, 
        uint256 fee1, 
        bytes calldata data
    ) external override {
        FlashCallbackData memory decoded = abi.decode(data, (FlashCallbackData));
        IUniswapV3Pool pool = IUniswapV3Pool(PoolAddress.computeAddress(_factory, decoded.poolKey));
        require(msg.sender == address(pool), "ICB");

        // adjust vessel if exists, or open vessel with flashloaned asset and mint grai as debt
        if (_hasVessel) {
            TransferHelper.safeApprove(decoded.asset, address(_borrowerOperations), decoded.flashAmount);
            _borrowerOperations.adjustVessel(decoded.asset, decoded.flashAmount, 0, decoded.debtAmount, true, decoded.upperHint, decoded.lowerHint);
        } else {
            openVessel(decoded.asset, decoded.flashAmount, decoded.debtAmount, decoded.upperHint, decoded.lowerHint);
            _hasVessel = true;
        }        

        // swap debt token back to asset using multihop swap grai -> asset
        uint256 swappedasset;
        if (decoded.swapType == SwapType.Curve) {
            swappedasset = swapDebtToCollateralCurve(decoded.debtAmount, decoded.swapPath);
        } else {
            swappedasset = swapDebtToCollateralUniswapV3(decoded.debtAmount, decoded.swapPath);
        }

        uint256 amount0Owed = fee0;
        uint256 amount1Owed = fee1;
        uint256 assetNeeded;
        if (pool.token0() == decoded.asset) {
            amount0Owed += decoded.flashAmount;
            assetNeeded = amount0Owed;
        } else {
            amount1Owed += decoded.flashAmount;
            assetNeeded = amount1Owed;
        }

        if (assetNeeded > swappedasset) {
            uint256 transferAmount = assetNeeded - swappedasset;
            require(transferAmount <= decoded.maxDeposit, "SWAP_SLIPPAGE_TOO_HIGH");
            TransferHelper.safeTransferFrom(decoded.asset, decoded.payer, address(this), transferAmount);
        }
        
        // pay back flashloan (N.B. needs some deposit from caller to pay fee)
        TransferHelper.safeApprove(decoded.poolKey.token0, address(this), amount0Owed);
        TransferHelper.safeApprove(decoded.poolKey.token1, address(this), amount1Owed);

        if (amount0Owed > 0) pay(decoded.poolKey.token0, address(this), msg.sender, amount0Owed);
        if (amount1Owed > 0) pay(decoded.poolKey.token1, address(this), msg.sender, amount1Owed);
    }

    function unlockDebt(
        address asset,
        uint256 amount,
        address upperHint,
        address lowerHint
    ) external override onlyOwner {
        _borrowerOperations.withdrawDebtTokens(asset, amount, upperHint, lowerHint);
        TransferHelper.safeTransfer(_grai, msg.sender, amount);
    }

    function close(
        address asset,
        uint256 debt
    ) external override onlyOwner {        
        TransferHelper.safeTransferFrom(_grai, msg.sender, address(this), debt);
        TransferHelper.safeApprove(_grai, address(_borrowerOperations), debt);
        _borrowerOperations.closeVessel(asset);
        _hasVessel = false;
    }

    function openVessel(
        address col, 
        uint256 colAmount, 
        uint256 debtAmount,
        address upperHint,
        address lowerHint
    ) internal {
        TransferHelper.safeApprove(col, address(_borrowerOperations), colAmount);
        _borrowerOperations.openVessel(
            col,
            colAmount,
            debtAmount,
            upperHint,
            lowerHint
        );
    }

    function swapDebtToCollateralCurve(
        uint256 debtAmount,
        bytes memory swapPath
    ) internal returns (uint256) {
        TransferHelper.safeApprove(_grai, address(_crvExchange), debtAmount);
        (bool success, bytes memory result) = address(_crvExchange).call(swapPath);
        require(success, "SWAP_FAILED");
        return abi.decode(result, (uint256));
    }

    function swapDebtToCollateralUniswapV3(
        uint256 debtAmount,
        bytes memory path
    ) internal returns (uint256) {
        ISwapRouter.ExactInputParams  memory params = ISwapRouter.ExactInputParams ({
            path: path,
            recipient: address(this),
            deadline: block.timestamp,
            amountIn: debtAmount,
            amountOutMinimum: 0 // doesn't matter because amountOut goes to flashloan payback
        });
        TransferHelper.safeApprove(_grai, address(_swapRouter), debtAmount);
        return _swapRouter.exactInput(params);
    }

    function pay(
        address token,
        address payer,
        address recipient,
        uint256 value
    ) internal {
        if (payer == address(this)) {
            // pay with tokens already in the contract (for the exact input multihop case)
            TransferHelper.safeTransfer(token, recipient, value);
        } else {
            // pull payment
            TransferHelper.safeTransferFrom(token, payer, recipient, value);
        }
    }
}