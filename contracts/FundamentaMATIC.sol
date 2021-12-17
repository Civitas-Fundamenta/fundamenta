// SPDX-License-Identifier: GPL-3.0

// Author: Matt Hooft
// https://github.com/Civitas-Fundamenta
// mhooft@fundamenta.network

// Civitas Fundamenta's Polygon implementation of the Fundamenta Token.

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Context.sol";

contract FMTATokenMATIC is ERC20, AccessControl {
    
    using SafeERC20 for IERC20;
    using SafeMath for uint256;
    
   //------RBAC Vars--------------
   
    bytes32 public constant _MINT = keccak256("_MINT");
    bytes32 public constant _MINTTO = keccak256("_MINTTO");
    bytes32 public constant _BURN = keccak256("_BURN");
    bytes32 public constant _BURNFROM = keccak256("_BURNFROM");
    bytes32 public constant _SUPPLY = keccak256("_SUPPLY");
    bytes32 public constant _ADMIN = keccak256("_ADMIN");
   
   //------Token Variables------------------
   
    uint private _cap;
    
    //-------Toggle Variables---------------
    
    bool public paused;
    bool public mintDisabled;
    bool public mintToDisabled;
    
    //----------Events-----------------------
    
    event TokensMinted (uint _amount);
    event TokensMintedTo (address _to, uint _amount);
    event TokensBurned (uint _amount, address _burner);
    event TokensBurnedFrom (address _from, uint _amount, address _burner);
    event SupplyCapChanged (uint _newCap, address _changedBy);
    event ContractPaused (uint _blockHeight, address _pausedBy);
    event ContractUnpaused (uint _blockHeight, address _unpausedBy);
    event MintingEnabled (uint _blockHeight, address _enabledBy);
    event MintingDisabled (uint _blockHeight, address _disabledBy);
    event MintingToEnabled (uint _blockHeight, address _enabledBy);
    event MintingToDisabled (uint _blockHeight, address _disabledBy);
   
    //------Token/Admin Constructor---------
    
    constructor() ERC20("Fundamenta", "FMTA") {
        _cap = 2.5e25;
        mintDisabled = true;
        mintToDisabled = false;
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }
    

    //--------Toggle Functions----------------
    
    function setPaused(bool _paused) external {
        require(hasRole(_ADMIN, msg.sender),"Fundamenta: Message Sender must be _ADMIN");
        paused = _paused;
        if (_paused == true) {
            emit ContractPaused (block.number, msg.sender);
        } else if (_paused == false) {
            emit ContractUnpaused (block.number, msg.sender);
        }
    }
    
    function disableMint(bool _disableMinting) external {
        require(hasRole(_ADMIN, msg.sender),"Fundamenta: Message Sender must be _ADMIN");
        mintDisabled = _disableMinting;
        if (_disableMinting == true){
            emit MintingDisabled (block.number, msg.sender);
        }  else if (_disableMinting == false) {
            emit MintingEnabled (block.number, msg.sender);
        }  
    }
    
    function disableMintTo(bool _disableMintTo) external {
        require(hasRole(_ADMIN, msg.sender),"Fundamenta: Message Sender must be _ADMIN");
        mintToDisabled = _disableMintTo;
        if (_disableMintTo == true) {
            emit MintingToDisabled (block.number, msg.sender);
        } else if (_disableMintTo == false) {
            emit MintingToEnabled (block.number, msg.sender);
        }
    }

    //------Toggle Modifiers------------------
    
    modifier pause() {
        require(!paused, "Fundamenta: Contract is Paused");
        _;
    }
    
    modifier mintDis() {
        require(!mintDisabled, "Fundamenta: Minting is currently disabled");
        _;
    }
    
    modifier mintToDis() {
        require(!mintToDisabled, "Fundamenta: Minting to addresses is curently disabled");
        _;
    }
    
    //------Token Functions-----------------
    
    
    function mintTo(address _to, uint _amount) external pause mintToDis{
        require(hasRole(_MINTTO, msg.sender),"Fundamenta: Message Sender must be _MINTTO");
        _mint(_to, _amount);
        emit TokensMintedTo(_to, _amount);
    }
    
    function mint( uint _amount) external pause mintDis{
        require(hasRole(_MINT, msg.sender),"Fundamenta: Message Sender must be _MINT");
        _mint(msg.sender, _amount);
        emit TokensMinted(_amount);
    }
    
    function burn(uint _amount) external pause { 
        require(hasRole(_BURN, msg.sender),"Fundamenta: Message Sender must be _BURN");
        _burn(msg.sender,  _amount);
        emit TokensBurned(_amount, msg.sender);
    }
    
    function burnFrom(address _from, uint _amount) external pause {
        require(hasRole(_BURNFROM, msg.sender),"Fundamenta: Message Sender must be _BURNFROM");
        _burn(_from, _amount);
        emit TokensBurnedFrom(_from, _amount, msg.sender);
    }

    //----------Supply Cap------------------
    

    function setSupplyCap(uint _supplyCap) external pause {
        require(hasRole(_SUPPLY, msg.sender));
        _cap = _supplyCap;
        require(totalSupply() < _cap, "nope");
        emit SupplyCapChanged (_supplyCap, msg.sender);
    }
    
    function supplyCap() public view returns (uint) {
        return _cap;
    }
    
    function _beforeTokenTransfer(address from, address to, uint amount) internal virtual override {
        super._beforeTokenTransfer(from, to, amount);

        if (from == address(0)) { 
            require(totalSupply().add(amount) <= _cap, "Fundamenta: There is a Supply Cap dude. Come on...");
        }
    }
    
}
