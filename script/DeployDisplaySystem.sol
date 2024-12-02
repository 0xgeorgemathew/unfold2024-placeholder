// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {DisplayNFT} from "../src/OperatorRegistry.sol";
import {OperatorRegistry} from "../src/OperatorRegistry.sol";
import {AdvertisementSystem} from "../src/AdvertisementSystem.sol";
import {console} from "forge-std/console.sol";

contract DeployDisplaySystem is Script {
    function run()
        external
        returns (
            DisplayNFT displayNFT,
            OperatorRegistry operatorRegistry,
            AdvertisementSystem advertisementSystem
        )
    {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        string memory baseTokenURI = vm.envString("BASE_TOKEN_URI");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy DisplayNFT
        displayNFT = new DisplayNFT();
        console.log("DisplayNFT deployed to:", address(displayNFT));

        // Deploy OperatorRegistry with DisplayNFT address
        operatorRegistry = new OperatorRegistry(
            address(displayNFT),
            baseTokenURI
        );
        console.log("OperatorRegistry deployed to:", address(operatorRegistry));

        // Deploy AdvertisementSystem with OperatorRegistry address
        advertisementSystem = new AdvertisementSystem(
            address(operatorRegistry)
        );
        console.log(
            "AdvertisementSystem deployed to:",
            address(advertisementSystem)
        );

        // Set OperatorRegistry in DisplayNFT
        displayNFT.setOperatorRegistry(address(operatorRegistry));
        console.log("OperatorRegistry set in DisplayNFT");

        // Verify contracts on block explorer if not on local network
        if (block.chainid != 31337) {
            console.log("\nInitiating contract verification...");

            // Verify DisplayNFT
            console.log("Verifying DisplayNFT...");

            // Verify OperatorRegistry
            console.log("Verifying OperatorRegistry...");
            bytes memory operatorRegistryArgs = abi.encode(
                address(displayNFT),
                baseTokenURI
            );

            // Verify AdvertisementSystem
            console.log("Verifying AdvertisementSystem...");
            bytes memory advertisementSystemArgs = abi.encode(
                address(operatorRegistry)
            );
        }

        vm.stopBroadcast();

        // Log deployment information
        console.log("\nDeployment Summary:");
        console.log("-------------------");
        console.log("DisplayNFT:", address(displayNFT));
        console.log("OperatorRegistry:", address(operatorRegistry));
        console.log("AdvertisementSystem:", address(advertisementSystem));
        console.log("Base Token URI:", baseTokenURI);

        // Log verification instructions
    }
}
