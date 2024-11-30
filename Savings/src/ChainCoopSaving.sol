// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;
import {IChainCoopSaving} from "./interface/IchainCoopSaving.sol";
import {LibChainCoopSaving} from  "./lib/LibChainCoopSaving.sol";
import "./ChainCoopManagement.sol";

 /*****TODO
     * Add IERC20 Interface
     */
//import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";


error ZeroAmount(uint256 _amount);

error ZeroDuration(uint256 _duration);
error ZeroGoalAmount(uint256  _goalamount);
error NotPoolOwner(address _caller,bytes32 _poolId);

contract ChainCoopSaving is IChainCoopSaving,ChainCoopManagement{
    using LibChainCoopSaving for address;
   


    //constructor => incase of upgradability will update it
    constructor(address _tokenAddress) ChainCoopManagement(_tokenAddress){
      
        }

    //      function initialize(address _allowedToken) public initializer {
    //     __ChainCoopManagement_init(_allowedToken); // Initialize the inherited contract
   
    // }


    //events
    event OpenSavingPool(address indexed user,address indexed _tokenAddress,uint256 _index,uint256 initialAmount,uint256 goalAmount,uint256 duration,bytes32 _poolId);    
    event Withdraw(address indexed user,address indexed _tokenAddress ,uint256 amount,bytes32 _poolId);  
    event UpdateSaving(address indexed user,address indexed _tokenAddress,uint256 _index ,uint256 amount,bytes32 _poolId);

    //Mapping
    mapping(uint256 _poolIndex => SavingPool) public userSavingPool;
    mapping(bytes32 => SavingPool) public poolSavingPool;
    mapping(address => mapping(bytes32 => uint256)) public userPoolBalance;
   
   //Pool Count
   uint256 public poolCount = 0;

  

   
   

     /***
     * @notice Allow Opening a saving pool with initial contribution
     * 
     */
    function openSavingPool(address _tokenTosaveWith,uint256 _savedAmount,uint256 _goalAmount,string calldata _reason,uint256 _duration) onlyAllowedTokens(_tokenTosaveWith) external{
       if (_savedAmount <= 0){
        revert ZeroAmount(_savedAmount);
       }
       if (_goalAmount <= 0){
        revert ZeroGoalAmount(_goalAmount);
        }
        if (_duration <= 0){
            revert ZeroDuration(_duration);
            }
            uint256 _index  = poolCount;
            
       bytes32 _poolId = LibChainCoopSaving.generatePoolIndex(
        msg.sender,       
        block.timestamp,   
        _goalAmount        
    );
    
    SavingPool memory pool = SavingPool({saver:msg.sender,tokenToSaveWith:_tokenTosaveWith,Reason:_reason,poolIndex:_poolId,goalAmount:_goalAmount,Duration:_duration,amountSaved:_savedAmount,isGoalAccomplished:false});
    userSavingPool[_index] = pool;
    poolSavingPool[_poolId] = pool;
    userPoolBalance[msg.sender][_poolId] = _savedAmount;
    poolCount++;
    emit OpenSavingPool(msg.sender,_tokenTosaveWith,_index,_savedAmount,_goalAmount,_duration,_poolId);

        
    }
    /*****
     * @notice Allow adding funds to an existing saving pool
     */
   
    function updateSaving(uint256 _index,uint256 _amount)external {
        
        if(userSavingPool[_index].saver != msg.sender){
            revert NotPoolOwner(msg.sender,userSavingPool[_index].poolIndex);
        }
        if(_amount <= 0){
            revert ZeroAmount(_amount);
            }
           SavingPool storage pool = userSavingPool[_index];
           pool.amountSaved += _amount;
           if(pool.amountSaved >= pool.goalAmount){
            pool.isGoalAccomplished = true;
           }
          
           emit UpdateSaving(msg.sender,pool.tokenToSaveWith, _index, _amount,pool.poolIndex);

            
            
    }

//prevent reentrancy attack
    function withdraw(uint256 _index)external {
        SavingPool storage pool = userSavingPool[_index];
        if(pool.saver != msg.sender){
            revert NotPoolOwner(msg.sender,pool.poolIndex);
            }
            if(pool.isGoalAccomplished){
                //return all erc20 token to the user
                //saved amount to zero
                //transfer

                pool.amountSaved = 0;
                
                }else{
                    //return all erc20 token to the user
                    //saved amount to zeror
                    //take some penalty fee i.e 1 %
                    //transfer penalty fee to the contract owner
                    //transfer remaining amount to the user

                }
                
                
                
                


    }
  
    /****
     * @notice Get All total number of  pools created 
     */
    function getSavingPoolCount()external view returns(uint256){
        return poolCount;

    }
    /***
     * @notice get pool by index
     * @param _poolIndex Index of the pool to get
     * 
     * **/
     /****Can remove this after some considerations ?????????? */
    function getSavingPoolByIndex(bytes32 _index)external view returns(SavingPool memory){}
    /***
     * @notice get pool by the creator address
     * **/
    function getSavingPoolBySaver(address _saver)external view returns(SavingPool[] memory pools){
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

    
}