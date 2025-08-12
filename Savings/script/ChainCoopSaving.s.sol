// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

import {Script, console} from "forge-std/Script.sol";
import {ChainCoopSaving} from "../src/ChainCoopSaving.sol";
import {ERC2771ForwarderUpgradeable} from "@openzeppelin/contracts-upgradeable/metatx/ERC2771ForwarderUpgradeable.sol";
import {Upgrades, Options} from "@openzeppelin-foundry-upgrades/Upgrades.sol";

contract ChainCoopSavingScript is Script {
    ChainCoopSaving public chainCoopSaving;
    ERC2771ForwarderUpgradeable public forwarder;

    address public tokenAddress = 0xc2132D05D31c914a87C6611C10748AEb04B58e8F; // USDT on BSC

    function run() public {
        vm.startBroadcast();

        // Deploy the ERC2771 Forwarder first
        address forwarderProxy = Upgrades.deployUUPSProxy(
            "ERC2771ForwarderUpgradeable.sol:ERC2771ForwarderUpgradeable",
            abi.encodeCall(
                ERC2771ForwarderUpgradeable.initialize,
                ("ChainCoopForwarder")
            )
        );
        console.log(
            "ERC2771ForwarderUpgradeable (UUPS Proxy) deployed at:",
            forwarderProxy
        );

        // Create options with constructor arguments
        Options memory opts;
        opts.constructorData = abi.encode(forwarderProxy);

        // Deploy ChainCoopSaving with forwarder address in constructor
        address savingProxy = Upgrades.deployUUPSProxy(
            "ChainCoopSaving.sol:ChainCoopSaving",
            abi.encodeCall(ChainCoopSaving.initialize, (tokenAddress)),
            opts
        );

        console.log("ChainCoopSaving (UUPS Proxy) deployed at:", savingProxy);

        vm.stopBroadcast();
    }
}
