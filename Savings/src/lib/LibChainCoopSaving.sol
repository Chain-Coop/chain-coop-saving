// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;
type UserAddress is address;
type CreatedAt is uint256;
type TargetAmount is uint256;

library LibChainCoopSaving{
    function generatePoolIndex(UserAddress _user,CreatedAt _time,TargetAmount _target)public pure returns(bytes32){
        
        return keccak256(abi.encode(_user,_time,_target));

    }

}