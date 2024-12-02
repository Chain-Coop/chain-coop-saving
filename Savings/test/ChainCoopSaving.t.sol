// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {ChainCoopSaving} from "../src/ChainCoopSaving.sol";
import {YieldErc20_BreadToken} from "../src/mock/YieldErc20_BreadToken.sol";

contract SavingTest is Test {
    ChainCoopSaving public saving;
    YieldErc20_BreadToken public breadToken;

    function setUp() public {
        // Deploy the mock token and main contract before each test
        breadToken = new YieldErc20_BreadToken();
        saving = new ChainCoopSaving(address(breadToken));
        saving.setAllowedTokens(address(breadToken));
    }

    function test_user_balance_is_zero() public {
        // Ensure initial balance of the test contract is zero
        assertEq(breadToken.balanceOf(address(this)), 0);
    }

    //management
    function test_set_allow_token() public {
        // Set the token to be allowed
        
        
        assertEq(saving.isTokenAllowed(address(breadToken)),true);
    }

    //SavingTest
    //address _tokenTosaveWith,uint256 _savedAmount,uint256 _goalAmount,string calldata _reason,uint256 _duration
    function test_openSavingPool() public {
        // Open a new saving pool
        saving.openSavingPool(address(breadToken), 10, 1000, "Buy A new Meme Coin",100);

        // Check that the pool has been created
        assertEq(saving.poolCount(), 1);
      


    }
}
