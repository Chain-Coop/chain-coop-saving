// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

interface IChainCoopSaving {
    struct SavingPool {
        address saver;
        address tokenToSaveWith;
        string Reason;
        bytes32 poolIndex;
        uint256 goalAmount;
        uint256 Duration;
        uint256 amountSaved;
        bool isGoalAccomplished;
        bool isDeadlinePassed;
    }

    /***
     * @notice Allow Opening a saving pool with initial contribution
     *
     */
    function openSavingPool(
        address _tokenTosaveWith,
        uint256 _savedAmount,
        uint256 _goalAmount,
        string calldata _reason,
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
