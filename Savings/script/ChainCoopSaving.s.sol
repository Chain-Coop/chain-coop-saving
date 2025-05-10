// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {ChainCoopSaving} from "../src/ChainCoopSaving.sol";

contract ChainCoopSavingScript is Script {
    ChainCoopSaving public chainCoopSaving;
    address public tokenAddress = 0xcab4981B2C0c843142B7e0D05Ac98DE00d8299C4; // WETH

    function setUp() public {}

    function run() public {
        vm.startBroadcast();
        chainCoopSaving = new ChainCoopSaving(tokenAddress);
        console.log("ChainCoopSaving deployed at: ", address(chainCoopSaving));
        vm.stopBroadcast();}
}
