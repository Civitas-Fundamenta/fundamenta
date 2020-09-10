// SPDX-License-Identifier: MIT

pragma solidity ^0.7.0;

import "./Ownable.sol";



contract Proxy is Ownable {
    
    address public token;
    
    function setAddress(address _token) public onlyOwner {
        token = _token;
    }
    
    function createStake(uint256 _stake, address _staker) public {
        ProxyInterface t = ProxyInterface(token);
        t.createStake(_stake, _staker);
    }
    
    function removeStake(uint256 _stake, address _staker) public {
        ProxyInterface t = ProxyInterface(token);
        t.removeStake(_stake, _staker);
    }
}

abstract contract ProxyInterface {
    function createStake(uint256 _stake, address _staker) public virtual;
    function removeStake(uint256 _stake, address _staker) public virtual;
}