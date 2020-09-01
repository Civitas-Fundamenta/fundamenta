pragma solidity ^0.6.0;

import "./ERC20.sol";
import "../../access/Ownable.sol";
import "../../access/AccessControl.sol";

contract FMTAToken is ERC20, Ownable, AccessControl {
    
    uint256 private _cap;
    uint256 public _premine;
    bytes32 public constant _MINTER = keccak256("_MINTER");
    bytes32 public constant _BURNER = keccak256("_BURNER");
    
    
    constructor() public {
        _cap = 25000000000000000000000000;
        _premine = 7500000000000000000000000;
        _mint(msg.sender, _premine);
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }
    
    function mint(address _to, uint _amount) public {
        require(hasRole(_MINTER, msg.sender));
        _mint(_to, _amount);
    }
    
    function burn(uint _amount) public onlyOwner { 
        require(hasRole(_BURNER, msg.sender));
        _burn(msg.sender,  _amount);
    }

   
    /**
     * @dev Returns the cap on the token's total supply.
     */
    function cap() public view returns (uint256) {
        return _cap;
    }

    
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual override {
        super._beforeTokenTransfer(from, to, amount);

        if (from == address(0)) { // When minting tokens
            require(totalSupply().add(amount) <= _cap, "There is a Supply Cap dude. Come on...");
        }
    }
}
