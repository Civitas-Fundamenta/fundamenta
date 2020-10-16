// SPDX-License-Identifier: GPL-3.0

// Author: Matt Hooft
// https://github.com/Civitas-Fundamenta
// mhooft@fundamenta.network

// This is a token vesting contract that can add multiple beneficiaries.  It uses
// Unix timestamps to keep track of release times and only the beneficiary is 
// allowed to remove the tokens.  For emergency purposes the ability to change the 
// beneficiary address has been added as well as the ability for the contract owner 
// to recover Ether and ERC20 tokens that are mistakenly deposited to the conract.

pragma solidity ^0.7.3;

import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract Vesting is AccessControl {
    
    using SafeERC20 for IERC20;
    using SafeMath for uint256;
    
    //-----------RBAC--------------
    
    bytes32 private constant _ADMIN = keccak256("_ADMIN");
    
    //---------Interface-----------
    
    IERC20  private token;
    
    //------structs/mappings-------
    
    /**
     * @dev struct to keep track of beneficiaries
     * release times and balances.
     */
    
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

    //------constructor--------------

    constructor() {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }
    
    //------contract functions-------
    
    function setToken(IERC20 _token) public {
        require(hasRole(_ADMIN, msg.sender));
        token = _token;
    }
    
    /**
     * @dev adds beneficiary
     */
    
    function addbeneficary(address _beneficiary, uint _ReleaseTime, uint _LockedAmount) public {
         Beneficiaries storage b = beneficiary[_beneficiary];
         require(hasRole(_ADMIN, msg.sender));
         require(b.LockedAmount == 0);
         beneficiary[_beneficiary] = Beneficiaries(_beneficiary, _ReleaseTime, _LockedAmount);
         emit beneficiaryAdded (_beneficiary, _ReleaseTime, _LockedAmount, block.number);
    }
    
    /**
     * @dev returns if msg.sender is a beneficiary and if so 
     * returns beneficiary information
     */
    
    /**
     * @dev check if a user is a beneficiary and if so 
     * return beneficiary information
     */
    
    function isBeneficiary(address _beneficiaryAddress) external view returns (address _beneficiary, uint _ReleaseTime, uint _LockedAmount, uint _timeRemainingInSeconds)  {
        Beneficiaries memory b = beneficiary[_beneficiaryAddress];
         if(b.ReleaseTime > block.timestamp) {
            uint timeRemaining = b.ReleaseTime.sub(block.timestamp);
            return (b.beneficiary, b.ReleaseTime, b.LockedAmount, timeRemaining);
        } else if(b.ReleaseTime < block.timestamp) {
            uint timeRemaining = 0;
            return (b.beneficiary, b.ReleaseTime, b.LockedAmount, timeRemaining);
    
        }    
    }
    
    /**
     * @dev allows Beneficiaries to wthdraw vested tokens
     * if the release time is satisfied.
     */
    
    function withdrawVesting() external {
        Beneficiaries storage b = beneficiary[msg.sender];
        if (b.LockedAmount == 0)
        revert ("You are not a beneficiary or do not have any tokens vesting");
        else if(b.ReleaseTime > block.timestamp) 
        revert("It isn't time yet speedracer...");
        else if (b.ReleaseTime < block.timestamp)
        require(contractBalance() >= b.LockedAmount, "Not enough tokens in contract balance to cover withdrawl");
        token.safeTransfer(b.beneficiary, b.LockedAmount);
        emit beneficiaryWithdraw (b.beneficiary, b.LockedAmount, block.number);
        beneficiary[msg.sender] = Beneficiaries(address(0), 0, 0);
    }
    
    /**
     * @dev flexibility is nice so we will allow the ability
     * for beneficiaries to increase vesting time. You cannot
     * decrease however.
     */
    
    function increaseReleaseTime(uint _newReleaseTime, address _beneficiary) public {
        require(hasRole(_ADMIN, msg.sender));
        Beneficiaries storage b = beneficiary[_beneficiary];
        require(_newReleaseTime > block.timestamp && _newReleaseTime > b.ReleaseTime, "Release time can only be increased");
        b.ReleaseTime = _newReleaseTime;
        emit releaseTimeIncreased (_beneficiary, _newReleaseTime, block.number);
    }
    
    /**
     * @dev emergency function to change beneficiary addresses if 
     * they pull a bozo and lose or compromise keys before the release
     * time has been reached.
     */

    function changeBeneficiary(address _newBeneficiary, address _currentBeneficiary) public {
        require(hasRole(_ADMIN, msg.sender));
        Beneficiaries storage b = beneficiary[_currentBeneficiary];
        b.beneficiary = _newBeneficiary;
        emit beneficiaryChanged (_currentBeneficiary, _newBeneficiary, block.number);
    }
    
    /**
     * @dev returns contract balance
     */
    
    function contractBalance() public view returns (uint _balance) {
        return IERC20(token).balanceOf(address(this));
    }
    
    //-----------Rescue--------------
    
    /**
     * @dev emergency functions to transfer Ether and ERC20 tokens that 
     * are mistakenly sent to the contract.
     */

    function mistakenERC20DepositRescue(address _ERC20, address _pebcak, uint _ERC20Amount) public {
        require(hasRole(_ADMIN, msg.sender));
        IERC20(_ERC20).safeTransfer(_pebcak, _ERC20Amount);
        emit tokensRescued (_pebcak, _ERC20, _ERC20Amount, block.number);
    }

    function mistakenDepositRescue(address payable _pebcak, uint _etherAmount) public {
        require(hasRole(_ADMIN, msg.sender));
        _pebcak.transfer(_etherAmount);
    }

}