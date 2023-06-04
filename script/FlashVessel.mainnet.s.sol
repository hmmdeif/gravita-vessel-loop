// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "forge-std/Script.sol";

import { FlashVessel } from "src/FlashVessel.sol";

contract FlashVesselMainnetScript is Script {
    address public MAINNET_GRAI = address(0x15f74458aE0bFdAA1a96CA1aa779D715Cc1Eefe4);
    address public MAINNET_BORROWER_OPERATIONS = address(0x2bCA0300c2aa65de6F19c2d241B54a445C9990E2);
    address public MAINNET_SWAP_ROUTER = address(0xE592427A0AEce92De3Edee1F18E0157C05861564);
    address public MAINNET_UNISWAP_FACTORY = address(0x1F98431c8aD98523631AE4a59f267346ea31F984);

    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address owner = vm.envAddress("OWNER");
        vm.startBroadcast(deployerPrivateKey);

        new FlashVessel(            
            MAINNET_BORROWER_OPERATIONS,
            MAINNET_SWAP_ROUTER,
            MAINNET_UNISWAP_FACTORY,
            MAINNET_GRAI,
            owner
        );

        vm.stopBroadcast();
    }
}
