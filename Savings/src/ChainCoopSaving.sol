// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;
import {IChainCoopSaving} from "./interface/IChainCoopSaving.sol";
import {LibChainCoopSaving} from "./lib/LibChainCoopSaving.sol";
import "./ChainCoopManagement.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
//import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

error ZeroAmount(uint256 _amount);
error ZeroDuration(uint256 _duration);
error ZeroGoalAmount(uint256 _goalamount);
error NotPoolOwner(address _caller, bytes32 _poolId);

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

    // Events
    event OpenSavingPool(
        address indexed user,
        address indexed _tokenAddress,
        uint256 _index,
        uint256 initialAmount,
        uint256 goalAmount,
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
        bytes32 _poolId
    );

    struct Contribution {
        address tokenAddress;
        uint256 amount;
    }

    // Mappings
    mapping(uint256 _poolIndex => SavingPool) public userSavingPool;
    mapping(bytes32 => SavingPool) public poolSavingPool;
    mapping(address => mapping(bytes32 => uint256)) public userPoolBalance;
    mapping(address => bytes32[]) public userContributedPools;

    // Pool Count
    uint256 public poolCount = 0;

    /***
     * @notice Allow Opening a saving pool with initial contribution
     */
    function openSavingPool(
        address _tokenTosaveWith,
        uint256 _savedAmount,
        uint256 _goalAmount,
        string calldata _reason,
        uint256 _duration
    ) external onlyAllowedTokens(_tokenTosaveWith) {
        if (_savedAmount <= 0) revert ZeroAmount(_savedAmount);
        if (_goalAmount <= 0) revert ZeroGoalAmount(_goalAmount);
        if (_duration <= 0) revert ZeroDuration(_duration);

        uint256 _index = poolCount;
        bytes32 _poolId = LibChainCoopSaving.generatePoolIndex(
            msg.sender,
            block.timestamp,
            _goalAmount
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
            goalAmount: _goalAmount,
            Duration: _duration,
            amountSaved: _savedAmount,
            isGoalAccomplished: false,
            isDeadlinePassed: false // Set initial deadline status to false
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
            _goalAmount,
            _duration,
            _poolId
        );
    }

    /*****
     * @notice Allow adding funds to an existing saving pool
     */
    function updateSaving(bytes32 _poolId, uint256 _amount) external {
        if (poolSavingPool[_poolId].saver != msg.sender)
            revert NotPoolOwner(msg.sender, poolSavingPool[_poolId].poolIndex);
        if (_amount <= 0) revert ZeroAmount(_amount);

        SavingPool storage pool = poolSavingPool[_poolId];
        require(
            IERC20(pool.tokenToSaveWith).transferFrom(
                msg.sender,
                address(this),
                _amount
            ),
            "failed to deposit"
        );

        pool.amountSaved += _amount;
        if (pool.amountSaved >= pool.goalAmount) {
            pool.isGoalAccomplished = true;
        }

        emit UpdateSaving(
            msg.sender,
            pool.tokenToSaveWith,
            _amount,
            pool.poolIndex
        );
    }

    /****
     * @notice Allow withdrawing funds from an existing saving pool
     * @param    poolId => bytes32
     * transfer penalty fee to the contract owner
     *transfer remaining amount to the user
     */
    function withdraw(bytes32 _poolId) external nonReentrant {
        SavingPool storage pool = poolSavingPool[_poolId];
        if (pool.saver != msg.sender)
            revert NotPoolOwner(msg.sender, pool.poolIndex);

        if (block.timestamp >= pool.Duration && !pool.isDeadlinePassed) {
            pool.isDeadlinePassed = true; // Mark deadline as passed
        }

        if (pool.isGoalAccomplished) {
            require(
                IERC20(pool.tokenToSaveWith).transfer(
                    pool.saver,
                    pool.amountSaved
                ),
                "failed to transfer"
            );
            pool.amountSaved = 0;
        } else {
            uint256 interest = LibChainCoopSaving.calculateInterest(
                pool.amountSaved
            );
            uint256 amountReturnToUser = pool.amountSaved - interest;
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

            pool.amountSaved = 0;
        }

        emit Withdraw(
            msg.sender,
            pool.tokenToSaveWith,
            pool.amountSaved,
            pool.poolIndex
        );
    }

    /***
     * @notice Get All total number of pools created
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
    ) external view returns (SavingPool memory) {
        return poolSavingPool[_index];
    }

    /***
     * @notice Get pool by the creator address
     */
    function getSavingPoolBySaver(
        address _saver
    ) external view returns (SavingPool[] memory pools) {
        uint256 userPoolCount = 0;

        for (uint256 i = 0; i < poolCount; i++) {
            if (userSavingPool[i].saver == _saver) {
                userPoolCount++;
            }
        }

        pools = new SavingPool[](userPoolCount);
        uint256 index = 0;

        // Populate the array with the user's pools

        for (uint256 i = 0; i < poolCount; i++) {
            if (userSavingPool[i].saver == _saver) {
                pools[index] = userSavingPool[i];
                index++;
            }
        }
    }

    function getUserContributions(
        address _saver
    ) external view returns (Contribution[] memory contributions) {
        uint256 userPoolCount = userContributedPools[_saver].length;

        // Initialize the contributions array
        contributions = new Contribution[](userPoolCount);

        // Loop through the pools the user owns
        for (uint256 i = 0; i < userPoolCount; i++) {
            bytes32 poolId = userContributedPools[_saver][i];
            SavingPool storage pool = poolSavingPool[poolId];

            // Populate the contribution
            contributions[i] = Contribution({
                tokenAddress: pool.tokenToSaveWith,
                amount: pool.amountSaved
            });
        }
    }
}
