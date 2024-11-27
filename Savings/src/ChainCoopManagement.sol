// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;



contract ChainCoopManagement {

    address public owner;
    
   
    // Events
    event AllowToken(address _updator,address _allowedToken);
    event AdminChanged(address previousAdmin,address newAdmin);
    //mapping
    mapping(address => bool) public isTokenAllowed;

    modifier onlyOwner() {
        require(msg.sender == owner, "Only the owner can execute this");
        _;
    }
    modifier onlyAllowedTokens(address _tokenAddress){
        require(isTokenAllowed[_tokenAddress],"Only allowed tokens");
        _;
    }

    constructor(address _tokenAddress) {
        owner = msg.sender;
        isTokenAllowed[_tokenAddress] = true;
       
    }
  
   
    function transferOwnership(address newOwner) external onlyOwner {
        owner = newOwner;
        emit AdminChanged(owner,newOwner);
    }

    function setAllowedTokens(address _tokenAddress)external onlyOwner{
        isTokenAllowed[_tokenAddress] = true;
        emit AllowToken(msg.sender,_tokenAddress);

    }

    
}
