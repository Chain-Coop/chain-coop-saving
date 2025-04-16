// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {ChainCoopSaving} from "../src/ChainCoopSaving.sol";

contract ChainCoopSavingScript is Script {
    ChainCoopSaving public chainCoopSaving;
    address public tokenAddress = 0x19Ea0584D2A73265251Bf8dC0Bc5A47DebF539ac; // WETH

    function setUp() public {}

    function run() public {
        vm.startBroadcast();
        chainCoopSaving = new ChainCoopSaving(tokenAddress);
        console.log("ChainCoopSaving deployed at: ", address(chainCoopSaving));
        vm.stopBroadcast();}
}
