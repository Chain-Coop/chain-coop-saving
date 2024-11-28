// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;


library LibChainCoopSaving{
    function generatePoolIndex(address _user,uint256 _time,uint256  _target)public pure returns(bytes32){
        
        return keccak256(abi.encode(_user,_time,_target));

    }

}