// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {ChainCoopSaving} from "../src/ChainCoopSaving.sol";

contract ChainCoopSavingScript is Script {
    ChainCoopSaving public chainCoopSaving;
    address public tokenAddress = 0xf7f007dc8Cb507e25e8b7dbDa600c07FdCF9A75B; // WETH

    function setUp() public {}

    function run() public {
        vm.startBroadcast();
        chainCoopSaving = new ChainCoopSaving(tokenAddress);
        console.log("ChainCoopSaving deployed at: ", address(chainCoopSaving));
        vm.stopBroadcast();}
}
