
// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.7.3;

interface TokenInterface{
    function burnFrom(address _from, uint _amount) external;
    function mintTo(address _to, uint _amount) external;
}