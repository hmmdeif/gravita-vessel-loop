// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "forge-std/Script.sol";

import { FlashVessel } from "src/FlashVessel.sol";

contract FlashVesselGoerliScript is Script {
    address public GOERLI_GRAI = address(0xb0e99590cF3Ddfdc19e68F91f7fe0626790cDb53);
    address public GOERLI_BORROWER_OPERATIONS = address(0xC2AE62aC744c03E9B7288CB04abaa1E3aDBD6ec0);
    address public GOERLI_SWAP_ROUTER = address(0xE592427A0AEce92De3Edee1F18E0157C05861564);
    address public GOERLI_UNISWAP_FACTORY = address(0x1F98431c8aD98523631AE4a59f267346ea31F984);

    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address owner = vm.envAddress("OWNER");
        vm.startBroadcast(deployerPrivateKey);

        new FlashVessel(            
            GOERLI_BORROWER_OPERATIONS,
            GOERLI_SWAP_ROUTER,
            GOERLI_UNISWAP_FACTORY,
            GOERLI_GRAI,
            owner
        );

        vm.stopBroadcast();
    }
}
