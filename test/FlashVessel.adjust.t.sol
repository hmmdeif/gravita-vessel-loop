// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "forge-std/Test.sol";

import { IVesselManager } from "Gravita-SmartContracts/contracts/Interfaces/IVesselManager.sol";
import { IVesselManagerOperations } from "Gravita-SmartContracts/contracts/Interfaces/IVesselManagerOperations.sol";
import { ISortedVessels } from "Gravita-SmartContracts/contracts/Interfaces/ISortedVessels.sol";
import { IAdminContract } from "Gravita-SmartContracts/contracts/Interfaces/IAdminContract.sol";
import { IERC20 } from 'openzeppelin-contracts/contracts/interfaces/IERC20.sol';
import { TestHelpers } from "./TestHelpers.t.sol";

import { FlashVessel, IFlashVessel } from "src/FlashVessel.sol";

contract FlashVesselAdjustTest is TestHelpers {
    uint256 mainnetFork;

    uint256 beforeCol = 50000e18;
    uint256 beforeDebt = (beforeCol * 9901 / 10000) - (beforeCol * 5 / 1000);
    uint256 afterCol = 50000e18;
    uint256 afterDebt = (afterCol * 9901 / 10000) - (afterCol * 5 / 1000);
    address owner = address(0x1);

    function setUp() public {
        mainnetFork = vm.createFork(MAINNET_RPC_URL);
        vm.selectFork(mainnetFork);
        vm.rollFork(17359884); // recent mint cap 17401924

        deal(MAINNET_BLUSD, owner, 1000000e18);
    }

    function test_CanAdjustOpenVessel() public {
        vm.selectFork(mainnetFork);
        
        FlashVessel flashVessel = new FlashVessel(
            MAINNET_BORROWER_OPERATIONS,
            MAINNET_SWAP_ROUTER,
            MAINNET_UNISWAP_FACTORY,
            MAINNET_GRAI,
            owner
        );

        vm.prank(owner);
        IERC20(MAINNET_BLUSD).approve(address(flashVessel), 22000e18); // approx 4.5x leverage

        ( address prevId, address nextId ) = getHints(beforeCol, beforeDebt);

        vm.prank(owner);
        IFlashVessel.LoopParams memory params = IFlashVessel.LoopParams({
            asset: MAINNET_BLUSD,
            token1: MAINNET_USDC,
            fee: 3000,
            flashAmount: beforeCol,            
            debtAmount: beforeDebt,
            maxDeposit: 10000e18,
            upperHint: prevId,
            lowerHint: nextId,
            swapPath: getCurveSwapHash(beforeDebt),
            swapType: IFlashVessel.SwapType.Curve
        });
        flashVessel.loop(params);

        assertEq(IVesselManager(MAINNET_VESSEL_MANAGER).getVesselColl(MAINNET_BLUSD, address(flashVessel)), beforeCol);
        assertEq(IVesselManager(MAINNET_VESSEL_MANAGER).getVesselStatus(MAINNET_BLUSD, address(flashVessel)), 1);

        vm.prank(owner);
        IFlashVessel.LoopParams memory afterParams = IFlashVessel.LoopParams({
            asset: MAINNET_BLUSD,
            token1: MAINNET_USDC,
            fee: 3000,
            flashAmount: afterCol,            
            debtAmount: afterDebt,
            maxDeposit: 12000e18, // slippage higher for second call
            upperHint: prevId,
            lowerHint: nextId,
            swapPath: getCurveSwapHash(afterDebt),
            swapType: IFlashVessel.SwapType.Curve
        });
        flashVessel.loop(afterParams);

        assertEq(IVesselManager(MAINNET_VESSEL_MANAGER).getVesselColl(MAINNET_BLUSD, address(flashVessel)), afterCol + beforeCol);
        assertEq(IVesselManager(MAINNET_VESSEL_MANAGER).getVesselStatus(MAINNET_BLUSD, address(flashVessel)), 1);
    }
}
