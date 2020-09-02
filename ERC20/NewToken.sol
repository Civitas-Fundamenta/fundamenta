pragma solidity ^0.6.0;

import "./ERC20.sol";
import "./Ownable.sol";
import "./AccessControl.sol";

contract FMTAToken is ERC20, Ownable, AccessControl {
    
    uint256 private _cap;
    uint256 public _premine;
    bytes32 public constant _MINTER = keccak256("_MINTER");
    bytes32 public constant _BURNER = keccak256("_BURNER");
    bool public paused;
    
    
    
    constructor() public {
        _cap = 25000000000000000000000000;
        _premine = 7500000000000000000000000;
        _mint(msg.sender, _premine);
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }
    
    modifier pause() {
        require(!paused, "Contract is Paused");
        _;
    }
    
    function mintTo(address _to, uint _amount) public pause {
        require(hasRole(_MINTER, msg.sender));
        _mint(_to, _amount);
    }
    
    function mint( uint _amount) public pause {
        require(hasRole(_MINTER, msg.sender));
        _mint(msg.sender, _amount);
    }
    
    function burn(uint _amount) public pause { 
        require(hasRole(_BURNER, msg.sender));
        _burn(msg.sender,  _amount);
    }
    
    function burnFrom(address _from, uint _amount) public pause {
        require(hasRole(_BURNER, msg.sender));
        _burn(_from, _amount);
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
    
    function setPaused(bool _paused) public onlyOwner {
        paused = _paused;
    }
    
}
