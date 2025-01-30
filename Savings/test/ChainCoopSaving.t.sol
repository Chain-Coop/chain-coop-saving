// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {ChainCoopSaving} from "../src/ChainCoopSaving.sol";
import {YieldErc20_BreadToken} from "../src/mock/YieldErc20_BreadToken.sol";
import {LibChainCoopSaving} from "../src/lib/LibChainCoopSaving.sol";
import {IChainCoopSaving} from "../src/interface/IchainCoopSaving.sol";

contract SavingTest is Test {
    using LibChainCoopSaving for address;
    ChainCoopSaving public saving;
    YieldErc20_BreadToken public breadToken;
    address public owner;
    address user1;
    address user2;
    address user3;
    address user4;
    address chaincoopFees;

    function setUp() public {
        // Deploy the mock token and main contract before each test
        breadToken = new YieldErc20_BreadToken();
        saving = new ChainCoopSaving(address(breadToken));
        saving.setAllowedTokens(address(breadToken));

        owner = address(1);
        user1 = address(2);
        user2 = address(3);
        user3 = address(4);
        chaincoopFees = address(5);
        saving.setChainCoopAddress(chaincoopFees);
        breadToken.mint(user1, 1000);
        breadToken.mint(user2, 1000);
        breadToken.mint(user3, 1000);
        breadToken.mint(address(this), 1000);
    }

    function test_user_balance_is_zero() public {
        // Ensure initial balance of the test contract is zero
        vm.prank(user3);
        assertEq(breadToken.balanceOf(user3), 1000 * 10 ** 18);
    }

    //mint token

    //management
    function test_set_allow_token() public view {
        assertEq(saving.isTokenAllowed(address(breadToken)), true);
    }

    //SavingTest
    function test_openSavingPool() public {
        address tokenToSaveWith = address(breadToken);
        uint256 initialAmount = 10 * 10 ** 18; // 10 tokens scaled
        string memory reason = "Buy A new Meme Coin";
        uint256 duration = 100; // Duration in seconds

        vm.startPrank(user3);
        breadToken.approve(address(saving), initialAmount);

        // Open saving pool
        saving.openSavingPool(
            tokenToSaveWith,
            initialAmount,
            reason,
            IChainCoopSaving.LockingType.FLEXIBLE,
            duration
        );
        vm.stopPrank();

        // Retrieve and validate the pool
        ChainCoopSaving.SavingPool[] memory pools = saving.getSavingPoolBySaver(
            user3
        );
        assertEq(pools.length, 1, "User should have one saving pool");
        assertEq(pools[0].saver, user3, "Saver address mismatch");
        assertEq(
            pools[0].amountSaved,
            initialAmount,
            "Initial amount mismatch"
        );
        assertEq(pools[0].Reason, reason, "Reason mismatch");
        assertEq(pools[0].Duration, duration, "Duration mismatch");
    }

    function test_withdraw_flexible_saving() public {
        address tokenToSaveWith = address(breadToken);
        uint256 initialAmount = 10 * 10 ** 18;
        string memory reason = "Flexible Savings Test";
        uint256 duration = 100;

        vm.startPrank(user3);
        breadToken.approve(address(saving), initialAmount);
        saving.openSavingPool(
            tokenToSaveWith,
            initialAmount,
            reason,
            IChainCoopSaving.LockingType.FLEXIBLE,
            duration
        );

        ChainCoopSaving.SavingPool[] memory poolsBefore = saving
            .getSavingPoolBySaver(user3);

        assertEq(
            poolsBefore.length,
            1,
            "User should have one saving pool before withdrawal"
        );
        assertEq(
            poolsBefore[0].amountSaved,
            initialAmount,
            "Initial amount mismatch"
        );

        saving.withdraw(poolsBefore[0].poolIndex);
        (, , , , , , uint256 amountSaved, , , ) = saving.poolSavingPool(
            poolsBefore[0].poolIndex
        );
        assertEq(
            amountSaved,
            0,
            "Amount saved should be zero after withdrawal"
        );

        vm.stopPrank();
    }

    function test_get_user_pools() public {
        // Open a new saving pool
        vm.startPrank(user2);

        uint256 savedAmount = 10;
        uint256 duration = 100;
        string memory reason = "Buy a laptop";

        breadToken.approve(address(saving), savedAmount);
        saving.openSavingPool(
            address(breadToken),
            savedAmount,
            reason,
            IChainCoopSaving.LockingType.FLEXIBLE,
            duration
        );

        IChainCoopSaving.SavingPool[] memory pools = saving
            .getSavingPoolBySaver(user2);
        vm.stopPrank();

        // Assert user has one pool
        assertEq(pools.length, 1, "User should have one saving pool");

        // Validate the details of the created saving pool
        assertEq(pools[0].saver, user2, "Saver address mismatch");
        assertEq(
            pools[0].tokenToSaveWith,
            address(breadToken),
            "Token address mismatch"
        );
        assertEq(
            pools[0].amountSaved,
            savedAmount,
            "Initial saved amount mismatch"
        );
        assertEq(pools[0].Reason, reason, "Reason mismatch");
        assertEq(pools[0].Duration, duration, "Duration mismatch");
        assertTrue(
            pools[0].isGoalAccomplished,
            "Goal should be accomplished for FLEXIBLE lock type"
        );
    }

    function test_withdraw_lock_saving() public {
        address tokenToSaveWith = address(breadToken);
        uint256 initialAmount = 10 * 10 ** 18;
        string memory reason = "Lock Savings Test";
        uint256 duration = 100;

        vm.startPrank(user3);
        breadToken.approve(address(saving), initialAmount);
        saving.openSavingPool(
            tokenToSaveWith,
            initialAmount,
            reason,
            IChainCoopSaving.LockingType.LOCK,
            duration
        );
        ChainCoopSaving.SavingPool[] memory poolsBefore = saving
            .getSavingPoolBySaver(user3);
        bytes32 poolId = poolsBefore[0].poolIndex;

        uint256 balanceBefore = breadToken.balanceOf(user3);
        saving.withdraw(poolId);
        uint256 balanceAfter = breadToken.balanceOf(user3);

        uint256 expectedPenalty = LibChainCoopSaving.calculateInterest(
            initialAmount
        );
        uint256 expectedBalance = balanceBefore +
            initialAmount -
            expectedPenalty;

        assertEq(
            balanceAfter,
            expectedBalance,
            "User balance should reflect penalty deduction"
        );
        (, , , , , , uint256 amountSaved, , , ) = saving.poolSavingPool(
            poolsBefore[0].poolIndex
        );
        assertEq(
            amountSaved,
            0,
            "Amount saved should be zero after withdrawal"
        );
        vm.stopPrank();
    }

    function test_stop_saving() public {
        address tokenToSaveWith = address(breadToken);
        uint256 initialAmount = 10 * 10 ** 18;
        string memory reason = "Stop Saving Test";
        uint256 duration = 100;

        vm.startPrank(user3);
        breadToken.approve(address(saving), initialAmount);
        saving.openSavingPool(
            tokenToSaveWith,
            initialAmount,
            reason,
            IChainCoopSaving.LockingType.FLEXIBLE,
            duration
        );
        ChainCoopSaving.SavingPool[] memory poolsBefore = saving
            .getSavingPoolBySaver(user3);

        saving.stopSaving(poolsBefore[0].poolIndex);
        bytes32 _poolId = poolsBefore[0].poolIndex;

        (, , , bytes32 poolIndex, , , , , , bool isStoped) = saving
            .poolSavingPool(_poolId);

        assertEq(isStoped, true);
        vm.expectRevert();
        saving.updateSaving(poolIndex, 5 * 10 ** 18);
        vm.stopPrank();
    }

    function test_restart_saving() public {
        address tokenToSaveWith = address(breadToken);
        uint256 initialAmount = 10 * 10 ** 18;
        string memory reason = "Restart Saving Test";
        uint256 duration = 100;

        vm.startPrank(user3);
        breadToken.approve(address(saving), initialAmount);
        saving.openSavingPool(
            tokenToSaveWith,
            initialAmount,
            reason,
            IChainCoopSaving.LockingType.FLEXIBLE,
            duration
        );

        ChainCoopSaving.SavingPool[] memory poolsBefore = saving
            .getSavingPoolBySaver(user3);
        bytes32 _poolId = poolsBefore[0].poolIndex;

        saving.stopSaving(_poolId);
        saving.restartSaving(_poolId);
        ChainCoopSaving.SavingPool[] memory poolsAfter = saving
            .getSavingPoolBySaver(user3);
        assertEq(poolsAfter[0].isStoped, false);
        breadToken.approve(address(saving), 5 * 10 ** 18);
        saving.updateSaving(poolsAfter[0].poolIndex, 5 * 10 ** 18);
        (, , , , , , uint256 amountSaved, , , ) = saving.poolSavingPool(
            poolsAfter[0].poolIndex
        );
        assertEq(amountSaved, initialAmount + 5 * 10 ** 18);
        vm.stopPrank();
    }
    //create pool and return the poolid
    // function test_create_pool() public returns (bytes32) {
    //     vm.startPrank(user2);
    //     // Create a new pool
    //     breadToken.approve(address(saving), 10);
    //     saving.openSavingPool(
    //         address(breadToken),
    //         10,
    //         1000,
    //         "Buy a laptop",
    //         100
    //     );
    //     ChainCoopSaving.SavingPool[] memory pools = saving.getSavingPoolBySaver(
    //         user2
    //     );
    //     vm.stopPrank();

    //     bytes32 poolId = pools[0].poolIndex;
    //     return poolId;
    // }

    // //test failed to openpool
    // function testfail_to_open_pool() public {
    //     vm.expectRevert("Only allowed tokens");

    //     saving.openSavingPool(user4, 10, 1000, "Buy A new Meme Coin", 100);
    // }

    // //get userPools

    // function test_update_pool_balance() public {
    //     // Open a new saving pool
    //     bytes32 _poolId = test_create_pool();

    //     vm.startPrank(user2);
    //     breadToken.approve(address(saving), 100);
    //     saving.updateSaving(_poolId, 100);
    //     (, , , , , , uint256 amountSaved, ) = saving.poolSavingPool(_poolId);
    //     vm.stopPrank();

    //     assertEq(
    //         amountSaved,
    //         110,
    //         "Balance not incremented correctly after second update"
    //     );
    // }

    // //update pool to completion
    // function test_update_pool_to_completion() public {
    //     // Open a new saving pool
    //     bytes32 _poolId = test_create_pool();
    //     // Update the pool balance to reach the goal amount
    //     vm.startPrank(user2);
    //     breadToken.approve(address(saving), 990);
    //     saving.updateSaving(_poolId, 990);
    //     // Validate the pool status
    //     (, , , , , , uint256 amountSaved, bool isGoalAccomplished) = saving
    //         .poolSavingPool(_poolId);
    //     vm.stopPrank();
    //     assertEq(
    //         amountSaved,
    //         1000,
    //         "Pool balance not updated correctly to reach goal amount"
    //     );
    //     assertEq(isGoalAccomplished, true, "Incomplete Saving round");
    // }

    // //withdraw before completion
    // function test_withdraw_before_completion() public {
    //     // Open a new saving pool
    //     bytes32 _poolId = test_create_pool();
    //     // Update the pool balance to reach the goal amount
    //     vm.startPrank(user2);
    //     breadToken.approve(address(saving), 900);
    //     saving.updateSaving(_poolId, 900);
    //     // Validate the pool status
    //     (, , , , , , uint256 amountSaved, bool isGoalAccomplished) = saving
    //         .poolSavingPool(_poolId);
    //     assertEq(amountSaved, 910, "Wrong Amount Saved");
    //     assertEq(isGoalAccomplished, false, "Failed to Accomplish");
    //     //check balance before withdraw
    //     uint256 bal = breadToken.balanceOf(user2);
    //     assertEq(
    //         bal,
    //         ((1000 * 10 ** 18) - amountSaved),
    //         "Incorect Balance amount since initialdeposit was 10, then 900 for update remaining (1000-(900+10)) =90"
    //     );
    //     //withdraw
    //     saving.withdraw(_poolId);
    //     //balance after withdraw
    //     bal = breadToken.balanceOf(chaincoopFees);
    //     //get 0.03 %
    //     uint256 fee = LibChainCoopSaving.calculateInterest(amountSaved);
    //     assertEq(bal, fee);

    //     vm.stopPrank();
    // }

    // //withdrawing after saving completion
    // function test_withdraw_after_completion() public {
    //     // Open a new saving pool
    //     bytes32 _poolId = test_create_pool();
    //     // Update the pool balance to reach the goal amount
    //     vm.startPrank(user2);
    //     breadToken.approve(address(saving), 990);
    //     saving.updateSaving(_poolId, 990);
    //     // Validate the pool status
    //     (, , , , , , uint256 amountSaved, bool isGoalAccomplished) = saving
    //         .poolSavingPool(_poolId);
    //     assertEq(amountSaved, 1000, "Wrong Amount Saved");
    //     assertEq(isGoalAccomplished, true, "Failed to Accomplish");
    //     //check balance before withdraw
    //     uint256 bal = breadToken.balanceOf(user2);
    //     assertEq(
    //         bal,
    //         ((1000 * 10 ** 18) - amountSaved),
    //         "Incorect Balance amount since initialdeposit was 10, then 900 for update remaining (1000-(900+10)) =90"
    //     );
    //     //withdraw
    //     saving.withdraw(_poolId);
    //     //balance after withdraw
    //     bal = breadToken.balanceOf(chaincoopFees);
    //     //get 0.03 %
    //     uint256 fee = LibChainCoopSaving.calculateInterest(0);
    //     assertEq(bal, fee);

    //     vm.stopPrank();
    // }
}
