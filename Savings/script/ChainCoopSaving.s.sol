// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.25;

import {Script, console} from "forge-std/Script.sol";
import {ChainCoopSaving} from "../src/ChainCoopSaving.sol";

contract ChainCoopSavingScript is Script {
    ChainCoopSaving public chainCoopSaving;
    address public tokenAddress = 0x64c5486457B886560CD7Dd4d90d5B66c99F685d1; // WETH

    function setUp() public {}

    function run() public {
        vm.startBroadcast();
        chainCoopSaving = new ChainCoopSaving(tokenAddress);
        console.log("ChainCoopSaving deployed at: ", address(chainCoopSaving));
        vm.stopBroadcast();}
}
