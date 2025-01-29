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

    // function test_lock_pool_completion_after_duration() public {
    //     // Open a LOCK type pool
    //     vm.startPrank(user2);
    //     breadToken.approve(address(saving), 10);
    //     saving.openSavingPool(
    //         address(breadToken),
    //         10,
    //         "Buy a laptop",
    //         IChainCoopSaving.LockingType.LOCK,
    //         100 days
    //     );
    //     bytes32 poolId = saving.getSavingPoolBySaver(user2)[0].poolIndex;

    //     // Fast-forward time to after the duration
    //     vm.warp(block.timestamp + 100 days + 1);
    //     saving.withdraw(poolId);

    //     (, , , , , , , bool isGoalAccomplished) = saving.poolSavingPool(poolId);
    //     assertTrue(
    //         isGoalAccomplished,
    //         "Pool should be completed after duration"
    //     );
    //     vm.stopPrank();
    // }

    // // withdrawing after saving completion
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
