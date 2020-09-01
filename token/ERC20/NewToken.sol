pragma solidity ^0.6.0;

import "./ERC20.sol";
import "../../access/Ownable.sol";

contract FMTAToken is ERC20, Ownable {
    
    uint256 private _cap;
    uint256 public _premine;
    
    constructor() public {
        _cap = 25000000000000000000000000;
        _premine = 7500000000000000000000000;
        _mint(msg.sender, _premine);
    }
    
    function mint(address _to, uint _amount) public onlyOwner { 
        _mint(_to, _amount);
    }
    
    function burn(uint _amount) public onlyOwner { 
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
