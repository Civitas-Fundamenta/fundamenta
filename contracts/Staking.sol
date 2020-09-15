// SPDX-License-Identifier: MIT

pragma solidity ^0.7.0;

import "./Ownable.sol";
import "./AccessControl.sol";
import "./SafeMath.sol";
import "./TokenInterface.sol";


contract Staking is Ownable, AccessControl {

    using SafeMath for uint256;
    
    address public token;

    //-------RBAC---------------------------

    bytes32 public constant _STAKING = keccak256("_STAKING");

    //-------Staking Vars-------------------
    
    uint256 public stakeCalc;
    uint256 public stakeCap;
    uint256 public rewardsWindow;
    bool public stakingOff;
    bool public paused;
    
    //--------Staking mapping/Arrays----------

    address[] internal stakeholders;
    mapping(address => uint256) internal stakes;
    mapping(address => uint256) internal rewards;
    mapping(address => uint256) internal lastWithdraw;
    

    //-------Constructor----------------------

    constructor(){
        stakingOff = true;
        stakeCalc = 1000;
        stakeCap = 3e22;
        rewardsWindow = 6500;
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    //-------Set Token Address----------------
    
    function setAddress(address _token) public onlyOwner {
        token = _token;
    }
    
    //------------------------------------------

    modifier pause() {
        require(!paused, "Contract is Paused");
        _;
    }

    function stakeOff(bool _stakingOff) public {
        require(hasRole(_STAKING, msg.sender));
        stakingOff = _stakingOff;
    }

    modifier stakeToggle() {
        require(!stakingOff, "Staking is not currently active");
        _;
    }

    //--------------------------------------------

    function createStake(uint256 _stake) external pause stakeToggle {
        if(stakes[msg.sender] == 0) addStakeholder(msg.sender);
        stakes[msg.sender] = stakes[msg.sender].add(_stake);
        if(stakes[msg.sender] > stakeCap) {
            revert("Can't Stake More than allowed moneybags");
        }
        TokenInterface t = TokenInterface(token);
        t.burnFrom(msg.sender, _stake);
    }
    
    function removeStake(uint256 _stake) external pause {
        if(stakes[msg.sender] == 0 && _stake != 0 ) 
        revert("You don't have any tokens staked");
        stakes[msg.sender] = stakes[msg.sender].sub(_stake);
        if(stakes[msg.sender] == 0) {
            removeStakeholder(msg.sender);
            TokenInterface t = TokenInterface(token);
            t.mintTo(msg.sender, _stake);
        }
        
    }
    
    function withdrawReward() external pause stakeToggle {
        uint256 reward = calculateReward(msg.sender);
        rewards[msg.sender] = rewards[msg.sender].add(reward);
        TokenInterface t = TokenInterface(token);
        if(lastWithdraw[msg.sender] == 0) {
           t.mintTo(msg.sender, reward); 
           lastWithdraw[msg.sender] = block.number;
        } else if (lastWithdraw[msg.sender] != 0){
            require(block.number > lastWithdraw[msg.sender] + rewardsWindow, "It hasn't been enough time since your last withdrawl");
            t.mintTo(msg.sender, reward);
            lastWithdraw[msg.sender] = block.number;
        }
    }
    
    function lastWdHeight() external view returns (uint256) {
        
        return lastWithdraw[msg.sender];
    }
    
    function curentBlockHeight() external view returns (uint256) {
        
        return block.number;
    }

    function stakeOf (address _stakeholder) public view returns(uint256) {
        return stakes[_stakeholder];
    }
    
    function totalStakes() public view returns(uint256) {
        uint256 _totalStakes = 0;
        for (uint256 s = 0; s < stakeholders.length; s += 1) {
            _totalStakes = _totalStakes.add(stakes[stakeholders[s]]);
        }
        
        return _totalStakes;
    }
    
    function isStakeholder(address _address) public view returns(bool, uint256) {
        for (uint256 s = 0; s < stakeholders.length; s += 1) {
            if (_address == stakeholders[s]) return (true, s);
        }
        
        return (false, 0);
    }
    
    function addStakeholder(address _stakeholder) internal pause stakeToggle {
        (bool _isStakeholder, ) = isStakeholder(_stakeholder);
        if(!_isStakeholder) stakeholders.push(_stakeholder);
    }
    
    function removeStakeholder(address _stakeholder) internal pause stakeToggle {
        (bool _isStakeholder, uint256 s) = isStakeholder(_stakeholder);
        if(_isStakeholder){
            stakeholders[s] = stakeholders[stakeholders.length - 1];
            stakeholders.pop();
        }
    }
    
    function rewardOf(address _stakeholder) external view returns(uint256) {
        return rewards[_stakeholder];
    }
    
    function totalRewardsPaid() external view returns(uint256) {
        uint256 _totalRewards = 0;
        for (uint256 s = 0; s < stakeholders.length; s += 1){
            _totalRewards = _totalRewards.add(rewards[stakeholders[s]]);
        }
        
        return _totalRewards;
    }
    
    function setStakeCalc(uint _stakeCalc) external pause {
        require(hasRole(_STAKING, msg.sender));
        stakeCalc = _stakeCalc;
    }
    
    function setStakeCap(uint _stakeCap) external pause {
        require(hasRole(_STAKING, msg.sender));
        stakeCap = _stakeCap;
    }
    
    function setRewardsWindow(uint256 _newWindow) external pause {
        require(hasRole(_STAKING, msg.sender));
        rewardsWindow = _newWindow;
    }
    
    function calculateReward(address _stakeholder) public view returns(uint256) {
        return stakes[_stakeholder] / stakeCalc;
    }

    //----------Pause----------------------

    function setPaused(bool _paused) external onlyOwner {
        paused = _paused;
    }
    

}
