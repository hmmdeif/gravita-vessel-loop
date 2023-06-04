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

    uint256 col = 10000e18;
    uint256 debt = (col * 9901 / 10000) - (col * 5 / 1000);
    address owner = address(0x1);

    function setUp() public {
        mainnetFork = vm.createFork(MAINNET_RPC_URL);
        vm.selectFork(mainnetFork);
        vm.rollFork(17359884);

        deal(MAINNET_BLUSD, owner, 1000000e18);
    }

    function test_RevertCanCloseOpenVessel() public {
        vm.selectFork(mainnetFork);
        
        FlashVessel flashVessel = new FlashVessel(
            MAINNET_BORROWER_OPERATIONS,
            MAINNET_SWAP_ROUTER,
            MAINNET_UNISWAP_FACTORY,
            MAINNET_GRAI,
            owner
        );

        vm.prank(owner);
        IERC20(MAINNET_BLUSD).approve(address(flashVessel), 2200e18); // approx 4.5x leverage
        ( address prevId, address nextId ) = getHints(col, debt);

        vm.prank(owner);
        IFlashVessel.LoopParams memory params = IFlashVessel.LoopParams({
            asset: MAINNET_BLUSD,
            token1: MAINNET_USDC,
            fee: 3000,
            flashAmount: col,            
            debtAmount: debt,
            maxDeposit: 2200e18,
            upperHint: prevId,
            lowerHint: nextId,
            swapPath: getCurveSwapHash(debt),
            swapType: IFlashVessel.SwapType.Curve
        });
        flashVessel.loop(params);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        flashVessel.close(MAINNET_BLUSD, debt);
    }

    function test_RevertCanCloseOpenVesselWhenNoDebtTokens() public {
        vm.selectFork(mainnetFork);
        
        FlashVessel flashVessel = new FlashVessel(
            MAINNET_BORROWER_OPERATIONS,
            MAINNET_SWAP_ROUTER,
            MAINNET_UNISWAP_FACTORY,
            MAINNET_GRAI,
            owner
        );

        vm.prank(owner);
        IERC20(MAINNET_BLUSD).approve(address(flashVessel), 2200e18); // approx 4.5x leverage
        ( address prevId, address nextId ) = getHints(col, debt);

        vm.prank(owner);
        IFlashVessel.LoopParams memory params = IFlashVessel.LoopParams({
            asset: MAINNET_BLUSD,
            token1: MAINNET_USDC,
            fee: 3000,
            flashAmount: col,            
            debtAmount: debt,
            maxDeposit: 2200e18,
            upperHint: prevId,
            lowerHint: nextId,
            swapPath: getCurveSwapHash(debt),
            swapType: IFlashVessel.SwapType.Curve
        });
        flashVessel.loop(params);

        vm.prank(owner);
        vm.expectRevert(bytes("STF"));
        flashVessel.close(MAINNET_BLUSD, debt);
    }

    function test_CanCloseOpenVessel() public {
        vm.selectFork(mainnetFork);
        
        FlashVessel flashVessel = new FlashVessel(
            MAINNET_BORROWER_OPERATIONS,
            MAINNET_SWAP_ROUTER,
            MAINNET_UNISWAP_FACTORY,
            MAINNET_GRAI,
            owner
        );

        vm.prank(owner);
        IERC20(MAINNET_BLUSD).approve(address(flashVessel), 2200e18); // approx 4.5x leverage

        ( address prevId, address nextId ) = getHints(col, debt);

        vm.prank(owner);
        IFlashVessel.LoopParams memory params = IFlashVessel.LoopParams({
            asset: MAINNET_BLUSD,
            token1: MAINNET_USDC,
            fee: 3000,
            flashAmount: col,            
            debtAmount: debt,
            maxDeposit: 2200e18,
            upperHint: prevId,
            lowerHint: nextId,
            swapPath: getCurveSwapHash(debt),
            swapType: IFlashVessel.SwapType.Curve
        });
        flashVessel.loop(params);

        uint256 repayDebt = IVesselManager(MAINNET_VESSEL_MANAGER).getVesselDebt(MAINNET_BLUSD, address(flashVessel));
        deal(MAINNET_GRAI, owner, repayDebt);        
        vm.prank(owner);
        IERC20(MAINNET_GRAI).approve(address(flashVessel), repayDebt);
        vm.prank(owner);
        flashVessel.close(MAINNET_BLUSD, repayDebt);

        assertEq(IVesselManager(MAINNET_VESSEL_MANAGER).getVesselStatus(MAINNET_BLUSD, address(flashVessel)), 2);
    }

    function test_CanReopenClosedVessel() public {
        vm.selectFork(mainnetFork);
        
        FlashVessel flashVessel = new FlashVessel(
            MAINNET_BORROWER_OPERATIONS,
            MAINNET_SWAP_ROUTER,
            MAINNET_UNISWAP_FACTORY,
            MAINNET_GRAI,
            owner
        );

        vm.prank(owner);
        IERC20(MAINNET_BLUSD).approve(address(flashVessel), 2200e18); // approx 4.5x leverage

        ( address prevId, address nextId ) = getHints(col, debt);

        vm.prank(owner);
        IFlashVessel.LoopParams memory params = IFlashVessel.LoopParams({
            asset: MAINNET_BLUSD,
            token1: MAINNET_USDC,
            fee: 3000,
            flashAmount: col,            
            debtAmount: debt,
            maxDeposit: 2200e18,
            upperHint: prevId,
            lowerHint: nextId,
            swapPath: getCurveSwapHash(debt),
            swapType: IFlashVessel.SwapType.Curve
        });
        flashVessel.loop(params);

        uint256 repayDebt = IVesselManager(MAINNET_VESSEL_MANAGER).getVesselDebt(MAINNET_BLUSD, address(flashVessel));
        deal(MAINNET_GRAI, owner, repayDebt);        
        vm.prank(owner);
        IERC20(MAINNET_GRAI).approve(address(flashVessel), repayDebt);
        vm.prank(owner);
        flashVessel.close(MAINNET_BLUSD, repayDebt);

        vm.prank(owner);
        IERC20(MAINNET_BLUSD).approve(address(flashVessel), 2200e18); // approx 4.5x leverage

        vm.prank(owner);
        IFlashVessel.LoopParams memory reopenParams = IFlashVessel.LoopParams({
            asset: MAINNET_BLUSD,
            token1: MAINNET_USDC,
            fee: 3000,
            flashAmount: col,            
            debtAmount: debt,
            maxDeposit: 2200e18,
            upperHint: prevId,
            lowerHint: nextId,
            swapPath: getCurveSwapHash(debt),
            swapType: IFlashVessel.SwapType.Curve
        });
        flashVessel.loop(reopenParams);
        assertEq(IVesselManager(MAINNET_VESSEL_MANAGER).getVesselStatus(MAINNET_BLUSD, address(flashVessel)), 1);
    }
}
