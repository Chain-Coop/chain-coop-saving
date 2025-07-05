// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;


library LibChainCoopSaving{
    function generatePoolIndex(address _user,uint256 _time,uint256  _initialSavingAmount)public pure returns(bytes32){
        
        return keccak256(abi.encode(_user,_time,_initialSavingAmount));

    }

    //calculate interest of 0.03 %
   function calculateInterest(uint256 _principal) public pure returns(uint256) {
    uint256 interest = (_principal * 3 * 100) / 10000; // Increased precision with 100 multiplier
    return interest;
}


}