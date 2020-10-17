// SPDX-License-Identifier: GPL-3.0

// Author: Matt Hooft
// https://github.com/Civitas-Fundamenta
// mhooft@fundamenta.network

// This is Civitas Fundamenta's implementation of the Fundamenta Token.
// It utilizes a Role Based Access Control System to allow outside contracts
// and accounts to interact with it securely providing future extesibility which
// as you will see is a theme with our smart contracts. 

pragma solidity ^0.7.3;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/GSN/Context.sol";

contract FMTAToken is ERC20, AccessControl {
    
    using SafeERC20 for IERC20;
    using SafeMath for uint256;
    
    /**
     * @dev Token uses Role Based Access Control to 
     * alllow for secure access as well as enabling the ability 
     * for other contracts such as oracles and supply mechanisms
     * to interact with it.
     */
    
   //------RBAC Vars--------------
   
    bytes32 public constant _MINT = keccak256("_MINT");
    bytes32 public constant _MINTTO = keccak256("_MINTTO");
    bytes32 public constant _BURN = keccak256("_BURN");
    bytes32 public constant _BURNFROM = keccak256("_BURNFROM");
    bytes32 public constant _SUPPLY = keccak256("_SUPPLY");
    bytes32 public constant _ADMIN = keccak256("_ADMIN");
   
   //------Token Variables------------------
   
    uint private _cap;
    uint public _fundingEmission;
    uint public _team;
    uint public _originalLiquidityProviders;
    
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
        _fundingEmission = 1e25;
        _team = 5e24;
        _originalLiquidityProviders = 3.6e24;
        _cap = 1e26;
        _mint(0x22a68bb25BF760d954c7E67fF06dc85297356068, _fundingEmission); // Funding Emission will be minted to a FE Dedicated Account
        _mint(0xa4dda4edfb34222063c77dfe2f50b30f5df39870, _team); // Locked in Vesting contract for 6 Months. See next Note.
        _mint(0xa4dda4edfb34222063c77dfe2f50b30f5df39870, _originalLiquidityProviders);
        _mint(0x458FD3022bBBe2fb66625dE58db668d2d523c222, 1.8e22); // 10% of total share of tokens for original liquidity providers are unlocked.
        _mint(0x56aAf8Bb0e5E52E414FD530eac2DFcCc9cAa349b, 4.6e22); // The Majority will be locked in a Vesting Contract located at the address
        _mint(0x223478514F46a1788aB86c78C431F7882fD53Af5, 3.36e23); //  . Team Tokens are locked in the same Vesting contract. 
        mintDisabled = true;
        mintToDisabled = true;
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }
    
    /**
     * @dev functions used to toggle contract states.
     * Includes disabling or enabling minting and 
     * pausing of the contract
     */

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
    
    
    /**
     * @dev token funtions require role based access to 
     * execute.  This gives us the ability to allow outside 
     * interaction with the token contract securely.
     */
    
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
    
    
    /**
     * @dev tokens supply cap is configureable and also 
     * leverages RBAC to allow outside mechanisms like  
     * oracles to interact with it securely.
     */

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

