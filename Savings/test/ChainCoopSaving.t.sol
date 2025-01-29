// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

import {ChainCoopSaving} from "../src/ChainCoopSaving.sol";
import {IChainCoopSaving} from "../src/interface/IchainCoopSaving.sol";
import {YieldErc20_BreadToken} from "../src/mock/YieldErc20_BreadToken.sol";
import {LibChainCoopSaving} from "../src/lib/LibChainCoopSaving.sol";

contract SavingTest is Test {
    using LibChainCoopSaving for address;
    ChainCoopSaving public saving;
    YieldErc20_BreadToken public breadToken;
    IChainCoopSaving public ichain;
    address public owner;
    address user1;
    address user2;
    address user3;
    address user4;
    address chaincoopFees;
    error SavingPeriodStillOn(
        address _caller,
        bytes32 _poolId,
        uint256 _endDate
    );
    error PoolDurationExpired(bytes32 _poolId);

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
        vm.prank(user2);
        assertEq(breadToken.balanceOf(user2), 1000 * 10 ** 18);
    }
    //mint token

    //management
    function test_set_allow_token() public view {
        // Set the token to be allowed

        assertEq(saving.isTokenAllowed(address(breadToken)), true);
    }

    //SavingTest
    //address _tokenTosaveWith,uint256 _savedAmount,uint256 _goalAmount,string calldata _reason,uint256 _duration
    function test_openSavingPool() public {
        // Open a new saving pool
        vm.startPrank(user3);

        breadToken.approve(address(saving), 10);
        saving.openSavingPool(
            address(breadToken),
            10,
            "Buy A new Meme Coin",
            IChainCoopSaving.LockingType.FLEXIBLE,
            10 days
        );
        vm.stopPrank();

        // Check that the pool has been created
        assertEq(saving.poolCount(), 1);
    }
    //create pool and return the poolid
    function test_create_pool() public returns (bytes32) {
        vm.startPrank(user2);
        // Create a new pool
        breadToken.approve(address(saving), 10);
        saving.openSavingPool(
            address(breadToken),
            10,
            "Buy a laptop",
            IChainCoopSaving.LockingType.FLEXIBLE,
            10 days
        );
        ChainCoopSaving.SavingPool[] memory pools = saving.getSavingPoolBySaver(
            user2
        );
        vm.stopPrank();

        return pools[0].poolIndex;
    }

    //test failed to openpool
    function testfail_to_open_pool() public {
        vm.expectRevert("Only allowed tokens");

        saving.openSavingPool(
            user4,
            10,
            "Buy A new Meme Coin",
            IChainCoopSaving.LockingType.FLEXIBLE,
            10 days
        );
    }
    //get userPools
    function test_get_user_pools() public {
        // Open a new saving pool
        vm.startPrank(user2);
        breadToken.approve(address(saving), 10);
        saving.openSavingPool(
            address(breadToken),
            10,
            "Buy a laptop",
            IChainCoopSaving.LockingType.FLEXIBLE,
            100
        );
        ChainCoopSaving.SavingPool[] memory pools = saving.getSavingPoolBySaver(
            user2
        );
        vm.stopPrank();
        assertEq(pools.length, 1, "User should have one saving pool");

        // Validate the details of the created saving pool
        assertEq(pools[0].saver, user2, "Saver address mismatch");
        assertEq(
            pools[0].tokenToSaveWith,
            address(breadToken),
            "Token address mismatch"
        );
        assertEq(pools[0].amountSaved, 10, "Minimum deposit mismatch");
        // assertEq(pools[0].goalAmount, 1000, "Target amount mismatch");
        assertEq(pools[0].Reason, "Buy a laptop", "Description mismatch");
        assertEq(pools[0].Duration, 100, "Duration mismatch");
    }

    function test_update_pool_balance() public {
        // Open a new saving pool
        bytes32 _poolId = test_create_pool();
        // console.log("Pool ID", _poolId);

        vm.startPrank(user2);
        breadToken.approve(address(saving), 100);
        saving.updateSaving(_poolId, 100);
        vm.stopPrank();

        // Retrieve the updated pool details using getSavingPoolBySaver
        ChainCoopSaving.SavingPool[] memory pools = saving.getSavingPoolBySaver(
            user2
        );

        assertEq(
            pools[0].amountSaved,
            110,
            "Balance not incremented correctly after second update"
        );
    }

    //update pool to completion
    function test_update_pool_to_completion() public {
        // Open a new saving pool
        bytes32 _poolId = test_create_pool();
        // Update the pool balance to reach the goal amount
        vm.startPrank(user2);
        breadToken.approve(address(saving), 990);
        saving.updateSaving(_poolId, 990);
        vm.stopPrank();

        ChainCoopSaving.SavingPool[] memory pools = saving.getSavingPoolBySaver(
            user2
        );
        assertEq(
            pools[0].amountSaved,
            1000,
            "Pool balance not updated correctly to reach goal amount"
        );
        assertEq(pools[0].isGoalAccomplished, true, "Incomplete Saving round");
    }

    function test_withdraw_strict_lock_saving() public {
        vm.startPrank(user2);
        breadToken.approve(address(saving), 100);

        // Create a strict lock saving pool with 10 days duration
        saving.openSavingPool(
            address(breadToken),
            100,
            "StrictLock Savings",
            IChainCoopSaving.LockingType.STRICTLOCK,
            10 days
        );

        ChainCoopSaving.SavingPool[] memory pools = saving.getSavingPoolBySaver(
            user2
        );
        bytes32 poolId = pools[0].poolIndex;

        // Try to withdraw before duration (should fail)
        vm.expectRevert(
            abi.encodeWithSelector(
                SavingPeriodStillOn.selector,
                user2,
                poolId,
                pools[0].Duration
            )
        );
        saving.withdraw(poolId);

        // Fast forward time to after duration
        vm.warp(block.timestamp + 11 days);
        uint256 initialUserBalance = breadToken.balanceOf(user2);

        // Withdraw after duration (should succeed)
        saving.withdraw(poolId);

        // Verify the withdrawal
        pools = saving.getSavingPoolBySaver(user2);

        // Check that amount saved is now 0
        assertEq(
            pools[0].amountSaved,
            0,
            "Amount saved should be 0 after withdrawal"
        );

        // Check that user received full amount (no penalty for STRICTLOCK)
        assertEq(
            breadToken.balanceOf(user2),
            initialUserBalance + 100,
            "User should receive full amount"
        );

        // Check that the goal is marked as accomplished
        assertTrue(
            pools[0].isGoalAccomplished,
            "Goal should be marked as accomplished"
        );

        vm.stopPrank();
    }

    //withdraw before completion
    function test_withdraw_before_completion() public {
        // Open a new saving pool with initial 10 tokens
        bytes32 _poolId = test_create_pool();

        // Update the pool balance with 900 more tokens
        vm.startPrank(user2);
        breadToken.approve(address(saving), 900);
        saving.updateSaving(_poolId, 900);

        // Get pool status after update
        ChainCoopSaving.SavingPool[] memory pools = saving.getSavingPoolBySaver(
            user2
        );

        // Verify total amount saved (10 + 900)
        assertEq(pools[0].amountSaved, 910, "Wrong Amount Saved");

        // For FLEXIBLE type, isGoalAccomplished should be true by default
        assertEq(
            pools[0].isGoalAccomplished,
            true,
            "Should be accomplished for FLEXIBLE type"
        );

        // Check user balance before withdraw (should be original 1000 - amount saved)
        uint256 initialBalance = breadToken.balanceOf(user2);

        // Calculate expected balance: 1000 * 10^18 - 910
        uint256 expectedBalance = (1000 * 10 ** 18) - 910;
        assertEq(
            initialBalance,
            expectedBalance,
            "Incorrect balance before withdrawal"
        );

        // Store contract's balance before withdrawal
        uint256 contractBalanceBefore = breadToken.balanceOf(address(saving));

        // Withdraw
        saving.withdraw(_poolId);

        // Check balances after withdrawal
        uint256 userBalanceAfter = breadToken.balanceOf(user2);
        uint256 contractBalanceAfter = breadToken.balanceOf(address(saving));

        // For FLEXIBLE type, no penalty fee should be taken
        assertEq(
            userBalanceAfter,
            initialBalance + 910,
            "User should receive full amount"
        );
        assertEq(
            contractBalanceAfter,
            contractBalanceBefore - 910,
            "Contract balance should decrease by full amount"
        );

        // Verify pool amount is zeroed
        pools = saving.getSavingPoolBySaver(user2);
        assertEq(
            pools[0].amountSaved,
            0,
            "Pool amount should be zero after withdrawal"
        );

        vm.stopPrank();
    }

    function test_lock_pool_completion_after_duration() public {
        // Open a LOCK type pool with 10 tokens
        vm.startPrank(user2);
        breadToken.approve(address(saving), 10);

        uint256 startTime = block.timestamp;
        uint256 duration = 100 days;

        saving.openSavingPool(
            address(breadToken),
            10,
            "Buy a laptop",
            IChainCoopSaving.LockingType.LOCK,
            duration
        );

        bytes32 poolId = saving.getSavingPoolBySaver(user2)[0].poolIndex;

        // Verify initial state
        ChainCoopSaving.SavingPool[] memory poolsBefore = saving
            .getSavingPoolBySaver(user2);
        assertEq(
            poolsBefore[0].isGoalAccomplished,
            false,
            "Should not be accomplished initially"
        );
        assertEq(
            poolsBefore[0].startDate,
            startTime,
            "Start time should match"
        );
        assertEq(poolsBefore[0].Duration, duration, "Duration should match");

        // Store initial balances
        uint256 userBalanceBefore = breadToken.balanceOf(user2);
        uint256 contractBalanceBefore = breadToken.balanceOf(address(saving));

        // Fast-forward time to just after the duration
        vm.warp(startTime + duration + 1);

        // Update the saving to trigger duration check
        // This step is needed because the contract checks duration in updateSaving
        breadToken.approve(address(saving), 5);
        vm.expectRevert(
            abi.encodeWithSelector(PoolDurationExpired.selector, poolId)
        );
        saving.updateSaving(poolId, 5);

        // Withdraw
        saving.withdraw(poolId);

        // Check balances after withdrawal
        uint256 userBalanceAfter = breadToken.balanceOf(user2);
        uint256 contractBalanceAfter = breadToken.balanceOf(address(saving));

        // Get final state
        ChainCoopSaving.SavingPool[] memory poolsAfter = saving
            .getSavingPoolBySaver(user2);

        // Verify final state
        assertTrue(
            poolsAfter[0].isGoalAccomplished,
            "Pool should be completed after duration"
        );
        assertEq(
            poolsAfter[0].amountSaved,
            0,
            "Amount saved should be zero after withdrawal"
        );

        // For LOCK type after duration, user should receive full amount (no penalty)
        assertEq(
            userBalanceAfter,
            userBalanceBefore + 10,
            "User should receive full amount"
        );
        assertEq(
            contractBalanceAfter,
            contractBalanceBefore - 10,
            "Contract balance should decrease by full amount"
        );

        vm.stopPrank();
    }

    // withdrawing after saving completion
    function test_withdraw_after_completion() public {
        // Open a new saving pool
        bytes32 _poolId = test_create_pool();

        // Update the pool balance
        vm.startPrank(user2);
        breadToken.approve(address(saving), 990);
        saving.updateSaving(_poolId, 990);

        // Get pool status after update
        ChainCoopSaving.SavingPool[] memory pools = saving.getSavingPoolBySaver(
            user2
        );

        // Validate the total amount saved (initial 10 + 990)
        assertEq(pools[0].amountSaved, 1000, "Wrong Amount Saved");
        assertEq(pools[0].isGoalAccomplished, true, "Failed to Accomplish");

        // Check user balance before withdrawal
        uint256 balanceBeforeWithdraw = breadToken.balanceOf(user2);
        uint256 expectedBalance = (1000 * 10 ** 18) - 1000; // Total minted - total saved
        assertEq(
            balanceBeforeWithdraw,
            expectedBalance,
            "Incorrect balance before withdrawal"
        );

        // Store initial chaincoopFees balance
        uint256 initialFeesBalance = breadToken.balanceOf(chaincoopFees);

        // Perform withdrawal
        saving.withdraw(_poolId);

        // Check balances after withdrawal
        uint256 balanceAfterWithdraw = breadToken.balanceOf(user2);
        uint256 feesBalanceAfterWithdraw = breadToken.balanceOf(chaincoopFees);

        // Since isGoalAccomplished is true, user should receive full amount with no fees
        assertEq(
            balanceAfterWithdraw,
            balanceBeforeWithdraw + 1000,
            "User should receive full amount when goal is accomplished"
        );

        // No fees should be taken when goal is accomplished
        assertEq(
            feesBalanceAfterWithdraw,
            initialFeesBalance,
            "No fees should be taken when goal is accomplished"
        );

        // Verify pool is emptied
        pools = saving.getSavingPoolBySaver(user2);
        assertEq(
            pools[0].amountSaved,
            0,
            "Pool should be empty after withdrawal"
        );

        vm.stopPrank();
    }
}
