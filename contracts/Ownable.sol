// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;

import "./Context.sol";

contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor () internal {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    function owner() public view returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(_owner == _msgSender(), "Ah, ah, ah, you didn't say the magic word...");
        _;
    }

    function renounceOwnership(address newOwner) public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(newOwner);
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}
