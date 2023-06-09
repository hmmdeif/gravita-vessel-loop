// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";

import { IVesselManager } from "Gravita-SmartContracts/contracts/Interfaces/IVesselManager.sol";
import { IVesselManagerOperations } from "Gravita-SmartContracts/contracts/Interfaces/IVesselManagerOperations.sol";
import { ISortedVessels } from "Gravita-SmartContracts/contracts/Interfaces/ISortedVessels.sol";
import { IAdminContract } from "Gravita-SmartContracts/contracts/Interfaces/IAdminContract.sol";
import { IERC20 } from 'openzeppelin-contracts/contracts/interfaces/IERC20.sol';
import { TestHelpers } from "./TestHelpers.t.sol";

import { FlashVessel, IFlashVessel } from "src/FlashVessel.sol";

contract FlashVesselOpenTest is TestHelpers {
    uint256 mainnetFork;

    uint256 col = 100000e18;
    uint256 debt = (col * 9901 / 10000) - (col * 5 / 1000);
    address owner = address(0x1);

    function setUp() public {
        mainnetFork = vm.createFork(MAINNET_RPC_URL);
        vm.selectFork(mainnetFork);
        vm.rollFork(17359884);

        deal(MAINNET_BLUSD, owner, 1000000e18);
    }

    function test_SetupState() public {
        assertEq(IERC20(MAINNET_BLUSD).balanceOf(owner) >= col, true);

        // check that the block we rolled to has space
        uint256 mintCap = IAdminContract(MAINNET_ADMIN_CONTRACT).getMintCap(MAINNET_BLUSD);
        uint256 totalDebt = IAdminContract(MAINNET_ADMIN_CONTRACT).getTotalAssetDebt(MAINNET_BLUSD);
        assertEq(mintCap > totalDebt + debt, true);
    }

    function test_RevertWhenCallerNotOwner() public {
        vm.selectFork(mainnetFork);

        FlashVessel flashVessel = new FlashVessel(
            MAINNET_BORROWER_OPERATIONS,
            MAINNET_SWAP_ROUTER,
            MAINNET_UNISWAP_FACTORY,
            MAINNET_GRAI,
            owner
        );

        vm.prank(address(0));
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        IFlashVessel.LoopParams memory params = IFlashVessel.LoopParams({
            asset: MAINNET_BLUSD,
            token1: MAINNET_USDC,
            fee: 3000,
            flashAmount: 10000e18,
            debtAmount: 9000e18,
            maxDeposit: 22000e18,
            upperHint: address(0),
            lowerHint: address(0),
            swapPath: getCurveSwapHash(9000e18),
            swapType: IFlashVessel.SwapType.Curve
        });
        flashVessel.loop(params);
    }

    function test_RevertWhenSlippageTooMuch() public {
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

        vm.prank(owner);
        vm.expectRevert(bytes("SWAP_SLIPPAGE_TOO_HIGH"));
        IFlashVessel.LoopParams memory params = IFlashVessel.LoopParams({
            asset: MAINNET_BLUSD,
            token1: MAINNET_USDC,
            fee: 3000,
            flashAmount: col,            
            debtAmount: debt,
            maxDeposit: 20000e18,
            upperHint: address(0),
            lowerHint: address(0),
            swapPath: getCurveSwapHash(debt),
            swapType: IFlashVessel.SwapType.Curve
        });
        flashVessel.loop(params);
    }

    function test_CanFlashMainnet() public {
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

        ( address prevId, address nextId ) = getHints(col, debt);

        vm.prank(owner);
        IFlashVessel.LoopParams memory params = IFlashVessel.LoopParams({
            asset: MAINNET_BLUSD,
            token1: MAINNET_USDC,
            fee: 3000,
            flashAmount: col,            
            debtAmount: debt,
            maxDeposit: 22000e18,
            upperHint: prevId,
            lowerHint: nextId,
            swapPath: getCurveSwapHash(debt),
            swapType: IFlashVessel.SwapType.Curve
        });
        flashVessel.loop(params);

        assertEq(IVesselManager(MAINNET_VESSEL_MANAGER).getVesselColl(MAINNET_BLUSD, address(flashVessel)), col);
        assertEq(IVesselManager(MAINNET_VESSEL_MANAGER).getVesselStatus(MAINNET_BLUSD, address(flashVessel)), 1);
    }
}
