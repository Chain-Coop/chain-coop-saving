// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;
import {IChainCoopSaving} from "./interface/IchainCoopSaving.sol";
import {LibChainCoopSaving} from  "./lib/LibChainCoopSaving.sol";
import "./ChainCoopManagement.sol";


//import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";


contract ChainCoopSaving is IChainCoopSaving,ChainCoopManagement{
    using LibChainCoopSaving for address;
   


    //constructor => incase of upgradability will update it
    constructor(address _tokenAddress) ChainCoopManagement(_tokenAddress){
      
        }

    //      function initialize(address _allowedToken) public initializer {
    //     __ChainCoopManagement_init(_allowedToken); // Initialize the inherited contract
   
    // }


    //events
    event OpenSavingPool(address indexed user,address indexed _tokenAddress,uint256 initialAmount,uint256 goalAmount,uint256 duration,bytes32 _poolId);    
    event Withdraw(address indexed user,address indexed _tokenAddress ,uint256 amount,bytes32 _poolId);  
    event UpdateSaving(address indexed user,address indexed _tokenAddress, uint256 amount,bytes32 _poolId);

    //Mapping
    mapping(address => SavingPool) public userSavingPool;
    mapping(bytes32 => SavingPool) public poolSavingPool;
    mapping(address => mapping(bytes32 => uint256)) public userPoolBalance;
   
   //Pool Count
   uint256 public poolCount = 0;

  

   
   

     /***
     * @notice Allow Opening a saving pool with initial contribution
     * 
     */
    function openSavingPool(address _tokenTosaveWith,uint256 _initialAmount,uint256 _goalAmount,string calldata _reason,uint256 _duration) onlyAllowedTokens(_tokenTosaveWith) external{}
    /*****
     * @notice Allow adding funds to an existing saving pool
     */
    function updateSaving(uint256 _amount)external{}

    function withdraw()external view returns(bytes32){}
  
    /****
     * @notice Get All total number of  pools created 
     */
    function getSavingPoolCount()external view returns(uint256){}
    /***
     * @notice get pool by index
     * @param _poolIndex Index of the pool to get
     * 
     * **/
    function getSavingPoolByIndex(bytes32 _index)external view returns(SavingPool memory){}
    /***
     * @notice get pool by the creator address
     * **/
    function getSavingPoolBySaver(address _saver)external view returns(SavingPool memory){}

    
}