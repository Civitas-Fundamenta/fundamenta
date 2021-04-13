// SPDX-License-Identifier: GPL-3.0

// Author: Matt Hooft 
// https://github.com/Civitas-Fundamenta
// mhooft@fundamenta.network

// A simple token Staking Contract that uses a configurable `stakeCap` to limit inflation.
// Employs the use of Role Based Access Control (RBAC) so allow outside accounts and contracts
// to interact with it securely allowing for future extensibility.

pragma solidity ^0.8.0;

import "./TokenInterface.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/AccessControl.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/IERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/utils/SafeERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/math/SafeMath.sol";

contract Staking is AccessControl {

    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    
    TokenInterface private fundamenta;  
    
    /**
     * Smart Contract uses Role Based Access Control to 
     * 
     * alllow for secure access as well as enabling the ability 
     *
     * for other contracts such as oracles to interact with ifundamenta.
     */

    //-------RBAC---------------------------

    bytes32 public constant _STAKING = keccak256("_STAKING");
    bytes32 public constant _RESCUE = keccak256("_RESCUE");
    bytes32 public constant _ADMIN = keccak256("_ADMIN");

    //-------Staking Vars-------------------
    
    uint public stakeCalc;
    uint public stakeCap;
    uint public rewardsWindow;
    uint public stakeLockMultiplier;
    bool public stakingOff;
    bool public paused;
    bool public emergencyWDoff;
    
    //--------Staking mapping/Arrays----------

    address[] internal stakeholders;
    mapping(address => uint) internal stakes;
    mapping(address => uint) internal rewards;
    mapping(address => uint) internal lastWithdraw;
    
    //----------Events----------------------
    
    event StakeCreated(address _stakeholder, uint _stakes, uint _blockHeight);
    event StakeRemoved(address _stakeholder, uint _stakes, uint rewards, uint _blockHeight);
    event RewardsWithdrawn(address _stakeholder, uint _rewards, uint blockHeight);
    event TokensRescued (address _pebcak, address _ERC20, uint _ERC20Amount, uint _blockHeightRescued);
    event ETHRescued (address _pebcak, uint _ETHAmount, uint _blockHeightRescued);

    //-------Constructor----------------------

    constructor(){
        stakingOff = true;
        emergencyWDoff = true;
        stakeCalc = 500;
        stakeCap = 3e22;
        rewardsWindow = 6500;
        stakeLockMultiplier = 2;
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    //-------Set Token Address----------------
    
    function setAddress(TokenInterface _token) public {
        require(hasRole(_ADMIN, msg.sender));
        fundamenta = _token;
    }
    
    //-------Modifiers--------------------------

    modifier pause() {
        require(!paused, "TokenStaking: Contract is Paused");
        _;
    }

    modifier stakeToggle() {
        require(!stakingOff, "TokenStaking: Staking is not currently active");
        _;
    }
    
    modifier emergency() {
        require(!emergencyWDoff, "TokenStaking: Emergency Withdraw is not enabled");
        _;
    }

    //--------Staking Functions-------------------

    /**
     * allows a user to create a staking positon. Users will
     * 
     * not be allowed to stake more than the `stakeCap` which is 
     *
     * a settable variable by Admins/Contrcats with the `_STAKING` 
     * 
     * Role.
     */

    function createStake(uint _stake) public pause stakeToggle {
        rewards[msg.sender] = rewards[msg.sender].add(rewardsAccrued());
        if(stakes[msg.sender] == 0) addStakeholder(msg.sender);
        stakes[msg.sender] = stakes[msg.sender].add(_stake);
        fundamenta.mintTo(msg.sender, rewardsAccrued());
        fundamenta.burnFrom(msg.sender, _stake);
        require(stakes[msg.sender] <= stakeCap, "TokenStaking: Can't Stake More than allowed moneybags"); 
        lastWithdraw[msg.sender] = block.number;
        emit StakeCreated(msg.sender, _stake, block.number);
    }
    
    /**
     * removes a users staked positon if the required lock
     * 
     * window is satisfied. Also pays out any `_rewardsAccrued` to
     *
     * the user if any rewards are pending.
     */
    
    function removeStake(uint _stake) public pause {
        uint unlockWindow = rewardsWindow.mul(stakeLockMultiplier);
        require(block.number >= lastWithdraw[msg.sender].add(unlockWindow), "TokenStaking: FMTA has not been staked for long enough");
        rewards[msg.sender] = rewards[msg.sender].add(rewardsAccrued());
        if(stakes[msg.sender] == 0 && _stake != 0 ) {
            revert("TokenStaking: You don't have any tokens staked");
        }else if (stakes[msg.sender] != 0 && _stake != 0) {
            fundamenta.mintTo(msg.sender, rewardsAccrued());
            fundamenta.mintTo(msg.sender, _stake);
            stakes[msg.sender] = stakes[msg.sender].sub(_stake);
            lastWithdraw[msg.sender] = block.number;
        }else if (stakes[msg.sender] == 0) {
            fundamenta.mintTo(msg.sender, rewardsAccrued());
            fundamenta.mintTo(msg.sender, _stake);
            stakes[msg.sender] = stakes[msg.sender].sub(_stake);
            removeStakeholder(msg.sender);
            lastWithdraw[msg.sender] = block.number;
        }
        emit StakeRemoved(msg.sender, _stake, rewardsAccrued(), block.number);
        
    }
    
    /**
     * returns the amount of rewards a user as accrued.
     */
    
    function rewardsAccrued() public view returns (uint) {
        uint _rewardsAccrued;
        uint multiplier;
        multiplier = block.number.sub(lastWithdraw[msg.sender]).div(rewardsWindow);
        _rewardsAccrued = calculateReward(msg.sender).mul(multiplier);
        return _rewardsAccrued;
        
    }
    
    /**
     * @dev allows user to withrdraw any pending rewards as
     * 
     * long as the `rewardsWindow` is satisfied.
     */
     
    function withdrawReward() public pause stakeToggle {
        rewards[msg.sender] = rewards[msg.sender].add(rewardsAccrued());
        if(lastWithdraw[msg.sender] == 0) {
           revert("TokenStaking: You cannot withdraw if you hve never staked");
        } else if (lastWithdraw[msg.sender] != 0){
            require(block.number > lastWithdraw[msg.sender].add(rewardsWindow), "TokenStaking: It hasn't been enough time since your last withdrawl");
            fundamenta.mintTo(msg.sender, rewardsAccrued());
            lastWithdraw[msg.sender] = block.number;
            emit RewardsWithdrawn(msg.sender, rewardsAccrued(), block.number);
        }
    }
    
    
    function compoundRewards() public pause stakeToggle {
        rewards[msg.sender] = rewards[msg.sender].add(rewardsAccrued());
        if(stakes[msg.sender] == 0) addStakeholder(msg.sender);
        stakes[msg.sender] = stakes[msg.sender].add(rewardsAccrued());
        require(stakes[msg.sender] <= stakeCap, "TokenStaking: Can't Stake More than allowed moneybags"); 
        lastWithdraw[msg.sender] = block.number;
        emit StakeCreated(msg.sender, rewardsAccrued(), block.number);
    }
    
    /**
     * allows user to withrdraw any pending rewards and
     * 
     * staking position if `emergencyWDoff` is false enabling 
     * 
     * emergency withdraw situtaions when staking is off and 
     * 
     * the contract is paused.  This will likely never be used.
     */
    
    function emergencyWithdrawRewardAndStakes() public emergency {
        rewards[msg.sender] = rewards[msg.sender].add(rewardsAccrued());
        fundamenta.mintTo(msg.sender, rewardsAccrued());
        fundamenta.mintTo(msg.sender, stakes[msg.sender]);
        stakes[msg.sender] = stakes[msg.sender].sub(stakes[msg.sender]);
        removeStakeholder(msg.sender);
    }
    
    /**
     * returns a users `lastWithdraw` which is the last block
     * 
     * height that the user last withdrew rewards.
     */
    
    function lastWdHeight() public view returns (uint) {
        return lastWithdraw[msg.sender];
    }
    
    /**
     * returns to the user the amount of blocks that they must
     * 
     * have their stake locked before they are able to unstake their
     * 
     * positon.
     */
    
    function stakeUnlockWindow() external view returns (uint) {
        uint unlockWindow = rewardsWindow.mul(stakeLockMultiplier);
        uint stakeWindow = lastWithdraw[msg.sender].add(unlockWindow);
        return stakeWindow;
    }
    
    /**
     * allows admin with the `_STAKING` role to set the 
     * 
     * `stakeMultiplier` which is used in the calculation that
     *
     * determines how long a user must have a staked positon 
     * 
     * before they are able to unstake said positon.
     */
    
    function setStakeMultiplier(uint _newMultiplier) public pause stakeToggle {
        require(hasRole(_STAKING, msg.sender));
        stakeLockMultiplier = _newMultiplier;
    }
    
    /**
     * returns a users staked position.
     */
    
    function stakeOf (address _stakeholder) public view returns(uint) {
        return stakes[_stakeholder];
    }
    
    /**
     * returns the total amount of FMTA that has been 
     * 
     * placed in staking postions by users.
     */
    
    function totalStakes() public view returns(uint) {
        uint _totalStakes = 0;
        for (uint s = 0; s < stakeholders.length; s += 1) {
            _totalStakes = _totalStakes.add(stakes[stakeholders[s]]);
        }
        
        return _totalStakes;
    }
    
    /**
     * returns if an account is a stakeholder and holds
     * 
     * a staked position.
     */

    function isStakeholder(address _address) public view returns(bool, uint) {
        for (uint s = 0; s < stakeholders.length; s += 1) {
            if (_address == stakeholders[s]) return (true, s);
        }
        
        return (false, 0);
    }
    
    /**
     * internal function that adds accounts as stakeholders.
     */
    
    function addStakeholder(address _stakeholder) internal pause stakeToggle {
        (bool _isStakeholder, ) = isStakeholder(_stakeholder);
        if(!_isStakeholder) stakeholders.push(_stakeholder);
    }
    
    /**
     * internal function that removes accounts as stakeholders.
     */
    
    function removeStakeholder(address _stakeholder) internal {
        (bool _isStakeholder, uint s) = isStakeholder(_stakeholder);
        if(_isStakeholder){
            stakeholders[s] = stakeholders[stakeholders.length - 1];
            stakeholders.pop();
        }
    }
    
    /**
     * returns an accounts total rewards paid over the
     * 
     * Staking Contracts lifetime.
     */
    
    function totalRewardsOf(address _stakeholder) external view returns(uint) {
        return rewards[_stakeholder];
    }
    
    /**
     * returns the amount of total rewards paid to all
     * 
     * accounts over the Staking Contracts lifetime.
     */
    
    function totalRewardsPaid() external view returns(uint) {
        uint _totalRewards = 0;
        for (uint s = 0; s < stakeholders.length; s += 1){
            _totalRewards = _totalRewards.add(rewards[stakeholders[s]]);
        }
        
        return _totalRewards;
    }
    
     /**
     * allows admin with the `_STAKING` role to set the
     * 
     * Staking Contracts `stakeCalc` which is the divisor used
     * 
     * in `calculateReward` to determine the reward during each 
     * 
     * `rewardsWindow`.
     */
    
    function setStakeCalc(uint _stakeCalc) external pause stakeToggle {
        require(hasRole(_STAKING, msg.sender));
        stakeCalc = _stakeCalc;
    }
    
     /**
     * allows admin with the `_STAKING` role to set the
     * 
     * Staking Contracts `stakeCap` which determines how many
     * 
     * tokens total can be staked per account.
     */
    
    function setStakeCap(uint _stakeCap) external pause stakeToggle {
        require(hasRole(_STAKING, msg.sender));
        stakeCap = _stakeCap;
    }
    
     /**
     * allows admin with the `_STAKING` role to set the
     * 
     * Staking Contracts `stakeOff` bool to true ot false 
     * 
     * effecively turning staking on or off. The only function 
     * 
     * that is not effected is removng stake 
     */
    
    function stakeOff(bool _stakingOff) public {
        require(hasRole(_STAKING, msg.sender));
        stakingOff = _stakingOff;
    }
    
    /**
     * allows admin with the `_STAKING` role to set the
     * 
     * Staking Contracts `rewardsWindow` which determines how
     * 
     * long a user must wait before they can with draw in the 
     * 
     * form of a number of blocks that must pass since the users
     * 
     * `lastWithdraw`.
     */
    
    function setRewardsWindow(uint _newWindow) external pause stakeToggle {
        require(hasRole(_STAKING, msg.sender));
        rewardsWindow = _newWindow;
    }
    
    /**
     * simple function help track and calculate the rewards
     * 
     * accrued between rewards windows. it uses `stakeCalc` which
     * 
     * is settable by admins with the `_STAKING` role.
     */
    
    function calculateReward(address _stakeholder) public view returns(uint) {
        return stakes[_stakeholder] / stakeCalc;
    }
    
    /**
     * turns on the emergencyWD function which is used for 
     * 
     * when the staking contract is paused or stopped for some
     * 
     * unforseeable reason and we still need to let users withdraw.
     */
    
    function setEmergencyWDoff(bool _emergencyWD) external {
        require(hasRole(_ADMIN, msg.sender));
        emergencyWDoff = _emergencyWD;
    }
    

    //----------Pause----------------------

    /**
     * pauses the Smart Contract.
     */

    function setPaused(bool _paused) external {
        require(hasRole(_ADMIN, msg.sender));
        paused = _paused;
    }
    
    //----Emergency PEBCAK Functions-------
    
    function mistakenERC20DepositRescue(address _ERC20, address _pebcak, uint _ERC20Amount) public {
        require(hasRole(_RESCUE, msg.sender),"TokenStaking: Message Sender must be _RESCUE");
        IERC20(_ERC20).safeTransfer(_pebcak, _ERC20Amount);
        emit TokensRescued (_pebcak, _ERC20, _ERC20Amount, block.number);
    }

    function mistakenDepositRescue(address payable _pebcak, uint _etherAmount) public {
        require(hasRole(_RESCUE, msg.sender),"TokenStaking: Message Sender must be _RESCUE");
        _pebcak.transfer(_etherAmount);
        emit ETHRescued (_pebcak, _etherAmount, block.number);
    }

}
