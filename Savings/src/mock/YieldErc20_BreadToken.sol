// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ChainCoopManagement} from "../ChainCoopManagement.sol";

/****TODO
 * Exploring if we can go with upgradeable contracts
 */

//import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
//import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
contract YieldErc20_BreadToken is ERC20{
    uint256 public  constant Decimals = 10**18;
    address owner;
    
   
    constructor()ERC20("Bread","BR"){
        owner = msg.sender;
        
        
    }
    // function initialize(string memory name, string memory symbol, uint256 initialSupply) public initializer {
    //     __ERC20_init(name, symbol);
    //     _mint(msg.sender, initialSupply);
    // }

    /***
     * TODO
     * // Ensure that only the owner can mint
     */
    modifier onlyOwner(){
        require(owner == msg.sender,"only owner");
        _;
    }
    function mint(address to, uint256 amount) public  onlyOwner(){       
        
        _mint(to, amount*Decimals);
    }
    function burn(address from, uint256 amount) public {
        _burn(from, amount*Decimals);
        }

        
    
}