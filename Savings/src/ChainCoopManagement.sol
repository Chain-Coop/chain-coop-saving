// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract ChainCoopManagement is Initializable, OwnableUpgradeable {
    address public chainCoopFees;

    // Events
    event AllowToken(address _updator, address _allowedToken);
    event AdminChanged(address previousAdmin, address newAdmin);
    event ChainCoopFeesChanged(
        address indexed previousChainCoopFees,
        address indexed newChainCoopFees,
        address indexed _ownerChanged
    );

    // Mapping
    mapping(address => bool) public isTokenAllowed;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    // 🚀 Internal initializer instead of public initialize
    function __ChainCoopManagement_init(
        address _tokenAddress
    ) internal onlyInitializing {
        __Ownable_init(msg.sender);
        isTokenAllowed[_tokenAddress] = true;
    }

    modifier onlyAllowedTokens(address _tokenAddress) {
        require(isTokenAllowed[_tokenAddress], "Only allowed tokens");
        _;
    }

    function transferOwnership(address newOwner) public override onlyOwner {
        address previousOwner = owner();
        super.transferOwnership(newOwner);
        emit AdminChanged(previousOwner, newOwner);
    }

    function setAllowedTokens(address _tokenAddress) external onlyOwner {
        isTokenAllowed[_tokenAddress] = true;
        emit AllowToken(msg.sender, _tokenAddress);
    }

    function removeAllowedTokens(address _tokenAddress) external onlyOwner {
        isTokenAllowed[_tokenAddress] = false;
        emit AllowToken(msg.sender, _tokenAddress);
    }

    function setChainCoopAddress(address _chaincoopfees) external onlyOwner {
        address previousChainCoopFees = chainCoopFees;
        chainCoopFees = _chaincoopfees;
        emit ChainCoopFeesChanged(
            previousChainCoopFees,
            _chaincoopfees,
            msg.sender
        );
    }

    uint256[49] private __gap;
}
