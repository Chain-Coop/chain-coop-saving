// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

import {Script, console} from "forge-std/Script.sol";
import {ChainCoopSaving} from "../src/ChainCoopSavingv2.sol";
import {ERC2771ForwarderUpgradeable} from "@openzeppelin/contracts-upgradeable/metatx/ERC2771ForwarderUpgradeable.sol";
import {Upgrades, Options} from "@openzeppelin-foundry-upgrades/Upgrades.sol";

contract ChainCoopSavingScript is Script {
    ChainCoopSaving public chainCoopSaving;
    ERC2771ForwarderUpgradeable public forwarder;

    address public tokenAddress = 0xc2132D05D31c914a87C6611C10748AEb04B58e8F; // USDT on BSC

    // function run() public {
    //     vm.startBroadcast();

    //     // Deploy the ERC2771 Forwarder first
    //     address forwarderProxy = Upgrades.deployUUPSProxy(
    //         "ERC2771ForwarderUpgradeable.sol:ERC2771ForwarderUpgradeable",
    //         abi.encodeCall(
    //             ERC2771ForwarderUpgradeable.initialize,
    //             ("ChainCoopForwarder")
    //         )
    //     );
    //     console.log(
    //         "ERC2771ForwarderUpgradeable (UUPS Proxy) deployed at:",
    //         forwarderProxy
    //     );

    //     // Create options with constructor arguments
    //     Options memory opts;
    //     opts.constructorData = abi.encode(forwarderProxy);

    //     // Deploy ChainCoopSaving with forwarder address in constructor
    //     address savingProxy = Upgrades.deployUUPSProxy(
    //         "ChainCoopSaving.sol:ChainCoopSaving",
    //         abi.encodeCall(ChainCoopSaving.initialize, (tokenAddress)),
    //         opts
    //     );

    //     console.log("ChainCoopSaving (UUPS Proxy) deployed at:", savingProxy);

    //     vm.stopBroadcast();
    // }

    function run() public {
        vm.startBroadcast();

        // Upgrade the ChainCoopSaving contract

        Options memory opts;
        opts.referenceContract = "ChainCoopSaving.sol";
        opts.constructorData = abi.encode(
            0x7045D4eEA52bA96A2F2037b464360a43bd33e60B
        );

        Upgrades.upgradeProxy(
            0xbB22d720da22E4c793a13af71a66440965C69Bcc,
            "ChainCoopSavingv2.sol:ChainCoopSaving",
            "",
            opts
        );

        console.log(
            "ChainCoopSaving upgraded at:",
            0xbB22d720da22E4c793a13af71a66440965C69Bcc
        );

        vm.stopBroadcast();
    }
}
