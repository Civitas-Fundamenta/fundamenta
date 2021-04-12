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

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/utils/SafeERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/math/SafeMath.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/AccessControl.sol";

contract Vesting is AccessControl {
    
    using SafeERC20 for IERC20;
    using SafeMath for uint256;
    
    //-----------RBAC--------------
    
    bytes32 public constant _ADMIN = keccak256("_ADMIN");
    bytes32 public constant _MOVE = keccak256("_MOVE");
    bytes32 public constant _RESCUE = keccak256("_RESCUE");
    
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
        uint releasedPerMonth;
        uint totalAmountReleased;
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
    
    function addbeneficary(address _beneficiary, uint _ReleaseTime, uint _LockedAmount, uint _releasedPerMonth) public {
         Beneficiaries storage b = beneficiary[_beneficiary];
         require(hasRole(_ADMIN, msg.sender));
         require(b.LockedAmount == 0);
         beneficiary[_beneficiary] = Beneficiaries(_beneficiary, _ReleaseTime, _LockedAmount, _releasedPerMonth, 0);
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
     * if the release time is satisfied.  2,592,000
     */
    
    function withdrawVesting() external {
        Beneficiaries storage b = beneficiary[msg.sender];
        if (b.LockedAmount == 0) {
        revert ("You are not a beneficiary or do not have any tokens vesting");
        } else if(b.ReleaseTime > block.timestamp) { 
        revert("It isn't time yet speedracer...");
        } else if (b.ReleaseTime < block.timestamp && b.releasedPerMonth <= b.LockedAmount) {
        token.safeTransfer(b.beneficiary, b.releasedPerMonth);
        emit beneficiaryWithdraw (b.beneficiary, b.releasedPerMonth, block.number);
        }else if (b.ReleaseTime < block.timestamp && b.LockedAmount < b.releasedPerMonth) {
        token.safeTransfer(b.beneficiary, b.LockedAmount);
        emit beneficiaryWithdraw (b.beneficiary, b.LockedAmount, block.number);
        }
        beneficiary[msg.sender] = Beneficiaries(b.beneficiary, block.timestamp.add(2592000), b.LockedAmount.sub(b.releasedPerMonth), b.releasedPerMonth, b.totalAmountReleased.add(b.releasedPerMonth));
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
        require(hasRole(_MOVE, msg.sender));
        IERC20(_ERC20).safeTransfer(_pebcak, _ERC20Amount);
        emit tokensRescued (_pebcak, _ERC20, _ERC20Amount, block.number);
    }

    function mistakenDepositRescue(address payable _pebcak, uint _etherAmount) public {
        require(hasRole(_RESCUE, msg.sender));
        _pebcak.transfer(_etherAmount);
    }

}