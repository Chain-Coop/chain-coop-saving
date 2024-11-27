// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test,console} from "forge-std/Test.sol";
import {ChainCoopSaving} from "../src/ChainCoopSaving.sol";


contract SavingTest is Test{
    ChainCoopSaving public saving;
    function setUp()public{
        saving = new ChainCoopSaving();

    }


    
}