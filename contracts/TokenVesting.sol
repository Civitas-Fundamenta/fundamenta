// SPDX-License-Identifier: GPL-3.0

// Author: Matt Hooft
// https://github.com/Civitas-Fundamenta
// mhooft@fundamenta.network

// This is a token vesting contract that can add multiple beneficiaries.  It uses
// Unix timestamps to keep track of release times and only the beneficiary is 
// allowed to remove the tokens.  For emergency purposes the ability to change the 
// beneficiary address has been added as well as the ability for users with the  
// proper roles to recover Ether and ERC20 tokens that are mistakenly deposited 
// to the conract. The required roles will only be granted/used if/when needed
// with community consent. Until then no users will be granted the roles capable
// of token movement.  This is a comprimise to allow recovery of tokens/ether 
// that are sent to the contract by mistake.

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract Vesting is AccessControl {
    
    using SafeERC20 for IERC20;
    using SafeMath for uint256;
    
    //-----------RBAC--------------
    
    bytes32 public constant _ADMIN = keccak256("_ADMIN");
    bytes32 public constant _MOVE = keccak256("_MOVE");
    bytes32 public constant _RESCUE = keccak256("_RESCUE");
    
    //---------Interface-----------
    
    IERC20 private token;
    
    uint public periodLength;
    
    //------structs/mappings-------
    
    /**
     * struct to keep track of beneficiaries
     * release times and balances.
     */
    
    struct Beneficiaries {
        address beneficiary;
        uint releaseTime;
        uint lockedAmount;
        uint releasedPerPeriod;
        uint totalAmountReleased;
    }
    
    mapping (address => Beneficiaries) beneficiary;
    
    //-----------Events--------------
    
    event beneficiaryAdded (address _beneficiary, uint _releaseTime, uint _LockedAmount, uint _blockHeight);
    event beneficiaryWithdraw (address _beneficiary, uint _withdrawnAmount, uint _blockHeight, uint _nextUnlock);
    event beneficiaryChanged (address _currentBeneficiary, address _newBeneficiary, uint _blockHeight);
    event tokensRescued (address _pebcak, address _tokenContract, uint _amountRescued, uint _blockHeight);

    //------constructor--------------

    constructor() {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        periodLength = 2592000; // Set initial period length (30 Days in seconds)
    }
    
    //------contract functions-------
    
    function setToken(IERC20 _token) public {
        require(hasRole(_ADMIN, msg.sender));
        token = _token;
    }
    
    function setPeriodLength(uint _periodLength) public {
        require(hasRole(_ADMIN, msg.sender));
        periodLength = _periodLength;
    }
    
    /**
     * adds beneficiary
     */
    
    function addbeneficary(address _beneficiary, uint _ReleaseTime, uint _LockedAmount, uint _releasedPerPeriod) public {
         Beneficiaries storage b = beneficiary[_beneficiary];
         require(hasRole(_ADMIN, msg.sender));
         require(b.lockedAmount == 0);
         beneficiary[_beneficiary] = Beneficiaries(_beneficiary, _ReleaseTime, _LockedAmount, _releasedPerPeriod, 0);
         emit beneficiaryAdded (_beneficiary, _ReleaseTime, _LockedAmount, block.number);
    }
    
    /**
     * returns if msg.sender is a beneficiary and if so 
     * returns beneficiary information
     */
    
    /**
     * check if a user is a beneficiary and if so 
     * return beneficiary information
     */
    
    function isBeneficiary(address _beneficiaryAddress) external view returns (address _beneficiary, uint _ReleaseTime, uint _LockedAmount, uint _timeRemainingInSeconds)  {
        Beneficiaries memory b = beneficiary[_beneficiaryAddress];
         if(b.releaseTime > block.timestamp) {
            uint timeRemaining = b.releaseTime.sub(block.timestamp);
            return (b.beneficiary, b.releaseTime, b.lockedAmount, timeRemaining);
        } else if(b.releaseTime < block.timestamp) {
            uint timeRemaining = 0;
            return (b.beneficiary, b.releaseTime, b.lockedAmount, timeRemaining);
    
        }    
    }
    
    /**
     * allows Beneficiaries to wthdraw vested tokens
     * if the release time is satisfied.
     */
    
    function withdrawVesting() external {
        Beneficiaries storage b = beneficiary[msg.sender];
        if (b.lockedAmount == 0) {
        revert ("You are not a beneficiary or do not have any tokens vesting");
        } else if(b.releaseTime > block.timestamp) { 
        revert("It isn't time yet speedracer...");
        } else if (b.releaseTime < block.timestamp && b.releasedPerPeriod <= b.lockedAmount) {
        token.safeTransfer(b.beneficiary, b.releasedPerPeriod);
        emit beneficiaryWithdraw (b.beneficiary, b.releasedPerPeriod, block.number, block.timestamp.add(periodLength));
        beneficiary[msg.sender] = Beneficiaries(b.beneficiary, block.timestamp.add(periodLength), b.lockedAmount.sub(b.releasedPerPeriod), b.releasedPerPeriod, b.totalAmountReleased.add(b.releasedPerPeriod));
        }else if (b.releaseTime < block.timestamp && b.lockedAmount < b.releasedPerPeriod) {
        token.safeTransfer(b.beneficiary, b.lockedAmount);
        emit beneficiaryWithdraw (b.beneficiary, b.lockedAmount, block.number, block.timestamp.add(periodLength));
        beneficiary[msg.sender] = Beneficiaries(b.beneficiary, block.timestamp.add(periodLength), 0, b.releasedPerPeriod, b.totalAmountReleased.add(b.releasedPerPeriod));
        }
    }
    
    /**
     * emergency function to change beneficiary addresses if 
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
     * returns contract balance
     */
    
    function contractBalance() public view returns (uint _balance) {
        return IERC20(token).balanceOf(address(this));
    }
    
    //-----------Rescue--------------
    
    /**
     * emergency functions to transfer Ether and ERC20 tokens that 
     * are mistakenly sent to the contract.
     */

    function mistakenERC20DepositRescue(address _ERC20, address _pebcak, uint _ERC20Amount) public {
        require(hasRole(_MOVE, msg.sender));
        IERC20(_ERC20).safeTransfer(_pebcak, _ERC20Amount);
        emit tokensRescued (_pebcak, _ERC20, _ERC20Amount, block.number);
    }

    function mistakenDepositRescue(address payable _pebcak, uint _etherAmount) public {
        require(hasRole(_RESCUE, msg.sender));
        _pebcak.transfer(_etherAmount);
    }

}