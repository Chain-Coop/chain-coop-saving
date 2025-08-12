// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

interface IChainCoopSaving {
    //enum with locking
    enum LockingType {
        FLEXIBLE,
        LOCK,
        STRICTLOCK
    }

    // Enhanced struct to include Aave integration
    struct SavingPool {
        address saver;
        address tokenToSaveWith;
        string Reason;
        bytes32 poolIndex;
        uint256 startDate;
        uint256 Duration;
        uint256 amountSaved; // Original amount saved
        uint256 aaveDepositAmount; // Amount deposited to Aave
        LockingType locktype;
        bool isGoalAccomplished;
        bool isStoped;
        bool aaveEnabled; // Whether this pool uses Aave
    }

    // Enhanced contribution struct
    struct Contribution {
        address tokenAddress;
        uint256 amount;
        uint256 aaveBalance; // Current aToken balance
    }

    

    // ============ Core Functions ============

    /**
     * @notice Allow Opening a saving pool with initial contribution and optional Aave integration
     * @param _tokenTosaveWith Token to save with
     * @param _savedAmount Initial amount to save
     * @param _reason Reason for saving
     * @param _locktype Type of locking mechanism
     * @param _duration Duration of the saving period
     * @param _enableAave Whether to enable Aave yield generation
     */
    function openSavingPool(
        address _tokenTosaveWith,
        uint256 _savedAmount,
        string calldata _reason,
        LockingType _locktype,
        uint256 _duration,
        bool _enableAave
    ) external;

    /**
     * @notice Allow adding funds to an existing saving pool
     * @param _poolIndex Pool identifier
     * @param _amount Amount to add
     */
    function updateSaving(bytes32 _poolIndex, uint256 _amount) external;

    /**
     * @notice Allow withdrawing funds from an existing saving pool
     * @param _poolId Pool identifier
     */
    function withdraw(bytes32 _poolId) external;

    /**
     * @notice Stop Saving
     * @param _poolId Pool identifier
     */
    function stopSaving(bytes32 _poolId) external;

    /**
     * @notice Restart Saving
     * @param _poolId Pool identifier
     */
    function restartSaving(bytes32 _poolId) external;

    // ============ Aave Integration Functions ============

    /**
     * @notice Configure Aave integration for a specific token
     * @param tokenAddress The token to configure
     * @param aavePool The Aave pool contract
     * @param aToken The corresponding aToken
     * @param rewardsController The Aave rewards controller
     */
    function configureAave(
        address tokenAddress,
        address aavePool,
        address aToken,
        address rewardsController
    ) external;

    /**
     * @notice Claim Aave rewards for a specific pool
     * @param _poolId Pool identifier
     */
    function claimAaveRewards(bytes32 _poolId) external;

    /**
     * @notice Get current Aave balance for a pool (including yield)
     * @param _poolId Pool identifier
     * @return Current aToken balance for the pool
     */
    function getPoolAaveBalance(bytes32 _poolId) external view returns (uint256);

    /**
     * @notice Get total yield earned from Aave for a pool
     * @param _poolId Pool identifier
     * @return Yield earned from Aave
     */
    function getPoolYield(bytes32 _poolId) external view returns (uint256);

    /**
     * @notice Check if Aave is configured for a token
     * @param token Token address to check
     * @return True if Aave is configured for the token
     */
    function isAaveConfigured(address token) external view returns (bool);

    // ============ View Functions ============

    /**
     * @notice get enhanced pool by index
     * @param _index Index of the pool to get
     * @return Enhanced pool information
     */
    function getSavingPoolByIndex(
        bytes32 _index
    ) external view returns (SavingPool memory);

    /**
     * @notice get enhanced pools by the creator address
     * @param _saver Address of the saver
     * @return Array of enhanced pool information
     */
    function getSavingPoolBySaver(
        address _saver
    ) external view returns (SavingPool[] memory);

    /**
     * @notice Get user contributions with Aave balances
     * @param _saver Address of the saver
     * @return Array of user contributions including Aave balances
     */
    function getUserContributions(
        address _saver
    ) external view returns (Contribution[] memory);

    // ============ Meta-transaction Support ============

    /**
     * @notice Check if the contract supports meta-transactions
     * @return bool true if meta-transactions are supported
     */
    function supportsMetaTransactions() external pure returns (bool);

    /**
     * @notice Get the trusted forwarder address
     * @return address The trusted forwarder address
     */
    function getTrustedForwarder() external view returns (address);
}