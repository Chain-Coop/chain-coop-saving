// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;
import {IChainCoopSaving} from "./interface/IchainCoopSaving.sol";
import {LibChainCoopSaving} from "./lib/LibChainCoopSaving.sol";
import "./ChainCoopManagement.sol";

import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/metatx/ERC2771Context.sol";

error ZeroAmount(uint256 _amount);
error ZeroDuration(uint256 _duration);
error ZeroGoalAmount(uint256 _goalamount);
error NotPoolOwner(address _caller, bytes32 _poolId);
error StrictlySavingType(address _caller, bytes32 _poolId);
error SavingPeriodStillOn(address _caller, bytes32 _poolId, uint256 _endDate);
error PoolStoped(address _caller, bytes32 _poolid);

contract ChainCoopSaving is
    IChainCoopSaving,
    ChainCoopManagement,
    ReentrancyGuard,
    ERC2771Context
{
    using LibChainCoopSaving for address;

    // Constructor updated to include trusted forwarder for ERC2771
    constructor(
        address _tokenAddress,
        address _trustedForwarder
    ) ChainCoopManagement(_tokenAddress) ERC2771Context(_trustedForwarder) {}

    // Override _msgSender() and _msgData() to support meta-transactions
    function _msgSender() internal view override returns (address sender) {
        return ERC2771Context._msgSender();
    }

    function _msgData() internal view override returns (bytes calldata) {
        return ERC2771Context._msgData();
    }

    // Events
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
        bytes32 _poolId
    );
    event RestartSaving(address _poolOwner, bytes32 _poolId);
    event StopSaving(address _poolOwner, bytes32 _poolId);
    event PoolClosed(address indexed user, bytes32 indexed poolId);

    struct Contribution {
        address tokenAddress;
        uint256 amount;
    }

    // Mappings
    mapping(bytes32 => SavingPool) public poolSavingPool;
    mapping(address => mapping(bytes32 => uint256)) public userPoolBalance;
    mapping(address => bytes32[]) public userContributedPools;

    // Pool Count
    uint256 public poolCount = 0;

    /**
     * @notice Allow Opening a saving pool with initial contribution
     * @dev Now supports meta-transactions through ERC2771Context
     */
    function openSavingPool(
        address _tokenTosaveWith,
        uint256 _savedAmount,
        string calldata _reason,
        LockingType _locktype,
        uint256 _duration
    ) external onlyAllowedTokens(_tokenTosaveWith) {
        address sender = _msgSender(); // Use ERC2771Context _msgSender()

        if (_savedAmount <= 0) {
            revert ZeroAmount(_savedAmount);
        }

        if (_duration <= 0) {
            revert ZeroDuration(_duration);
        }

        uint256 _index = poolCount;
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

        require(
            IERC20(_tokenTosaveWith).transferFrom(
                sender,
                address(this),
                _savedAmount
            ),
            "failed to deposit"
        );

        SavingPool memory pool = SavingPool({
            saver: sender,
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
        poolSavingPool[_poolId] = pool;
        userContributedPools[sender].push(_poolId);
        userPoolBalance[sender][_poolId] += _savedAmount;

        emit OpenSavingPool(
            sender,
            _tokenTosaveWith,
            _index,
            _savedAmount,
            _starttime,
            _locktype,
            _duration,
            _poolId
        );
    }

    /**
     * @notice Allow adding funds to an existing saving pool
     * @dev Now supports meta-transactions through ERC2771Context
     */
    function updateSaving(bytes32 _poolId, uint256 _amount) external {
        address sender = _msgSender(); // Use ERC2771Context _msgSender()

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
        require(
            IERC20(pool.tokenToSaveWith).transferFrom(
                sender,
                address(this),
                _amount
            ),
            "failed to deposit"
        );

        pool.amountSaved += _amount;
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
     * @dev Now supports meta-transactions through ERC2771Context
     */
    function stopSaving(bytes32 _poolId) external {
        address sender = _msgSender(); // Use ERC2771Context _msgSender()

        if (poolSavingPool[_poolId].saver != sender) {
            revert NotPoolOwner(sender, poolSavingPool[_poolId].poolIndex);
        }
        poolSavingPool[_poolId].isStoped = true;
        emit StopSaving(sender, _poolId);
    }

    /**
     * @notice Restart Saving
     * @dev Now supports meta-transactions through ERC2771Context
     */
    function restartSaving(bytes32 _poolId) external {
        address sender = _msgSender(); // Use ERC2771Context _msgSender()

        if (poolSavingPool[_poolId].saver != sender) {
            revert NotPoolOwner(sender, poolSavingPool[_poolId].poolIndex);
        }
        poolSavingPool[_poolId].isStoped = false;
        emit RestartSaving(sender, _poolId);
    }

    /**
     * @notice Allow withdrawing funds from an existing saving pool
     * @param _poolId bytes32 pool identifier
     * @dev Now supports meta-transactions through ERC2771Context
     * Transfer penalty fee to the contract owner
     * Transfer remaining amount to the user
     */
    function withdraw(bytes32 _poolId) external nonReentrant {
        address sender = _msgSender(); // Use ERC2771Context _msgSender()
        SavingPool storage pool = poolSavingPool[_poolId];

        if (pool.saver != sender) {
            revert NotPoolOwner(sender, pool.poolIndex);
        }

        if (pool.locktype == LockingType.STRICTLOCK) {
            if (pool.Duration > block.timestamp) {
                revert SavingPeriodStillOn(sender, _poolId, pool.Duration);
            } else {
                uint256 amount = pool.amountSaved;
                pool.amountSaved = 0;
                pool.isGoalAccomplished = true;
                require(
                    IERC20(pool.tokenToSaveWith).transfer(pool.saver, amount),
                    "failed to transfer"
                );
            }
        } else if (pool.isGoalAccomplished) {
            uint256 amount = pool.amountSaved;
            pool.amountSaved = 0;
            require(
                IERC20(pool.tokenToSaveWith).transfer(pool.saver, amount),
                "failed to transfer"
            );
        } else {
            uint256 interest = LibChainCoopSaving.calculateInterest(
                pool.amountSaved
            );
            uint256 amountReturnToUser = pool.amountSaved - interest;
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

        emit Withdraw(
            sender,
            pool.tokenToSaveWith,
            pool.amountSaved,
            pool.poolIndex
        );

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
     * @notice Get All total number of pools created
     */
    function getSavingPoolCount() external view returns (uint256) {
        return poolCount;
    }

    function getSavingPoolByIndex(
        bytes32 _index
    ) external view returns (SavingPool memory) {
        return poolSavingPool[_index];
    }

    /**
     * @notice get pool by the creator address
     */
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

            contributions[i] = Contribution({
                tokenAddress: pool.tokenToSaveWith,
                amount: pool.amountSaved
            });
        }
    }

    /**
     * @notice Check if the contract supports meta-transactions
     * @return bool true if meta-transactions are supported
     */
    function supportsMetaTransactions() external pure returns (bool) {
        return true;
    }

    /**
     * @notice Get the trusted forwarder address
     * @return address The trusted forwarder address
     */
    function getTrustedForwarder() external view returns (address) {
        return trustedForwarder();
    }
}
