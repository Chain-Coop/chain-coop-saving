// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IChainCoopSaving {
    //enum with locking
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
        LockingType locktype;
        bool isGoalAccomplished;
        bool isStoped;
    }

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
    ) external;

    /*****
     * @notice Allow adding funds to an existing saving pool
     */
    function updateSaving(bytes32 _poolIndex, uint256 _amount) external;

    /*****
     * @notice Allow withdrawing funds from an existing saving pool
     *
     * */
    function withdraw(bytes32 _poolId) external;

    //Stop Saving
    function stopSaving(bytes32 _poolId) external;

    //Restart Saving
    function restartSaving(bytes32 _poolId) external;

    /****
     * @notice Get All total number of  pools created
     */
    function getSavingPoolCount() external view returns (uint256);

    /***
     * @notice get pool by index
     * @param _poolIndex Index of the pool to get
     *
     * **/
    function getSavingPoolByIndex(
        bytes32 _index
    ) external view returns (SavingPool memory);

    /***
     * @notice get pool by the creator address
     * **/
    function getSavingPoolBySaver(
        address _saver
    ) external view returns (SavingPool[] memory);
}
