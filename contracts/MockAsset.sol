// SPDX-License-Identifier: BSD-3-Clause

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract MockAsset is ERC20 {
    
    using SafeERC20 for IERC20;
    using SafeMath for uint256;
    
    constructor() ERC20("MockAsset", "MOCK") {}
    
    function mintTo(address _to, uint _amount) external {
        _mint(_to, _amount);
    }
    
    function mint( uint _amount) external {
        _mint(msg.sender, _amount);
    }
    
    function burn(uint _amount) external { 
        _burn(msg.sender,  _amount);
    }
    
    function burnFrom(address _from, uint _amount) external {
        _burn(_from, _amount);
    }

}