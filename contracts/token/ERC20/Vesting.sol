// SPDX-License-Identifier: MIT

pragma solidity ^0.6.0;

import "./SafeERC20.sol";
import "../../access/Ownable.sol";

contract Vesting is Ownable {
    using SafeERC20 for IERC20;

    IERC20 private _token;
    address private _beneficiary0;
    address private _beneficiary1;
    address private _beneficiary2;
    uint256 private _beneficiary0Amount;
    uint256 private _beneficiary1Amount;
    uint256 private _beneficiary2Amount;
    uint256 private _releaseTime;

    constructor (IERC20 token, address beneficiary0, address beneficiary1, address beneficiary2, uint256 beneficiary0Amount, uint256 beneficiary1Amount, uint256 beneficiary2Amount, uint256 releaseTime) public {
        require(releaseTime > block.timestamp, "We don't have a Hot Tub Time Machine...");
        _token = token;
        _beneficiary0 = beneficiary0;
        _beneficiary1 = beneficiary1;
        _beneficiary2 = beneficiary2;
        _beneficiary0Amount = beneficiary0Amount;
        _beneficiary1Amount = beneficiary1Amount;
        _beneficiary2Amount = beneficiary2Amount;
        _releaseTime = releaseTime;
    }

    function token() public view returns (IERC20) {
        return _token;
    }

     
    function beneficiaries() public view returns (address Beneficiary0, address Beneficiary1, address Beneficiary2) {
        return(_beneficiary0, _beneficiary1, _beneficiary2);
    }
    
    function beneficiaryAmounts() public view returns (uint Beneficiary0Amount, uint Beneficiary1Amount, uint Beneficiary2Amount) {
        return(_beneficiary0Amount, _beneficiary1Amount, _beneficiary2Amount);
    }

    function releaseTime() public view returns (uint256) {
        return _releaseTime;
    }

    function release() public virtual onlyOwner {
        require(block.timestamp >= _releaseTime, "Calm Down there Speedracer... It isn't time yet.");
        _token.safeTransfer(_beneficiary0, _beneficiary0Amount);
        _token.safeTransfer(_beneficiary1, _beneficiary1Amount);
        _token.safeTransfer(_beneficiary2, _beneficiary2Amount);
    }
}
