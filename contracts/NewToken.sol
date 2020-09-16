2// SPDX-License-Identifier: MIT

pragma solidity ^0.7.0;

import "./ERC20.sol";
import "./SafeERC20.sol";
import "./Ownable.sol";
import "./AccessControl.sol";
import "./SafeMath.sol";
import "./Context.sol";

contract TESTToken is ERC20, Ownable, AccessControl {
    
    using SafeERC20 for IERC20;
    using SafeMath for uint256;
    using Address for address;
    
   //------RBAC Vars--------------
   
    bytes32 public constant _MINTER = keccak256("_MINTER");
    bytes32 public constant _BURNER = keccak256("_BURNER");
    bytes32 public constant _SUPPLY = keccak256("_SUPPLY");
   
   //------Token Variables------------------
   
    uint256 private _cap;
    uint256 public _fundingEmission;
    
    //-------Toggle Variables---------------
    
    bool public paused;
    bool public mintDisabled;
    bool public mintToDisabled;
   
    //------Token/Admin Constructor---------
    
    constructor() ERC20("TEST", "TEST") {
        _fundingEmission = 7.5e24;
        _cap = 5e25;
        mintDisabled = true;
        mintToDisabled = true;
        _mint(msg.sender, _fundingEmission);
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    //--------Toggle Functions----------------
    
    function setPaused(bool _paused) external onlyOwner {
        paused = _paused;
    }
    
    function disableMint(bool _disableMinting) external onlyOwner {
        mintDisabled = _disableMinting;
    }
    
    function disableMintTo(bool _disableMintTo) external onlyOwner {
        mintToDisabled = _disableMintTo;
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
    
    function mintTo(address _to, uint _amount) external pause mintToDis{
        require(hasRole(_MINTER, msg.sender));
        _mint(_to, _amount);
    }
    
    function mint( uint _amount) external pause mintDis{
        require(hasRole(_MINTER, msg.sender));
        _mint(msg.sender, _amount);
    }
    
    function burn(uint _amount) external pause { 
        require(hasRole(_BURNER, msg.sender));
        _burn(msg.sender,  _amount);
    }
    
    function burnFrom(address _from, uint _amount) external pause {
        require(hasRole(_BURNER, msg.sender));
        _burn(_from, _amount);
    }

    //----------Supply Cap------------------

    function setSupplyCap(uint _supplyCap) external pause {
        require(hasRole(_SUPPLY, msg.sender));
        if(_supplyCap >= totalSupply()) {
            revert ("Yeah... Can't make the supply cap less then the total supply.");
        }
        _cap = _supplyCap;
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
