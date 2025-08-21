// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// Aave imports for interface consistency
import {IPool} from "@aave/contracts/interfaces/IPool.sol";
import {IRewardsController} from "@aave/contracts/rewards/interfaces/IRewardsController.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";

interface IChainCoopSaving {
    enum LockingType {
        FLEXIBLE,
        LOCK,
        STRICTLOCK
    }

    struct SavingPool {
        address saver;
        address tokenToSaveWith;
        string Reason;
        bytes32 poolIndex;
        uint256 startDate;
        uint256 Duration;
        uint256 amountSaved;
        uint256 aaveDepositAmount;
        LockingType locktype;
        bool isGoalAccomplished;
        bool isStoped;
        bool aaveEnabled;
    }

    struct Contribution {
        address tokenAddress;
        uint256 amount;
        uint256 aaveBalance;
    }

    struct AaveConfig {
        IPool pool;
        IERC20 aToken;
        IRewardsController rewardsController;
        bool isConfigured;
    }

    // Events
    event OpenSavingPool(
        address indexed user,
        address indexed _tokenAddress,
        uint256 initialAmount,
        uint256 startTime,
        LockingType locktype,
        uint256 duration,
        bytes32 _poolId
    );

    event Withdraw(
        address indexed user,
        address indexed _tokenAddress,
        uint256 amount,
        bytes32 _poolId,
        uint256 aaveYield
    );

    event UpdateSaving(
        address indexed user,
        address indexed _tokenAddress,
        uint256 amount,
        bytes32 _poolId
    );

    event RestartSaving(address _poolOwner, bytes32 _poolId);

    event StopSaving(address _poolOwner, bytes32 _poolId);

    event PoolClosed(address indexed user, bytes32 indexed poolId);

    event AaveConfigured(address indexed token, address pool, address aToken);
    
    event AaveRewardsClaimed(
        address indexed user,
        address[] rewards,
        uint256[] amounts
    );
    
    event AaveDepositEnabled(
        address indexed user,
        bytes32 indexed poolId,
        uint256 amount
    );

    // ============ Core Saving Pool Functions ============

    /**
     * @notice Open a new saving pool
     * @param _tokenTosaveWith Token address to save with
     * @param _savedAmount Initial amount to save
     * @param _reason Reason for saving
     * @param _locktype Type of locking mechanism
     * @param _duration Duration of the saving period
     */
    function openSavingPool(
        address _tokenTosaveWith,
        uint256 _savedAmount,
        string calldata _reason,
        LockingType _locktype,
        uint256 _duration
    ) external;

    /**
     * @notice Add more funds to an existing saving pool
     * @param _poolId Pool identifier
     * @param _amount Amount to add
     */
    function updateSaving(bytes32 _poolId, uint256 _amount) external;

    /**
     * @notice Withdraw funds from a saving pool
     * @param _poolId Pool identifier
     */
    function withdraw(bytes32 _poolId) external;

    /**
     * @notice Stop saving in a pool
     * @param _poolId Pool identifier
     */
    function stopSaving(bytes32 _poolId) external;

    /**
     * @notice Restart saving in a stopped pool
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
     * @notice Enable Aave integration for an existing pool
     * @param _poolId Pool identifier
     */
    function enableAaveForPool(bytes32 _poolId) external;

    /**
     * @notice Claim Aave rewards for a specific pool
     * @param _poolId Pool identifier
     */
    function claimAaveRewards(bytes32 _poolId) external;

    // ============ View Functions ============

    /**
     * @notice Get saving pool details by index
     * @param _index Pool identifier
     * @return SavingPool struct
     */
    function getSavingPoolByIndex(
        bytes32 _index
    ) external view returns (SavingPool memory);

    /**
     * @notice Get all saving pools for a specific saver
     * @param _saver Address of the saver
     * @return pools Array of SavingPool structs
     */
    function getSavingPoolBySaver(
        address _saver
    ) external view returns (SavingPool[] memory pools);

    /**
     * @notice Get user contributions summary
     * @param _saver Address of the saver
     * @return contributions Array of Contribution structs
     */
    function getUserContributions(
        address _saver
    ) external view returns (Contribution[] memory contributions);

    /**
     * @notice Get current Aave balance for a pool (including yield)
     * @param _poolId Pool identifier
     * @return Current Aave balance
     */
    function getPoolAaveBalance(
        bytes32 _poolId
    ) external view returns (uint256);

    /**
     * @notice Get total yield earned from Aave for a pool
     * @param _poolId Pool identifier
     * @return Yield amount
     */
    function getPoolYield(bytes32 _poolId) external view returns (uint256);

    /**
     * @notice Check if Aave is configured for a token
     * @param token Token address
     * @return True if configured
     */
    function isAaveConfigured(address token) external view returns (bool);

    /**
     * @notice Get user pool balance
     * @param user User address
     * @param poolId Pool identifier
     * @return Balance amount
     */
    function userPoolBalance(
        address user,
        bytes32 poolId
    ) external view returns (uint256);

    /**
     * @notice Get user contributed pools by index
     * @param user User address
     * @param index Array index
     * @return Pool ID at the specified index
     */
    function userContributedPools(
        address user,
        uint256 index
    ) external view returns (bytes32);

    /**
     * @notice Get Aave configuration for a token
     * @param token Token address
     * @return pool The Aave pool interface
     * @return aToken The aToken interface
     * @return rewardsController The rewards controller interface
     * @return isConfigured Whether Aave is configured for this token
     */
    function aaveConfigs(address token) external view returns (
        IPool pool,
        IERC20 aToken,
        IRewardsController rewardsController,
        bool isConfigured
    );

    /**
     * @notice Get total Aave deposits for a token
     * @param token Token address
     * @return Total deposit amount
     */
    function totalAaveDeposits(address token) external view returns (uint256);

    /**
     * @notice Get saving pool by pool ID
     * @param poolId Pool identifier
     * @return saver The address of the saver
     * @return tokenToSaveWith The token address used for saving
     * @return Reason The reason for saving
     * @return poolIndex The pool identifier
     * @return startDate The start timestamp
     * @return Duration The duration of the saving period
     * @return amountSaved The total amount saved
     * @return aaveDepositAmount The amount deposited in Aave
     * @return locktype The locking type
     * @return isGoalAccomplished Whether the goal is accomplished
     * @return isStoped Whether the pool is stopped
     * @return aaveEnabled Whether Aave is enabled for this pool
     */
    function poolSavingPool(bytes32 poolId) external view returns (
        address saver,
        address tokenToSaveWith,
        string memory Reason,
        bytes32 poolIndex,
        uint256 startDate,
        uint256 Duration,
        uint256 amountSaved,
        uint256 aaveDepositAmount,
        LockingType locktype,
        bool isGoalAccomplished,
        bool isStoped,
        bool aaveEnabled
    );

    // ============ Meta-transaction Support ============

    /**
     * @notice Check if contract supports meta transactions
     * @return True if supported
     */
    function supportsMetaTransactions() external pure returns (bool);

    /**
     * @notice Get trusted forwarder address
     * @return Forwarder address
     */
    function getTrustedForwarder() external view returns (address);
}