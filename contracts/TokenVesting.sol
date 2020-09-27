// SPDX-License-Identifier: MIT

pragma solidity ^0.7.0;

import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

contract Vesting is Ownable {
    
    using SafeERC20 for IERC20;
    using SafeMath for uint256;
    
    IERC20  private token;
    
    struct Beneficiaries {
        address beneficiary;
        uint ReleaseTime;
        uint LockedAmount;
    }
    
    mapping (address => Beneficiaries) beneficiary;
    
    //-----------Events--------------
    
    event beneficiaryAdded (address _beneficiary, uint _ReleaseTime, uint _LockedAmount, uint _blockHeight);
    
    event beneficiaryWithdraw (address _beneficiary, uint _WithdrawnAmount, uint _blockHeight);
    
    event releaseTimeIncreased (address _beneficiary, uint _newReleaseTime, uint _blockHeight);
    
    event beneficiaryChanged (address _currentBeneficiary, address _newBeneficiary, uint _blockHeight);

    event tokensRescued (address _pebcak, address _tokenContract, uint _amountRescued, uint _blockHeight);
    
    function setToken(IERC20 _token) public onlyOwner {
        token = _token;
    }
    
    function addbeneficary(address _beneficiary, uint _ReleaseTime, uint _LockedAmount) public onlyOwner {
         beneficiary[_beneficiary] = Beneficiaries(_beneficiary, _ReleaseTime, _LockedAmount);
         
         emit beneficiaryAdded (_beneficiary, _ReleaseTime, _LockedAmount, block.number);
    }
    
    function amIBeneficiary() external view returns (address _beneficiary, uint _ReleaseTime, uint _LockedAmount, uint _timeRemainingInSeconds)  {
        Beneficiaries storage b = beneficiary[msg.sender];
        if(b.ReleaseTime > block.timestamp) {
        uint timeRemaining = b.ReleaseTime.sub(block.timestamp);
        return (b.beneficiary, b.ReleaseTime, b.LockedAmount, timeRemaining);
        } else if(b.ReleaseTime < block.timestamp) {
        }uint timeRemaining = 0;
        return (b.beneficiary, b.ReleaseTime, b.LockedAmount, timeRemaining);
    }
    
    function isBeneficiary(address _beneficiaryAddress) external view returns (address _beneficiary, uint _ReleaseTime, uint _LockedAmount, uint _timeRemainingInSeconds)  {
        Beneficiaries storage b = beneficiary[_beneficiaryAddress];
         if(b.ReleaseTime > block.timestamp) {
        uint timeRemaining = b.ReleaseTime.sub(block.timestamp);
        return (b.beneficiary, b.ReleaseTime, b.LockedAmount, timeRemaining);
        } else if(b.ReleaseTime < block.timestamp) {
        }uint timeRemaining = 0;
        return (b.beneficiary, b.ReleaseTime, b.LockedAmount, timeRemaining);
    }
    
    function withdrawVesting() external {
        Beneficiaries storage b = beneficiary[msg.sender];
        uint256 cb = contractBalance();
        if (b.LockedAmount == 0)
        revert ("You are not a beneficiary or do not have any tokens vesting");
        else if(b.ReleaseTime > block.timestamp) 
        revert("It isn't time yet speedracer...");
        else if (b.ReleaseTime < block.timestamp)
        require(cb >= b.LockedAmount, "Not enough tokens in contract balance to cover withdrawl");
        token.safeTransfer(b.beneficiary, b.LockedAmount);
        emit beneficiaryWithdraw (b.beneficiary, b.LockedAmount, block.number);
        beneficiary[msg.sender] = Beneficiaries(address(0), 0, 0);
    }
    
    function increaseReleaseTime(uint _newReleaseTime, address _beneficiary) public onlyOwner {
        Beneficiaries storage b = beneficiary[_beneficiary];
        require(_newReleaseTime > block.timestamp, "Release time can only be increased");
        b.ReleaseTime = _newReleaseTime;
        emit releaseTimeIncreased (_beneficiary, _newReleaseTime, block.number);
    }

    function changeBeneficiary(address _newBeneficiary, address _currentBeneficiary) public onlyOwner {
        Beneficiaries storage b = beneficiary[_currentBeneficiary];
        b.beneficiary = _newBeneficiary;
        emit beneficiaryChanged (_currentBeneficiary, _newBeneficiary, block.number);
    }
    
    function contractBalance() public view returns (uint _balance) {
        address ca = address(this);
        return IERC20(token).balanceOf(ca);
    }

    function mistakenERC20DepositRescue(address _ERC20, address _pebcak, uint256 _ERC20Amount) public onlyOwner {
        IERC20(_ERC20).safeTransfer(_pebcak, _ERC20Amount);
        emit tokensRescued (_pebcak, _ERC20, _ERC20Amount, block.number);
    }

    function mistakenDepositRescue(address payable _pebcak, uint256 _etherAmount) public onlyOwner {
        _pebcak.transfer(_etherAmount);
    }

}