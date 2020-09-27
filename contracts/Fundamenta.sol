// SPDX-License-Identifier: MIT

// Author: Matt Hooft
// https://github.com/Civitas-Fundamenta
// mhooft@fundamenta.network

// This is Civitas Fundamenta's implementation of the Fundamenta Token.
// It utilizes a Role Based Access Control System to allow outside contracts
// and accounts to interact with it securely providing future extesibility which
// as you will see is a theme with our smart contracts. 

pragma solidity ^0.7.0;

import "./ERC20.sol";
import "./SafeERC20.sol";
import "./Ownable.sol";
import "./AccessControl.sol";
import "./SafeMath.sol";
import "./Context.sol";

contract FMTAToken is ERC20, Ownable, AccessControl {
    
    using SafeERC20 for IERC20;
    using SafeMath for uint256;
    using Address for address;
    
    /**
     * @dev Token uses Role Based Access Control to 
     * 
     * alllow for secure access as well as enabling the ability 
     *
     * for other contracts such as oracles and supply mechanisms
     * 
     * to interact with it.
     */
    
   //------RBAC Vars--------------
   
    bytes32 public constant _MINTER = keccak256("_MINTER");
    bytes32 public constant _BURNER = keccak256("_BURNER");
    bytes32 public constant _SUPPLY = keccak256("_SUPPLY");
   
   //------Token Variables------------------
   
    uint256 private _cap;
    uint256 public _fundingEmission;
    uint256 public _team;
    uint256 public _originalLiquidtyProviders;
    
    //-------Toggle Variables---------------
    
    bool public paused;
    bool public mintDisabled;
    bool public mintToDisabled;
    
    //----------Events-----------------------
    
    event tokensMinted (uint256 _amount);
    event tokensMintedTo (address _to, uint256 _amount);
    event tokensBurned (uint256 _amount, address _burner);
    event tokensBurnedFrom (address _from, uint256 _amount, address _burner);
    event supplyCapChanged (uint256 _newCap, address _changedBy);
    event contractPaused (uint256 _blockHeight, address _pausedBy);
    event contractUnpaused (uint256 _blockHeight, address _unpausedBy);
    event mintingEnabled (uint256 _blockHeight, address _enabledBy);
    event mintingDisabled (uint256 _blockHeight, address _disabledBy);
    event mintingToEnabled (uint256 _blockHeight, address _enabledBy);
    event mintingToDisabled (uint256 _blockHeight, address _disabledBy);
   
    //------Token/Admin Constructor---------
    
    constructor() ERC20("Fundamenta", "FMTA") {
        _fundingEmission = 1e25;
        _team = 5e24;
        _originalLiquidtyProviders = 3e24;
        _cap = 1e26;
        mintDisabled = true;
        mintToDisabled = true;
        _mint(msg.sender, _fundingEmission);
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }
    
    /**
     * @dev functions used to toggle contract states.
     * 
     * Includes disabling or enabling minting and 
     * 
     * pausing of the contract
     */

    //--------Toggle Functions----------------
    
    function setPaused(bool _paused) external onlyOwner {
        paused = _paused;
        if (_paused == true) {
            emit contractPaused (block.number, msg.sender);
        } else if (_paused == false) {
            emit contractUnpaused (block.number, msg.sender);
        }
    }
    
    function disableMint(bool _disableMinting) external onlyOwner {
        mintDisabled = _disableMinting;
        if (_disableMinting == true){
            emit mintingDisabled (block.number, msg.sender);
        }  else if (_disableMinting == false) {
            emit mintingEnabled (block.number, msg.sender);
        }  
    }
    
    function disableMintTo(bool _disableMintTo) external onlyOwner {
        mintToDisabled = _disableMintTo;
        if (_disableMintTo == true) {
            emit mintingToDisabled (block.number, msg.sender);
        } else if (_disableMintTo == false) {
            emit mintingToEnabled (block.number, msg.sender);
        }
    }

    //------Toggle Modifiers------------------
    
    modifier pause() {
        require(!paused, "Contract is Paused");
        _;
    }
    
    modifier mintDis() {
        require(!mintDisabled, "Minting is currently disabled");
        _;
    }
    
    modifier mintToDis() {
        require(!mintToDisabled, "Minting to addresses is curently disabled");
        _;
    }
    
    //------Token Functions-----------------
    
    
    /**
     * @dev token funtions require role based access to 
     * 
     * execute.  This gives us the ability to allow outside 
     *
     * interaction with the token contract securely.
     */
    
    function mintTo(address _to, uint _amount) external pause mintToDis{
        require(hasRole(_MINTER, msg.sender));
        _mint(_to, _amount);
        emit tokensMintedTo(_to, _amount);
    }
    
    function mint( uint _amount) external pause mintDis{
        require(hasRole(_MINTER, msg.sender));
        _mint(msg.sender, _amount);
        emit tokensMinted(_amount);
    }
    
    function burn(uint _amount) external pause { 
        require(hasRole(_BURNER, msg.sender));
        _burn(msg.sender,  _amount);
        emit tokensBurned(_amount, msg.sender);
    }
    
    function burnFrom(address _from, uint _amount) external pause {
        require(hasRole(_BURNER, msg.sender));
        _burn(_from, _amount);
        emit tokensBurnedFrom(_from, _amount, msg.sender);
    }

    //----------Supply Cap------------------
    
    
    /**
     * @dev tokens supply cap is configureable and also 
     * 
     * leverages RBAC to allow outside mechanisms like  
     *
     * oracles to interact with it securely.
     */

    function setSupplyCap(uint _supplyCap) external pause {
        require(hasRole(_SUPPLY, msg.sender));
        if(_supplyCap >= totalSupply()) {
            revert ("Yeah... Can't make the supply cap less then the total supply.");
        }
        _cap = _supplyCap;
        emit supplyCapChanged (_supplyCap, msg.sender);
    }
    
    function supplyCap() public view returns (uint256) {
        return _cap;
    }
    
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual override {
        super._beforeTokenTransfer(from, to, amount);

        if (from == address(0)) { 
            require(totalSupply().add(amount) <= _cap, "There is a Supply Cap dude. Come on...");
        }
    }
    
}
