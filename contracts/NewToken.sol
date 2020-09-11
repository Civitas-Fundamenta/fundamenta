// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;

import "./ERC20.sol";
import "./EnumerableSet.sol";
import "./Initializable.sol";
import "./AccessControl.sol";
import "./Ownable.sol";

contract FMTAToken is Initializable, ERC20UpgradeSafe, AccessControlUpgradeSafe, OwnableUpgradeSafe {
    
   //------Token Vars-------------
   
    uint256 private _cap;
    uint256 public _fundingAllocation;
    bytes32 public constant _MINTER = keccak256("_MINTER");
    bytes32 public constant _BURNER = keccak256("_BURNER");
    bytes32 public constant _DISTRIBUTOR = keccak256("_DISTRIBUTOR");
    bytes32 public constant USER_ROLE = keccak256("USER");
    bytes32 public constant _STAKING = keccak256("_STAKING");
    bytes32 public constant _VOTING = keccak256("_VOTING");
    bytes32 public constant _SUPPLY = keccak256("_SUPPLY");
    bool public paused;
    
    //--------Toggle Vars-------------------
    
    bool public mintDisabled;
    bool public mintToDisabled;
    
    //-------Staking Vars-------------------
    
    address[] internal stakeholders;
    mapping(address => uint256) internal stakes;
    mapping(address => uint256) internal rewards;
    uint256 public stakeCalc;
    uint256 public stakeCap;
    bool public stakingOff;
    
    //--------Voting Vars-------------------
    
    address[] internal voters;
    mapping(address => uint256) internal votes;
    bool public votingOff = true;
    
    
    //------Token/Admin Constructor---------
    
    bool private initialized;
    
    function initialize (string memory name, string memory symbol) public initializer {
        require(!initialized, "Contract instance has already been initialized");
        initialized = true;
        mintDisabled = true;
        mintToDisabled = true;
        stakingOff = true;
        stakeCap = 3e22;
        stakeCalc = 1000;
        _cap = 5e25;
        _fundingAllocation = 7.5e24;
        _mint(msg.sender, _fundingAllocation);
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setRoleAdmin(USER_ROLE, DEFAULT_ADMIN_ROLE);
        __Context_init_unchained();
        __ERC20_init_unchained(name, symbol);
        __Context_init_unchained();
        __AccessControl_init_unchained();
        __Context_init_unchained();
        __Ownable_init_unchained();
        
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
    
    function createStake(uint256 _stake, address _staker) public pause stakeToggle {
        require(hasRole(_STAKING, msg.sender));
        if(stakes[_staker] == 0) addStakeholder(_staker);
        stakes[_staker] = stakes[_staker].add(_stake);
        if(stakes[_staker] > stakeCap) {
            revert("Can't Stake More than allowed moneybags");
        }
        _burn(_staker, _stake);
    }
    
    function removeStake(uint256 _stake, address _staker) public pause stakeToggle {
        require(hasRole(_STAKING, msg.sender));
        stakes[_staker] = stakes[_staker].sub(_stake);
        if(stakes[_staker] == 0) removeStakeholder(_staker);
        _mint(_staker, _stake);
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
        require(hasRole(_STAKING, msg.sender));
        (bool _isStakeholder, ) = isStakeholder(_stakeholder);
        if(!_isStakeholder) stakeholders.push(_stakeholder);
    }
    
    function removeStakeholder(address _stakeholder) internal pause stakeToggle {
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
    
    uint256[51] private _______gap;
    
}



   

