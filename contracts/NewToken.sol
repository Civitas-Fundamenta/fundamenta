// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;

import "./ERC20.sol";
import "./Ownable.sol";
import "./AccessControl.sol";

contract TESTToken is ERC20, Ownable, AccessControl {
    
   //------RBAC Vars--------------
   
    bytes32 public constant _MINTER = keccak256("_MINTER");
    bytes32 public constant _BURNER = keccak256("_BURNER");
    bytes32 public constant _DISTRIBUTOR = keccak256("_DISTRIBUTOR");
    bytes32 public constant _STAKING = keccak256("_STAKING");
    bytes32 public constant _VOTING = keccak256("_VOTING");
    bytes32 public constant _SUPPLY = keccak256("_SUPPLY");
   
   //------Token Vars----------------------
   
    uint256 private _cap;
    uint256 public _fundingEmission;
    
    //-------Toggle Vars--------------------
    
    bool public paused;
    bool public mintDisabled;
    bool public mintToDisabled;
    bool public stakingOff;
   
    //-------Staking Vars-------------------
    
    uint256 public stakeCalc;
    uint256 public stakeCap;
    
    //--------Staking mapping/Arrays----------

    address[] internal stakeholders;
    mapping(address => uint256) internal stakes;
    mapping(address => uint256) internal rewards;
    
    //------Token/Admin Constructor---------
    
    constructor() public ERC20("TEST", "TEST") {
        _fundingEmission = 7.5e24;
        _cap = 5e25;
        stakingOff = true;
        mintDisabled = true;
        mintToDisabled = true;
        stakeCalc = 1000;
        stakeCap = 3e22;
        _mint(msg.sender, _fundingEmission);
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }
    
    //------Toggle Modifiers------------------
    
    modifier pause() {
        require(!paused, "Contract is Paused");
        _;
    }
    
    modifier stakeToggle() {
        require(!stakingOff, "Staking is not currently active");
        _;
    }
    
    modifier mintDis() {
        require(!mintDisabled, "Minting is currently disabled");
        _;
    }
    
    modifier mintToDis() {
        require(!mintToDisabled, "Minting to addresses is curently disabled");
        _;
    }
    
    //-------Admin Modifier----------------
    
       modifier onlyAdmin() {
        require(isAdmin(msg.sender), "Restricted to admins");
        _;
    }
    
    //------Token Functions-----------------
    
    function mintTo(address _to, uint _amount) public pause mintToDis{
        require(hasRole(_MINTER, msg.sender));
        _mint(_to, _amount);
    }
    
    function mint( uint _amount) public pause mintDis{
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
        require(_supplyCap >= totalSupply(), "Yeah... Can't make the supply cap less then the total supply.");
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
    
    
    //--------Toggle Functions----------------
    
    function setPaused(bool _paused) public onlyOwner {
        paused = _paused;
    }
    
    function disableMint(bool _disableMinting) public onlyOwner {
        mintDisabled = _disableMinting;
    }
    
    function disableMintTo(bool _disableMintTo) public onlyOwner {
        mintToDisabled = _disableMintTo;
    }
    
    function stakeOff(bool _stakingOff) public {
        require(hasRole(_STAKING, msg.sender));
        stakingOff = _stakingOff;
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
    
    //--------Admin---------------------------
   
    function isAdmin(address account) public virtual view returns (bool) {
        return hasRole(DEFAULT_ADMIN_ROLE, account);
    }

    function addAdmin(address account) public virtual onlyOwner {
        grantRole(DEFAULT_ADMIN_ROLE, account);
    }
    
    function removeAdmin(address account) public virtual onlyOwner {
        revokeRole(DEFAULT_ADMIN_ROLE, account);
    }

    function renounceAdmin() public virtual {
        renounceRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }
}



   

