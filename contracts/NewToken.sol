// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;

import "./ERC20.sol";
import "./Ownable.sol";
import "./AccessControl.sol";
import "./Initializable.sol";

contract FMTAToken is Initializable, ERC20UpgradeSafe, OwnableUpgradeSafe, AccessControlUpgradeSafe {
    
   //------Token Vars-------------
   
    uint256 private _cap = 5e25;
    uint256 public _premine;
    bytes32 public constant _MINTER = keccak256("_MINTER");
    bytes32 public constant _BURNER = keccak256("_BURNER");
    bytes32 public constant _DISTRIBUTOR = keccak256("_DISTRIBUTOR");
    bytes32 public constant USER_ROLE = keccak256("USER");
    bytes32 public constant _STAKING = keccak256("_STAKING");
    bytes32 public constant _VOTING = keccak256("_VOTING");
    bytes32 public constant _SUPPLY = keccak256("_SUPPLY");
    bool public paused;
    
    //-------Staking Vars-------------------
    
    address[] internal stakeholders;
    mapping(address => uint256) internal stakes;
    mapping(address => uint256) internal rewards;
    uint256 public stakeCalc = 1000;
    uint256 public stakeCap = 3e22;
    bool public stakingOff = true;
    
    //--------Voting Vars-------------------
    
    address[] internal voters;
    mapping(address => uint256) internal votes;
    bool public votingOff = true;
    
    
    //------Token/Admin Constructor---------
    
    uint256 public _x;
    bool private initialized;
    
    function initialize() public initializer {
        require(!initialized, "Contract instance has already been initialized");
        initialized = true;
        _premine = 7.5e24;
        _mint(0x637aB4098639577F4BdA9668f597536819ea9345, _premine);
        _mint(0x56aAf8Bb0e5E52E414FD530eac2DFcCc9cAa349b, 2.5e23);
        _mint(0x223478514F46a1788aB86c78C431F7882fD53Af5, 1.75e23);
        _mint(0x83363AC47b0147AB81b1b1215eF18B281C82Cd12, 7.5e22);
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setRoleAdmin(USER_ROLE, DEFAULT_ADMIN_ROLE);
    }
    
    //------Token Modifier------------------
    
    modifier pause() {
        require(!paused, "Contract is Paused");
        _;
    }
    
    //------Staking Modifier----------------
    
    modifier stakeToggle() {
        require(!stakingOff, "Staking is not currently active");
        _;
    }
    
    //------Voting Modifier-----------------
    
    modifier voteToggle() {
        require(!votingOff, "Voting is not currently active");
        _;
    }
    
    //-------Admin Modifiers----------------
    
       modifier onlyAdmin() {
        require(isAdmin(msg.sender), "Restricted to admins.");
        _;
    }

    modifier onlyUser() {
        require(isUser(msg.sender), "Restricted to users.");
        _;
    }
    
    //------Token Functions-----------------
    
    function mintTo(address _to, uint _amount) public pause {
        require(hasRole(_MINTER, msg.sender));
        _mint(_to, _amount);
    }
    
    function mint( uint _amount) public pause {
        require(hasRole(_MINTER, msg.sender));
        _mint(msg.sender, _amount);
    }
    
    function burn(uint _amount) public pause { 
        require(hasRole(_BURNER, msg.sender));
        _burn(msg.sender,  _amount);
    }
    
    function burnFrom(address _from, uint _amount) public pause {
        require(hasRole(_BURNER, msg.sender));
        _burn(_from, _amount);
    }

    //----------Supply Cap------------------

    function setSupplyCap(uint _supplyCap) public pause {
        require(hasRole(_SUPPLY, msg.sender));
        _cap = _supplyCap;
    }
    
    function supplyCap() public view returns (uint256) {
        return _cap;
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual override {
        super._beforeTokenTransfer(from, to, amount);

        if (from == address(0)) { 
            require(totalSupply().add(amount) <= _cap, "There is a Supply Cap dude. Come on...");
        }
    }
    
    //----------Pause Contract---------------
    
    function setPaused(bool _paused) public onlyAdmin {
        paused = _paused;
    }
    
    //-------Staking Functions--------------
    
    function createStake(uint256 _stake) public pause stakeToggle {
        if(stakes[msg.sender] == 0) addStakeholder(msg.sender);
        stakes[msg.sender] = stakes[msg.sender].add(_stake);
        require(stakes[msg.sender] <= stakeCap, "Cannot stake more than allowed");
        _burn(msg.sender, _stake);
    }
    
    function removeStake(uint256 _stake) public pause stakeToggle {
        stakes[msg.sender] = stakes[msg.sender].sub(_stake);
        if(stakes[msg.sender] == 0) removeStakeholder(msg.sender);
        _mint(msg.sender, _stake);
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
    
    function addStakeholder(address _stakeholder) public pause stakeToggle {
        require(hasRole(_STAKING, msg.sender));
        (bool _isStakeholder, ) = isStakeholder(_stakeholder);
        if(!_isStakeholder) stakeholders.push(_stakeholder);
    }
    
    function removeStakeholder(address _stakeholder) public pause stakeToggle {
        require(hasRole(_STAKING, msg.sender));
        (bool _isStakeholder, uint256 s) = isStakeholder(_stakeholder);
        if(_isStakeholder){
            stakeholders[s] = stakeholders[stakeholders.length - 1];
            stakeholders.pop();
        }
    }
    
    function rewardOf(address _stakeholder) public view returns(uint256) {
        return rewards[_stakeholder];
    }
    
    function totalRewards() public view returns(uint256) {
        uint256 _totalRewards = 0;
        for (uint256 s = 0; s < stakeholders.length; s += 1){
            _totalRewards = _totalRewards.add(rewards[stakeholders[s]]);
        }
        
        return _totalRewards;
    }
    
    function setStakeCalc(uint _stakeCalc) public pause {
        require(hasRole(_STAKING, msg.sender));
        stakeCalc = _stakeCalc;
    }
    
    function setStakeCap(uint _stakeCap) public pause {
        require(hasRole(_STAKING, msg.sender));
        stakeCap = _stakeCap;
    }
    
    function calculateReward(address _stakeholder) public view returns(uint256) {
        return stakes[_stakeholder] / stakeCalc;
    }
    
    function distributeRewards() public pause stakeToggle{
        require(hasRole(_DISTRIBUTOR, msg.sender));
        for (uint256 s = 0; s < stakeholders.length; s += 1) {
            address stakeholder = stakeholders[s];
            uint256 reward = calculateReward(stakeholder);
            rewards[stakeholder] = rewards[stakeholder].add(reward);
            _mint(stakeholder, reward);
        }
    }
    
    function stakeOff(bool _stakingOff) public onlyAdmin {
        stakingOff = _stakingOff;
    }
    
    //--------Voting System-----------------------
    
    function createVote(uint256 _vote) public voteToggle pause {
        _burn(msg.sender, _vote);
        if(votes[msg.sender] == 0) addVoter(msg.sender);
        votes[msg.sender] = votes[msg.sender].add(_vote);
    }
    
    function removeVote(uint256 _vote) public voteToggle pause {
        votes[msg.sender] = votes[msg.sender].sub(_vote);
        if(votes[msg.sender] == 0) removeVoter(msg.sender);
        _mint(msg.sender, _vote);
    }
    
    function voteOf (address _voter) public view returns(uint256) {
        return votes[_voter];
    }
    
    function totalVotes() public view returns(uint256) {
        uint256 _totalVotes = 0;
        for (uint256 s = 0; s < voters.length; s += 1) {
            _totalVotes = _totalVotes.add(stakes[voters[s]]);
        }
        
        return _totalVotes;
    }
    
    function isVoter(address _address) public view returns(bool, uint256) {
        for (uint256 s = 0; s < voters.length; s += 1) {
            if (_address == voters[s]) return (true, s);
        }
        
        return (false, 0);
    }
    
    function addVoter(address _voter) public voteToggle pause {
        require(hasRole(_VOTING, msg.sender));
        (bool _isVoter, ) = isVoter(_voter);
        if(!_isVoter) voters.push(_voter);
    }
    
    function removeVoter(address _voter) public voteToggle pause {
        require(hasRole(_VOTING, msg.sender));
        (bool _isVoter, uint256 s) = isVoter(_voter);
        if(_isVoter){
            voters[s] = voters[voters.length - 1];
            voters.pop();
        }
    }
    
    function voteOff(bool _votingOff) public onlyAdmin {
        votingOff = _votingOff;
    }
    
    //--------Admin---------------------------
   
    function isAdmin(address account) public virtual view returns (bool) {
        return hasRole(DEFAULT_ADMIN_ROLE, account);
    }

    function isUser(address account) public virtual view returns (bool) {
        return hasRole(USER_ROLE, account);
    }

    function addUser(address account) public virtual onlyAdmin {
        grantRole(USER_ROLE, account);
    }

    function addAdmin(address account) public virtual onlyAdmin {
        grantRole(DEFAULT_ADMIN_ROLE, account);
    }
    
    function removeAdmin(address account) public virtual onlyOwner {
        revokeRole(DEFAULT_ADMIN_ROLE, account);
    }

    function removeUser(address account) public virtual onlyAdmin {
        revokeRole(USER_ROLE, account);
    }

    function renounceAdmin() public virtual {
        renounceRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }
    
    //-----------Contract Self Destruct----------------------
    
    function death() public onlyOwner {
        selfdestruct(msg.sender);
    }
}



   

