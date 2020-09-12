
// SPDX-License-Identifier: MIT

pragma solidity ^0.7.0;

interface Interface{
    function burnFrom(address _from, uint _amount) external;
    function mintTo(address _to, uint _amount) external;
}