// SPDX-License-Identifier: MIT

// Author: Matt Hooft 
// https://github.com/Civitas-Fundamenta
// mhooft@fundamenta.network

// A simple token Staking Contract that uses a configurable `stakeCap` to limit inflation.
// Employs the use of Role Based Access Control (RBAC) so allow outside accounts and contracts
// to interact with it securely allowing for future extensibility.

pragma solidity ^0.7.0;

import "./Ownable.sol";
import "./AccessControl.sol";
import "./SafeMath.sol";
import "./TokenInterface.sol";
import "./IERC20.sol";
import "./SafeERC20.sol";


contract Staking is Ownable, AccessControl {

    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    address public token;
    
    /**
     * @dev Smart Contract uses Role Based Access Control to 
     * 
     * alllow for secure access as well as enabling the ability 
     *
     * for other contracts such as oracles to interact with it.
     */

    //-------RBAC---------------------------

    bytes32 public constant _STAKING = keccak256("_STAKING");

    //-------Staking Vars-------------------
    
    uint256 public stakeCalc;
    uint256 public stakeCap;
    uint256 public rewardsWindow;
    uint256 public stakeLockMultiplier;
    bool public stakingOff;
    bool public paused;
    bool public emergencyWDoff;
    
    //--------Staking mapping/Arrays----------

    address[] internal stakeholders;
    mapping(address => uint256) internal stakes;
    mapping(address => uint256) internal rewards;
    mapping(address => uint256) internal lastWithdraw;
    
    //----------Events----------------------
    
    event stakeCreated(address _stakeholder, uint256 _stakes, uint256 _blockHeight);
    event stakeRemoved(address _stakeholder, uint256 _stakes, uint256 rewards, uint256 _blockHeight);
    event rewardsWithdrawn(address _stakeholder, uint256 _rewards, uint256 blockHeight);
    event tokensRescued (address _pebcak, address _ERC20, uint256 _ERC20Amount, uint256 _blockHeightRescued);

    //-------Constructor----------------------

    constructor(){
        stakingOff = true;
        emergencyWDoff = true;
        stakeCalc = 1000;
        stakeCap = 3e22;
        rewardsWindow = 6500;
        stakeLockMultiplier = 2;
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    //-------Set Token Address----------------
    
    function setAddress(address _token) public onlyOwner {
        token = _token;
    }
    
    //-------Modifiers--------------------------

    modifier pause() {
        require(!paused, "Contract is Paused");
        _;
    }

    modifier stakeToggle() {
        require(!stakingOff, "Staking is not currently active");
        _;
    }
    
    modifier emergency() {
        require(!emergencyWDoff, "Emergency Withdraw is not enabled");
        _;
    }

    //--------Staking Functions-------------------

    /**
     * @dev allows a user to create a staking positon. Users will
     * 
     * not be allowed to stake more than the `stakeCap` which is 
     *
     * a settable variable by Admins/Contrcats with the `_STAKING` 
     * 
     * Role.
     */

    function createStake(uint256 _stake) public pause stakeToggle {
        if(stakes[msg.sender] == 0) addStakeholder(msg.sender);
        stakes[msg.sender] = stakes[msg.sender].add(_stake);
        if(stakes[msg.sender] > stakeCap) {
            revert("Can't Stake More than allowed moneybags");
        }
        TokenInterface t = TokenInterface(token);
        t.burnFrom(msg.sender, _stake);
        lastWithdraw[msg.sender] = block.number;
        emit stakeCreated(msg.sender, _stake, block.number);
    }
    
    /**
     * @dev removes a users staked positon if the required lock
     * 
     * window is satisfied. Also pays out any `_rewardsAccrued` to
     *
     * the user if any rewards are pending.
     */
    
    function removeStake(uint256 _stake) public pause {
        if(stakes[msg.sender] == 0 && _stake != 0 ) 
        revert("You don't have any tokens staked");
        uint256 unlockWindow = rewardsWindow.mul(stakeLockMultiplier);
        require(block.number >= lastWithdraw[msg.sender].add(unlockWindow), "FMTA has not been staked for long enough");
        TokenInterface t = TokenInterface(token);
        uint256 _rewardsAccrued;
        uint256 multiplier;
        multiplier = block.number.sub(lastWithdraw[msg.sender]).div(rewardsWindow);
        _rewardsAccrued = calculateReward(msg.sender).mul(multiplier);
        t.mintTo(msg.sender, _rewardsAccrued);
        stakes[msg.sender] = stakes[msg.sender].sub(_stake);
        if(stakes[msg.sender] == 0) {
            removeStakeholder(msg.sender);
            t.mintTo(msg.sender, _stake);
            emit stakeRemoved(msg.sender, _stake, _rewardsAccrued, block.number);
            
        }
        
    }
    
    /**
     * @dev returns the amount of rewards a user as accrued.
     */
    
    function rewardsAccrued() public view returns (uint256) {
        uint256 _rewardsAccrued;
        uint256 multiplier;
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
        uint256 reward;
        uint256 multiplier;
        multiplier = block.number.sub(lastWithdraw[msg.sender]).div(rewardsWindow);
        reward = calculateReward(msg.sender).mul(multiplier);
        rewards[msg.sender] = rewards[msg.sender].add(reward);
        TokenInterface t = TokenInterface(token);
        if(lastWithdraw[msg.sender] == 0) {
           revert("You cannot withdraw if you hve never staked");
        } else if (lastWithdraw[msg.sender] != 0){
            require(block.number > lastWithdraw[msg.sender] + rewardsWindow, "It hasn't been enough time since your last withdrawl");
            t.mintTo(msg.sender, reward);
            lastWithdraw[msg.sender] = block.number;
            emit rewardsWithdrawn(msg.sender, reward, block.number);
        }
    }
    
    /**
     * @dev allows user to withrdraw any pending rewards and
     * 
     * staking position if `emergencyWDoff` is false enabling 
     * 
     * emergency withdraw situtaions when staking is off and 
     * 
     * the contract is paused.  This will likely never be used.
     */
    
    function emergencyWithdrawRewardAndStakes(uint256 _stake) public emergency {
        TokenInterface t = TokenInterface(token);
        uint256 _rewardsAccrued;
        uint256 multiplier;
        multiplier = block.number.sub(lastWithdraw[msg.sender]).div(rewardsWindow);
        _rewardsAccrued = calculateReward(msg.sender).mul(multiplier);
        t.mintTo(msg.sender, _rewardsAccrued);
        stakes[msg.sender] = stakes[msg.sender].sub(_stake);
        if(stakes[msg.sender] == 0) {
            removeStakeholder(msg.sender);
            t.mintTo(msg.sender, _stake);
            
        }
    }
    
    /**
     * @dev returns a users `lastWithdraw` which is the last block
     * 
     * height that the user last withdrew rewards.
     */
    
    function lastWdHeight() public view returns (uint256) {
        return lastWithdraw[msg.sender];
    }
    
    /**
     * @dev returns to the user the amount of blocks that they must
     * 
     * have their stake locked before they are able to unstake their
     * 
     * positon.
     */
    
    function stakeUnlockWindow() external view returns (uint256) {
        uint256 unlockWindow = rewardsWindow.mul(stakeLockMultiplier);
        uint256 stakeWindow = lastWithdraw[msg.sender].add(unlockWindow);
        return stakeWindow;
    }
    
    /**
     * @dev allows admin with the `_STAKING` role to set the 
     * 
     * `stakeMultiplier` which is used in the calculation that
     *
     * determines how long a user must have a staked positon 
     * 
     * before they are able to unstake said positon.
     */
    
    function setStakeMultiplier(uint256 _newMultiplier) public pause stakeToggle {
        require(hasRole(_STAKING, msg.sender));
        stakeLockMultiplier = _newMultiplier;
    }
    
    /**
     * @dev returns a users staked position.
     */
    
    function stakeOf (address _stakeholder) public view returns(uint256) {
        return stakes[_stakeholder];
    }
    
    /**
     * @dev returns the total amount of FMTA that has been 
     * 
     * placed in staking postions by users.
     */
    
    function totalStakes() public view returns(uint256) {
        uint256 _totalStakes = 0;
        for (uint256 s = 0; s < stakeholders.length; s += 1) {
            _totalStakes = _totalStakes.add(stakes[stakeholders[s]]);
        }
        
        return _totalStakes;
    }
    
    /**
     * @dev returns if an account is a stakeholder and holds
     * 
     * a staked position.
     */

    function isStakeholder(address _address) public view returns(bool, uint256) {
        for (uint256 s = 0; s < stakeholders.length; s += 1) {
            if (_address == stakeholders[s]) return (true, s);
        }
        
        return (false, 0);
    }
    
    /**
     * @dev internal function that adds accounts as stakeholders.
     */
    
    function addStakeholder(address _stakeholder) internal pause stakeToggle {
        (bool _isStakeholder, ) = isStakeholder(_stakeholder);
        if(!_isStakeholder) stakeholders.push(_stakeholder);
    }
    
    /**
     * @dev internal function that removes accounts as stakeholders.
     */
    
    function removeStakeholder(address _stakeholder) internal {
        (bool _isStakeholder, uint256 s) = isStakeholder(_stakeholder);
        if(_isStakeholder){
            stakeholders[s] = stakeholders[stakeholders.length - 1];
            stakeholders.pop();
        }
    }
    
    /**
     * @dev returns an accounts total rewards paid over the
     * 
     * Staking Contracts lifetime.
     */
    
    function rewardOf(address _stakeholder) external view returns(uint256) {
        return rewards[_stakeholder];
    }
    
    /**
     * @dev returns the amount of total rewards paid to all
     * 
     * accounts over the Staking Contracts lifetime.
     */
    
    function totalRewardsPaid() external view returns(uint256) {
        uint256 _totalRewards = 0;
        for (uint256 s = 0; s < stakeholders.length; s += 1){
            _totalRewards = _totalRewards.add(rewards[stakeholders[s]]);
        }
        
        return _totalRewards;
    }
    
     /**
     * @dev allows admin with the `_STAKING` role to set the
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
     * @dev allows admin with the `_STAKING` role to set the
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
     * @dev allows admin with the `_STAKING` role to set the
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
     * @dev allows admin with the `_STAKING` role to set the
     * 
     * Staking Contracts `rewardsWindow` which determines how
     * 
     * long a user must wait before they can with draw in the 
     * 
     * form of a number of blocks that must pass since the users
     * 
     * `lastWithdraw`.
     */
    
    function setRewardsWindow(uint256 _newWindow) external pause stakeToggle {
        require(hasRole(_STAKING, msg.sender));
        rewardsWindow = _newWindow;
    }
    
    /**
     * @dev simple function help track and calculate the rewards
     * 
     * accrued between rewards windows. it uses `stakeCalc` which
     * 
     * is settable by admins with the `_STAKING` role.
     */
    
    function calculateReward(address _stakeholder) public view returns(uint256) {
        return stakes[_stakeholder] / stakeCalc;
    }
    
    /**
     * @dev turns on the emergencyWD function which is used for 
     * 
     * when the staking contract is paused or stopped for some
     * 
     * unforseeable reason and we still need to let users withdraw.
     */
    
    function setEmergencyWDoff(bool _emergencyWD) external onlyOwner {
        emergencyWDoff = _emergencyWD;
    }
    

    //----------Pause----------------------

    /**
     * @dev pauses the Smart Contract.
     */

    function setPaused(bool _paused) external onlyOwner {
        paused = _paused;
    }
    
    //----Emergency PEBCAK Functions-------
    
    function mistakenERC20DepositRescue(address _ERC20, address _pebcak, uint256 _ERC20Amount) public onlyOwner {
        IERC20(_ERC20).safeTransfer(_pebcak, _ERC20Amount);
        emit tokensRescued (_pebcak, _ERC20, _ERC20Amount, block.number);
    }

    function mistakenDepositRescue(address payable _pebcak, uint256 _etherAmount) public onlyOwner {
        _pebcak.transfer(_etherAmount);
    }

}
