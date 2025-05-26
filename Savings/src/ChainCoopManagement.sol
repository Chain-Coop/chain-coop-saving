// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;


//import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
contract ChainCoopManagement {

    address public owner;
    address public chainCoopFees;
    
   
    // Events
    event AllowToken(address _updator,address _allowedToken);
    event AdminChanged(address previousAdmin,address newAdmin);
    event ChainCoopFeesChanged(address indexed previousChainCoopFees,address indexed newChainCoopFees,address indexed _ownerChanged);
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
    // // Initialize function instead of constructor for upgradeable contract
    // function initialize(address _tokenAddress) public initializer {
    //     __Ownable_init();  // Initializes the OwnableUpgradeable (owner functionality)
    //     isTokenAllowed[_tokenAddress] = true;
    // }
  
   
    function transferOwnership(address newOwner) external onlyOwner {
        owner = newOwner;
        emit AdminChanged(owner,newOwner);
    }

    function setAllowedTokens(address _tokenAddress)external onlyOwner{
        isTokenAllowed[_tokenAddress] = true;
        emit AllowToken(msg.sender,_tokenAddress);

    }
    function removeAllowedTokens(address _tokenAddress)external onlyOwner{
        isTokenAllowed[_tokenAddress] =false;
        emit AllowToken(msg.sender,_tokenAddress);
        }
    function setChainCoopAddress(address _chaincoopfees)external onlyOwner{
        chainCoopFees = _chaincoopfees;
        emit ChainCoopFeesChanged(chainCoopFees,_chaincoopfees,msg.sender);

    }  

    
}
