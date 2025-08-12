// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IChainCoopSaving} from "./interface/IchainCoopSaving.sol";
import {LibChainCoopSaving} from "./lib/LibChainCoopSaving.sol";
import "./ChainCoopManagement.sol";

import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/metatx/ERC2771ContextUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

// Aave imports
import {IPool} from "@aave/contracts/interfaces/IPool.sol";
import {IRewardsController} from "@aave/contracts/rewards/interfaces/IRewardsController.sol";

error ZeroAmount(uint256 _amount);
error ZeroDuration(uint256 _duration);
error ZeroGoalAmount(uint256 _goalamount);
error NotPoolOwner(address _caller, bytes32 _poolId);
error StrictlySavingType(address _caller, bytes32 _poolId);
error SavingPeriodStillOn(address _caller, bytes32 _poolId, uint256 _endDate);
error PoolStoped(address _caller, bytes32 _poolid);
error AaveNotConfigured();
error InvalidAaveToken();

contract ChainCoopSaving is
    Initializable,
    ReentrancyGuardUpgradeable,
    ERC2771ContextUpgradeable,
    UUPSUpgradeable,
    ChainCoopManagement,
    IChainCoopSaving
{
    using LibChainCoopSaving for address;
    using SafeERC20 for IERC20;

    // Aave Integration Variables
    struct AaveConfig {
        IPool pool;
        IERC20 aToken;
        IRewardsController rewardsController;
        bool isConfigured;
    }

    // Mapping token address to its Aave configuration
    mapping(address => AaveConfig) public aaveConfigs;

    // Track total deposited in Aave per token
    mapping(address => uint256) public totalAaveDeposits;

    // Referral code for Aave
    uint16 private constant REFERRAL_CODE = 0;

    // Mappings
    mapping(bytes32 => SavingPool) public poolSavingPool;
    mapping(address => mapping(bytes32 => uint256)) public userPoolBalance;
    mapping(address => bytes32[]) public userContributedPools;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(
        address trustedForwarder_
    ) ERC2771ContextUpgradeable(trustedForwarder_) {
        _disableInitializers();
    }

    function initialize(address _tokenAddress) public initializer {
        // Initialize parent contracts
        __ReentrancyGuard_init();

        __ChainCoopManagement_init(_tokenAddress);
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override onlyOwner {}

    function _contextSuffixLength()
        internal
        view
        override(ContextUpgradeable, ERC2771ContextUpgradeable)
        returns (uint256)
    {
        return ERC2771ContextUpgradeable._contextSuffixLength();
    }

    function _msgSender()
        internal
        view
        override(ContextUpgradeable, ERC2771ContextUpgradeable)
        returns (address sender)
    {
        return ERC2771ContextUpgradeable._msgSender();
    }

    function _msgData()
        internal
        view
        override(ContextUpgradeable, ERC2771ContextUpgradeable)
        returns (bytes calldata)
    {
        return ERC2771ContextUpgradeable._msgData();
    }

    // Events
    event OpenSavingPool(
        address indexed user,
        address indexed _tokenAddress,
        uint256 initialAmount,
        uint256 startTime,
        LockingType locktype,
        uint256 duration,
        bytes32 _poolId,
        bool aaveEnabled
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
    ) external onlyOwner {
        require(tokenAddress != address(0), "Invalid token address");
        require(aavePool != address(0), "Invalid Aave pool");
        require(aToken != address(0), "Invalid aToken");

        aaveConfigs[tokenAddress] = AaveConfig({
            pool: IPool(aavePool),
            aToken: IERC20(aToken),
            rewardsController: IRewardsController(rewardsController),
            isConfigured: true
        });

        // Approve Aave pool to spend tokens
        IERC20(tokenAddress).safeIncreaseAllowance(aavePool, type(uint256).max);

        emit AaveConfigured(tokenAddress, aavePool, aToken);
    }

    /**
     * @notice Allow Opening a saving pool with initial contribution and optional Aave integration
     */
    function openSavingPool(
        address _tokenTosaveWith,
        uint256 _savedAmount,
        string calldata _reason,
        LockingType _locktype,
        uint256 _duration,
        bool _enableAave
    ) external onlyAllowedTokens(_tokenTosaveWith) {
        address sender = _msgSender();

        if (_savedAmount <= 0) {
            revert ZeroAmount(_savedAmount);
        }

        if (_duration <= 0) {
            revert ZeroDuration(_duration);
        }

        // Check if Aave is available for this token
        if (_enableAave && !aaveConfigs[_tokenTosaveWith].isConfigured) {
            revert AaveNotConfigured();
        }

        bool accomplished;
        if (_locktype == LockingType.FLEXIBLE) {
            accomplished = true;
        }
        uint256 _starttime = block.timestamp;

        bytes32 _poolId = LibChainCoopSaving.generatePoolIndex(
            sender,
            block.timestamp,
            _savedAmount
        );

        // Transfer tokens from user to contract
        IERC20(_tokenTosaveWith).safeTransferFrom(
            sender,
            address(this),
            _savedAmount
        );

        uint256 aaveDepositAmount = 0;

        // Deposit to Aave if enabled
        if (_enableAave) {
            AaveConfig memory config = aaveConfigs[_tokenTosaveWith];

            // Deposit to Aave - aTokens come to this contract
            config.pool.supply(
                _tokenTosaveWith,
                _savedAmount,
                address(this),
                REFERRAL_CODE
            );
            aaveDepositAmount = _savedAmount;
            totalAaveDeposits[_tokenTosaveWith] += _savedAmount;
        }

        SavingPool memory pool = SavingPool({
            saver: sender,
            tokenToSaveWith: _tokenTosaveWith,
            Reason: _reason,
            poolIndex: _poolId,
            startDate: _starttime,
            Duration: _duration,
            amountSaved: _savedAmount,
            aaveDepositAmount: aaveDepositAmount,
            locktype: _locktype,
            isGoalAccomplished: accomplished,
            isStoped: false,
            aaveEnabled: _enableAave
        });

        poolSavingPool[_poolId] = pool;
        userContributedPools[sender].push(_poolId);
        userPoolBalance[sender][_poolId] += _savedAmount;

        emit OpenSavingPool(
            sender,
            _tokenTosaveWith,
            _savedAmount,
            _starttime,
            _locktype,
            _duration,
            _poolId,
            _enableAave
        );
    }

    /**
     * @notice Allow adding funds to an existing saving pool
     */
    function updateSaving(bytes32 _poolId, uint256 _amount) external {
        address sender = _msgSender();

        if (poolSavingPool[_poolId].saver != sender) {
            revert NotPoolOwner(sender, poolSavingPool[_poolId].poolIndex);
        }
        if (poolSavingPool[_poolId].isStoped) {
            revert PoolStoped(sender, _poolId);
        }
        if (poolSavingPool[_poolId].locktype == LockingType.STRICTLOCK) {
            revert StrictlySavingType(sender, _poolId);
        }
        if (_amount <= 0) {
            revert ZeroAmount(_amount);
        }

        SavingPool storage pool = poolSavingPool[_poolId];

        // Transfer tokens from user
        IERC20(pool.tokenToSaveWith).safeTransferFrom(
            sender,
            address(this),
            _amount
        );

        // If Aave is enabled for this pool, deposit additional amount
        if (pool.aaveEnabled) {
            AaveConfig memory config = aaveConfigs[pool.tokenToSaveWith];
            config.pool.supply(
                pool.tokenToSaveWith,
                _amount,
                address(this),
                REFERRAL_CODE
            );
            pool.aaveDepositAmount += _amount;
            totalAaveDeposits[pool.tokenToSaveWith] += _amount;
        }

        pool.amountSaved += _amount;
        userPoolBalance[sender][_poolId] += _amount;

        if (pool.locktype == LockingType.LOCK) {
            if (pool.Duration <= block.timestamp) {
                pool.isGoalAccomplished = true;
            }
        }

        emit UpdateSaving(
            sender,
            pool.tokenToSaveWith,
            _amount,
            pool.poolIndex
        );
    }

    /**
     * @notice Stop Saving
     */
    function stopSaving(bytes32 _poolId) external {
        address sender = _msgSender();

        if (poolSavingPool[_poolId].saver != sender) {
            revert NotPoolOwner(sender, poolSavingPool[_poolId].poolIndex);
        }
        poolSavingPool[_poolId].isStoped = true;
        emit StopSaving(sender, _poolId);
    }

    /**
     * @notice Restart Saving
     */
    function restartSaving(bytes32 _poolId) external {
        address sender = _msgSender();

        if (poolSavingPool[_poolId].saver != sender) {
            revert NotPoolOwner(sender, poolSavingPool[_poolId].poolIndex);
        }
        poolSavingPool[_poolId].isStoped = false;
        emit RestartSaving(sender, _poolId);
    }

    /**
     * @notice Enhanced withdraw function with Aave integration
     */
    function withdraw(bytes32 _poolId) external nonReentrant {
        address sender = _msgSender();
        SavingPool storage pool = poolSavingPool[_poolId];

        if (pool.saver != sender) {
            revert NotPoolOwner(sender, pool.poolIndex);
        }

        uint256 totalAmountToUser = 0;
        uint256 aaveYield = 0;

        if (pool.locktype == LockingType.STRICTLOCK) {
            if (pool.Duration > block.timestamp) {
                revert SavingPeriodStillOn(sender, _poolId, pool.Duration);
            }
        }

        // Handle Aave withdrawal if enabled
        if (pool.aaveEnabled && pool.aaveDepositAmount > 0) {
            AaveConfig memory config = aaveConfigs[pool.tokenToSaveWith];

            // Get current aToken balance for this pool's share
            uint256 currentATokenBalance = _getPoolAaveBalance(
                _poolId,
                config.aToken
            );

            // Withdraw from Aave
            uint256 withdrawnFromAave = config.pool.withdraw(
                pool.tokenToSaveWith,
                currentATokenBalance,
                address(this)
            );

            aaveYield = withdrawnFromAave > pool.aaveDepositAmount
                ? withdrawnFromAave - pool.aaveDepositAmount
                : 0;

            totalAmountToUser = withdrawnFromAave;
            totalAaveDeposits[pool.tokenToSaveWith] -= pool.aaveDepositAmount;
        } else {
            totalAmountToUser = pool.amountSaved;
        }

        // Apply penalty if early withdrawal and not accomplished
        if (
            !pool.isGoalAccomplished && pool.locktype != LockingType.STRICTLOCK
        ) {
            uint256 interest = LibChainCoopSaving.calculateInterest(
                totalAmountToUser
            );
            uint256 amountReturnToUser = totalAmountToUser - interest;

            IERC20(pool.tokenToSaveWith).safeTransfer(
                pool.saver,
                amountReturnToUser
            );
            IERC20(pool.tokenToSaveWith).safeTransfer(chainCoopFees, interest);

            totalAmountToUser = amountReturnToUser;
        } else {
            IERC20(pool.tokenToSaveWith).safeTransfer(
                pool.saver,
                totalAmountToUser
            );
        }

        emit Withdraw(
            sender,
            pool.tokenToSaveWith,
            totalAmountToUser,
            pool.poolIndex,
            aaveYield
        );

        // Cleanup
        delete poolSavingPool[_poolId];
        delete userPoolBalance[sender][_poolId];

        bytes32[] storage userPools = userContributedPools[sender];
        for (uint256 i = 0; i < userPools.length; i++) {
            if (userPools[i] == _poolId) {
                userPools[i] = userPools[userPools.length - 1];
                userPools.pop();
                break;
            }
        }
        emit PoolClosed(sender, _poolId);
    }

    /**
     * @notice Claim Aave rewards for a specific pool
     */
    function claimAaveRewards(bytes32 _poolId) external {
        address sender = _msgSender();
        SavingPool storage pool = poolSavingPool[_poolId];

        if (pool.saver != sender) {
            revert NotPoolOwner(sender, pool.poolIndex);
        }

        if (!pool.aaveEnabled) {
            revert AaveNotConfigured();
        }

        AaveConfig memory config = aaveConfigs[pool.tokenToSaveWith];
        address[] memory assets = new address[](1);
        assets[0] = address(config.aToken);

        (address[] memory rewardsList, uint256[] memory claimedAmounts) = config
            .rewardsController
            .claimAllRewards(assets, sender);

        emit AaveRewardsClaimed(sender, rewardsList, claimedAmounts);
    }

    /**
     * @notice Get current Aave balance for a pool (including yield)
     */
    function getPoolAaveBalance(
        bytes32 _poolId
    ) external view returns (uint256) {
        SavingPool memory pool = poolSavingPool[_poolId];
        if (!pool.aaveEnabled) return 0;

        AaveConfig memory config = aaveConfigs[pool.tokenToSaveWith];
        return _getPoolAaveBalance(_poolId, config.aToken);
    }

    /**
     * @notice Internal function to calculate pool's share of aTokens
     */
    function _getPoolAaveBalance(
        bytes32 _poolId,
        IERC20 aToken
    ) internal view returns (uint256) {
        SavingPool memory pool = poolSavingPool[_poolId];
        if (!pool.aaveEnabled || pool.aaveDepositAmount == 0) return 0;

        // Get total aToken balance of this contract
        uint256 totalATokenBalance = aToken.balanceOf(address(this));
        uint256 totalDeposits = totalAaveDeposits[pool.tokenToSaveWith];

        if (totalDeposits == 0) return 0;

        // Calculate this pool's proportional share
        return (totalATokenBalance * pool.aaveDepositAmount) / totalDeposits;
    }

    function getSavingPoolByIndex(
        bytes32 _index
    ) external view returns (SavingPool memory) {
        return poolSavingPool[_index];
    }

    function getSavingPoolBySaver(
        address _saver
    ) external view returns (SavingPool[] memory pools) {
        uint256 userPoolCount = userContributedPools[_saver].length;
        pools = new SavingPool[](userPoolCount);

        for (uint256 i = 0; i < userPoolCount; i++) {
            bytes32 poolId = userContributedPools[_saver][i];
            pools[i] = poolSavingPool[poolId];
        }
    }

    function getUserContributions(
        address _saver
    ) external view returns (Contribution[] memory contributions) {
        uint256 userPoolCount = userContributedPools[_saver].length;
        contributions = new Contribution[](userPoolCount);

        for (uint256 i = 0; i < userPoolCount; i++) {
            bytes32 poolId = userContributedPools[_saver][i];
            SavingPool storage pool = poolSavingPool[poolId];

            uint256 aaveBalance = 0;
            if (pool.aaveEnabled) {
                AaveConfig memory config = aaveConfigs[pool.tokenToSaveWith];
                aaveBalance = _getPoolAaveBalance(poolId, config.aToken);
            }

            contributions[i] = Contribution({
                tokenAddress: pool.tokenToSaveWith,
                amount: pool.amountSaved,
                aaveBalance: aaveBalance
            });
        }
    }

    /**
     * @notice Check if Aave is configured for a token
     */
    function isAaveConfigured(address token) external view returns (bool) {
        return aaveConfigs[token].isConfigured;
    }

    /**
     * @notice Get total yield earned from Aave for a pool
     */
    function getPoolYield(bytes32 _poolId) external view returns (uint256) {
        SavingPool memory pool = poolSavingPool[_poolId];
        if (!pool.aaveEnabled) return 0;

        uint256 currentBalance = this.getPoolAaveBalance(_poolId);
        return
            currentBalance > pool.aaveDepositAmount
                ? currentBalance - pool.aaveDepositAmount
                : 0;
    }

    // ============ Meta-transaction Support ============

    function supportsMetaTransactions() external pure returns (bool) {
        return true;
    }

    function getTrustedForwarder() external view returns (address) {
        return trustedForwarder();
    }

    uint256[45] private __gap;
}