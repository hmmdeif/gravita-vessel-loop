// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "forge-std/Test.sol";

import { IVesselManager } from "Gravita-SmartContracts/contracts/Interfaces/IVesselManager.sol";
import { IVesselManagerOperations } from "Gravita-SmartContracts/contracts/Interfaces/IVesselManagerOperations.sol";
import { ISortedVessels } from "Gravita-SmartContracts/contracts/Interfaces/ISortedVessels.sol";
import { IAdminContract } from "Gravita-SmartContracts/contracts/Interfaces/IAdminContract.sol";
import { IERC20 } from 'openzeppelin-contracts/contracts/interfaces/IERC20.sol';

contract TestHelpers is Test {
    string public MAINNET_RPC_URL = vm.envString("MAINNET_RPC_URL");
    address public MAINNET_BLUSD = address(0xB9D7DdDca9a4AC480991865EfEf82E01273F79C3);
    address public MAINNET_GRAI = address(0x15f74458aE0bFdAA1a96CA1aa779D715Cc1Eefe4);
    address public MAINNET_USDC = address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    address public MAINNET_SORTED_VESSELS = address(0xF31D88232F36098096d1eB69f0de48B53a1d18Ce);
    address public MAINNET_BORROWER_OPERATIONS = address(0x2bCA0300c2aa65de6F19c2d241B54a445C9990E2);
    address public MAINNET_SWAP_ROUTER = address(0xE592427A0AEce92De3Edee1F18E0157C05861564);
    address public MAINNET_UNISWAP_FACTORY = address(0x1F98431c8aD98523631AE4a59f267346ea31F984);
    address public MAINNET_VESSEL_MANAGER = address(0xdB5DAcB1DFbe16326C3656a88017f0cB4ece0977);
    address public MAINNET_VESSEL_MANAGER_OPERATIONS = address(0xc49B737fa56f9142974a54F6C66055468eC631d0);
    address public MAINNET_ADMIN_CONTRACT = address(0xf7Cc67326F9A1D057c1e4b110eF6c680B13a1f53);
    address public MAINNET_BLUSD_CURVE_POOL = address(0x74ED5d42203806c8CDCf2F04Ca5F60DC777b901c);
    address public MAINNET_GRAI_CURVE_POOL = address(0x3175f54A354C83e8ADe950c14FA3e32fc794c0Dc);
    address public MAINNET_3POOL = address(0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7);
    address public MAINNET_3CRV = address(0x6c3F90f043a72FA612cbac8115EE7e52BDe6E490);
    address public MAINNET_LUSD_3POOL = address(0xEd279fDD11cA84bEef15AF5D39BB4d4bEE23F0cA);
    address public MAINNET_LUSD = address(0x5f98805A4E8be255a32880FDeC7F6728C6568bA0);

    uint256[3][4] swapParams = [[0, 2, 2], [1, 0, 8], [1, 0, 7], [1, 0, 3]];

    function getHints(uint256 col, uint256 debt) internal returns (address, address) {
        uint256 nicr = IVesselManagerOperations(MAINNET_VESSEL_MANAGER_OPERATIONS).computeNominalCR(col, debt);
        uint256 size = ISortedVessels(MAINNET_SORTED_VESSELS).getSize(MAINNET_BLUSD);
        ( address hintAddress, , ) = IVesselManagerOperations(MAINNET_VESSEL_MANAGER_OPERATIONS).getApproxHint(MAINNET_BLUSD, nicr, size, 1337);
        ( address prevId, address nextId ) = ISortedVessels(MAINNET_SORTED_VESSELS).findInsertPosition(MAINNET_BLUSD, nicr, hintAddress, hintAddress);
        return (prevId, nextId);
    }

    function getCurveSwapHash(uint256 amount) internal view returns (bytes memory) {        
        return abi.encodeWithSignature("exchange_multiple(address[9],uint256[3][4],uint256,uint256)", [MAINNET_GRAI, MAINNET_GRAI_CURVE_POOL, MAINNET_USDC, MAINNET_3POOL, MAINNET_3CRV, MAINNET_LUSD_3POOL, MAINNET_LUSD_3POOL, MAINNET_BLUSD_CURVE_POOL, MAINNET_BLUSD], swapParams, amount, 0);
    }

    function getUniswapSwapPath() internal view returns (bytes memory) {
        return abi.encodePacked(MAINNET_GRAI, uint24(500), MAINNET_USDC, uint24(500), MAINNET_LUSD, uint24(500), MAINNET_BLUSD);
    }
}