// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

import {Script, console} from "forge-std/Script.sol";
import {ChainCoopSaving} from "../src/ChainCoopSaving.sol";
import {ERC2771Forwarder} from "@openzeppelin/contracts/metatx/ERC2771Forwarder.sol";

contract ChainCoopSavingScript is Script {
    ChainCoopSaving public chainCoopSaving;
    ERC2771Forwarder public forwarder;

    address public tokenAddress = 0xc2132D05D31c914a87C6611C10748AEb04B58e8F;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        // Deploy the OpenZeppelin MinimalForwarder
        forwarder = new ERC2771Forwarder("ChainCoopForwarder");
        console.log("ERC2771 Forwarder deployed at:", address(forwarder));

        // Deploy ChainCoopSaving with the forwarder
        chainCoopSaving = new ChainCoopSaving(tokenAddress, address(forwarder));
        console.log("ChainCoopSaving deployed at:", address(chainCoopSaving));

        vm.stopBroadcast();
    }
}
