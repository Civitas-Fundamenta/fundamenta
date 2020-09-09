// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;

import "./Ownable.sol";



contract Proxy is Ownable {
    
    address public token;
    
    function setAddress(address _token) public onlyOwner {
        token = _token;
    }
    
    function mint( uint _amount) public onlyOwner {
        ProxyInterface t = ProxyInterface(token);
        t.mint(_amount);
    }
}

abstract contract ProxyInterface {
    function mint( uint _amount) public virtual;
}