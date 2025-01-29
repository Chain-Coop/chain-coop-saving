// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;
import {IChainCoopSaving} from "./interface/IchainCoopSaving.sol";
import {LibChainCoopSaving} from "./lib/LibChainCoopSaving.sol";
import "./ChainCoopManagement.sol";

import "@openzeppelin/contracts/interfaces/IERC20.sol";

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

error ZeroAmount(uint256 _amount);

error ZeroDuration(uint256 _duration);
error ZeroGoalAmount(uint256 _goalamount);
error NotPoolOwner(address _caller, bytes32 _poolId);
error StrictlySavingType(address _caller, bytes32 _poolId);
error SavingPeriodStillOn(address _caller, bytes32 _poolId, uint256 _endDate);
error PoolStoped(address _caller, bytes32 _poolid);
error NonExistentPool(bytes32 _poolId);
error PoolDurationExpired(bytes32 _poolId);
error TransferFailed(address token, address from, uint256 amount);

contract ChainCoopSaving is
    IChainCoopSaving,
    ChainCoopManagement,
    ReentrancyGuard
{
    using LibChainCoopSaving for address;

    //constructor => incase of upgradability will update it
    constructor(address _tokenAddress) ChainCoopManagement(_tokenAddress) {}

    //      function initialize(address _allowedToken) public initializer {
    //     __ChainCoopManagement_init(_allowedToken); // Initialize the inherited contract

    // }

    //events

    event OpenSavingPool(
        address indexed user,
        address indexed _tokenAddress,
        uint256 _index,
        uint256 initialAmount,
        uint256 startTime,
        LockingType,
        uint256 duration,
        bytes32 _poolId
    );
    event Withdraw(
        address indexed user,
        address indexed _tokenAddress,
        uint256 amount,
        bytes32 _poolId
    );
    event UpdateSaving(
        address indexed user,
        address indexed _tokenAddress,
        uint256 amount,
        bytes32 _poolId,
        uint256 newTotal
    );
    event RestartSaving(address _poolOwner, bytes32 _poolId);
    event StopSaving(address _poolOwner, bytes32 _poolId);

    struct Contribution {
        address tokenAddress;
        uint256 amount;
    }
    //Mapping
    mapping(uint256 _poolIndex => SavingPool) public userSavingPool;
    mapping(bytes32 => SavingPool) public poolSavingPool;
    mapping(address => mapping(bytes32 => uint256)) public userPoolBalance;
    mapping(address => bytes32[]) public userContributedPools;

    //Pool Count
    uint256 public poolCount = 0;

    /***
     * @notice Allow Opening a saving pool with initial contribution
     *
     */
    function openSavingPool(
        address _tokenTosaveWith,
        uint256 _savedAmount,
        string calldata _reason,
        LockingType _locktype,
        uint256 _duration
    ) external onlyAllowedTokens(_tokenTosaveWith) {
        if (_savedAmount <= 0) {
            revert ZeroAmount(_savedAmount);
        }

        if (_duration <= 0) {
            revert ZeroDuration(_duration);
        }
        uint256 _index = poolCount;
        //check lock type
        bool accomplished;
        if (_locktype == LockingType.FLEXIBLE) {
            accomplished = true;
        }
        uint256 _starttime = block.timestamp;

        bytes32 _poolId = LibChainCoopSaving.generatePoolIndex(
            msg.sender,
            block.timestamp,
            _savedAmount
        );
        require(
            IERC20(_tokenTosaveWith).transferFrom(
                msg.sender,
                address(this),
                _savedAmount
            ),
            "failed to deposit"
        );

        SavingPool memory pool = SavingPool({
            saver: msg.sender,
            tokenToSaveWith: _tokenTosaveWith,
            Reason: _reason,
            poolIndex: _poolId,
            startDate: _starttime,
            Duration: _duration,
            amountSaved: _savedAmount,
            locktype: _locktype,
            isGoalAccomplished: accomplished,
            isStoped: false
        });
        poolCount++;
        userSavingPool[_index] = pool;
        poolSavingPool[_poolId] = pool;
        userContributedPools[msg.sender].push(_poolId);
        userPoolBalance[msg.sender][_poolId] += _savedAmount;

        emit OpenSavingPool(
            msg.sender,
            _tokenTosaveWith,
            _index,
            _savedAmount,
            _starttime,
            _locktype,
            _duration,
            _poolId
        );
    }
    /*****
     * @notice Allow adding funds to an existing saving pool
     */

    function updateSaving(bytes32 _poolId, uint256 _amount) external {
        SavingPool storage pool = poolSavingPool[_poolId];
        if (pool.saver == address(0)) {
            revert NonExistentPool(_poolId);
        }
        if (pool.saver != msg.sender) {
            revert NotPoolOwner(msg.sender, _poolId);
        }
        if (pool.isStoped) {
            revert PoolStoped(msg.sender, _poolId);
        }
        if (pool.locktype == LockingType.STRICTLOCK) {
            revert StrictlySavingType(msg.sender, _poolId);
        }
        if (_amount == 0) {
            // Use == instead of <= for stricter check
            revert ZeroAmount(_amount);
        }
        // Check: Ensure pool duration hasn't expired for LOCK type
        if (
            pool.locktype == LockingType.LOCK &&
            block.timestamp > pool.startDate + pool.Duration
        ) {
            revert PoolDurationExpired(_poolId);
        }

        address token = pool.tokenToSaveWith;
        if (!IERC20(token).transferFrom(msg.sender, address(this), _amount)) {
            revert TransferFailed(token, msg.sender, _amount);
        }
        pool.amountSaved += _amount;

        //@dev this should be done in the withdraw function

        if (pool.locktype == LockingType.LOCK) {
            if (pool.Duration <= block.timestamp) {
                pool.isGoalAccomplished = true;
            }
        }

        emit UpdateSaving(
            msg.sender,
            token,
            _amount,
            _poolId,
            pool.amountSaved
        );
    }

    //Stop Saving
    function stopSaving(bytes32 _poolId) external {
        if (poolSavingPool[_poolId].saver != msg.sender) {
            revert NotPoolOwner(msg.sender, poolSavingPool[_poolId].poolIndex);
        }
        poolSavingPool[_poolId].isStoped = true;
        emit StopSaving(msg.sender, _poolId);
    }

    //Restart Saving
    function restartSaving(bytes32 _poolId) external {
        if (poolSavingPool[_poolId].saver != msg.sender) {
            revert NotPoolOwner(msg.sender, poolSavingPool[_poolId].poolIndex);
        }
        poolSavingPool[_poolId].isStoped = false;
        emit RestartSaving(msg.sender, _poolId);
    }

    /****
     * @notice Allow withdrawing funds from an existing saving pool
     * @param    poolId => bytes32
     * transfer penalty fee to the contract owner
     *transfer remaining amount to the user
     */
    function withdraw(bytes32 _poolId) external nonReentrant {
        SavingPool storage pool = poolSavingPool[_poolId];
        if (pool.saver != msg.sender) {
            revert NotPoolOwner(msg.sender, pool.poolIndex);
        }

        //for strictly locked
        if (pool.locktype == LockingType.STRICTLOCK) {
            if (pool.Duration > block.timestamp) {
                revert SavingPeriodStillOn(msg.sender, _poolId, pool.Duration);
            } else {
                //return all erc20 token to the user
                //saved amount to zero

                pool.isGoalAccomplished = true;
                require(
                    IERC20(pool.tokenToSaveWith).transfer(
                        pool.saver,
                        pool.amountSaved
                    ),
                    "failed to transfer"
                );
                pool.amountSaved = 0;
            }
        }
        if (pool.isGoalAccomplished) {
            //return all erc20 token to the user
            require(
                IERC20(pool.tokenToSaveWith).transfer(
                    pool.saver,
                    pool.amountSaved
                ),
                "failed to transfer"
            );
            //saved amount to zero
            pool.amountSaved = 0;
        } else {
            //take some penalty fee i.e 0.03%
            uint256 interest = LibChainCoopSaving.calculateInterest(
                pool.amountSaved
            );
            uint256 amountReturnToUser = pool.amountSaved - interest;
            //saved amount to zeror
            pool.amountSaved = 0;

            require(
                IERC20(pool.tokenToSaveWith).transfer(
                    pool.saver,
                    amountReturnToUser
                ),
                "Failed to transfer"
            );

            require(
                IERC20(pool.tokenToSaveWith).transfer(chainCoopFees, interest),
                "Failed to transfer"
            );
        }
    }

    /****
     * @notice Get All total number of  pools created
     */
    function getSavingPoolCount() external view returns (uint256) {
        return poolCount;
    }
    /***
     * @notice get pool by index
     * @param _poolIndex Index of the pool to get
     *
     * **/
    /****Can remove this after some considerations ?????????? */
    function getSavingPoolByIndex(
        bytes32 _index
    ) external view returns (SavingPool memory) {}
    /***
     * @notice get pool by the creator address
     * **/
    // function getSavingPoolBySaver(
    //     address _saver
    // ) external view returns (SavingPool[] memory pools) {
    //     uint256 userPoolCount = 0;

    //     for (uint256 i = 0; i < poolCount; i++) {
    //         if (userSavingPool[i].saver == _saver) {
    //             userPoolCount++;
    //         }
    //     }

    //     pools = new SavingPool[](userPoolCount);
    //     uint256 index = 0;

    //     // Populate the array with the user's pools
    //     for (uint256 i = 0; i < poolCount; i++) {
    //         if (userSavingPool[i].saver == _saver) {
    //             pools[index] = userSavingPool[i];
    //             index++;
    //         }
    //     }
    // }
    function getSavingPoolBySaver(
        address _saver
    ) external view returns (SavingPool[] memory) {
        bytes32[] memory poolIds = userContributedPools[_saver];
        SavingPool[] memory pools = new SavingPool[](poolIds.length);
        for (uint256 i = 0; i < poolIds.length; i++) {
            pools[i] = poolSavingPool[poolIds[i]];
        }
        return pools;
    }
    function getUserContributions(
        address _saver
    ) external view returns (Contribution[] memory contributions) {
        uint256 userPoolCount = userContributedPools[_saver].length;

        // Initialize the contributions array
        contributions = new Contribution[](userPoolCount);

        // Loop through the pools the user owns
        for (uint256 i = 0; i < userPoolCount; i++) {
            bytes32 poolId = userContributedPools[_saver][i]; // Retrieve the pool ID
            SavingPool storage pool = poolSavingPool[poolId]; // Fetch the pool details

            // Populate the contribution
            contributions[i] = Contribution({
                tokenAddress: pool.tokenToSaveWith,
                amount: pool.amountSaved
            });
        }
    }
}
