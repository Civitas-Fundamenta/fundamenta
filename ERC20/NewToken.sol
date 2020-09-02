pragma solidity ^0.6.0;

import "./ERC20.sol";
import "./Ownable.sol";
import "./AccessControl.sol";

contract FMTAToken is ERC20, Ownable, AccessControl {
    
   //------Token Vars-------------
   
    uint256 private _cap;
    uint256 public _premine;
    bytes32 public constant _MINTER = keccak256("_MINTER");
    bytes32 public constant _BURNER = keccak256("_BURNER");
    bytes32 public constant _DISTRIBUTOR = keccak256("_DISTRIBUTOR");
    bool public paused;
    
    //-------Staking Vars---------
    
    address[] internal stakeholders;
    
    mapping(address => uint256) internal stakes;
    
    mapping(address => uint256) internal rewards;
    
    
    //------Token Constructor-----------
    
    constructor() public {
        _cap = 25000000000000000000000000;
        _premine = 7500000000000000000000000;
        _mint(msg.sender, _premine);
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }
    
    //------Token Modifier--------------
    
    modifier pause() {
        require(!paused, "Contract is Paused");
        _;
    }
    
    //------Token Functions--------------
    
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

    function supplyCap() public view returns (uint256) {
        return _cap;
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual override {
        super._beforeTokenTransfer(from, to, amount);

        if (from == address(0)) { 
            require(totalSupply().add(amount) <= _cap, "There is a Supply Cap dude. Come on...");
        }
    }
    
    function setPaused(bool _paused) public onlyOwner {
        paused = _paused;
    }
    
    //-------Staking Functions-------------
    
    function createStake(uint256 _stake) public pause {
        _burn(msg.sender, _stake);
        if(stakes[msg.sender] == 0) addStakeholder(msg.sender);
        stakes[msg.sender] = stakes[msg.sender].add(_stake);
    }
    
    function removeStake(uint256 _stake) public pause {
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
    
    function addStakeholder(address _stakeholder) public pause {
        (bool _isStakeholder, ) = isStakeholder(_stakeholder);
        if(!_isStakeholder) stakeholders.push(_stakeholder);
    }
    
    function removeStakeholder(address _stakeholder) public pause {
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
    
    function calculateReward(address _stakeholder) public view returns(uint256) {
        return stakes[_stakeholder] / 200;
    }
    
    function distributeRewards() public pause {
        require(hasRole(_DISTRIBUTOR, msg.sender));
        for (uint256 s = 0; s < stakeholders.length; s += 1) {
            address stakeholder = stakeholders[s];
            uint256 reward = calculateReward(stakeholder);
            rewards[stakeholder] = rewards[stakeholder].add(reward);
            _mint(stakeholder, reward);
        }
    }
    
    //function withdrawReward() public {
    //    uint256 reward = rewards[msg.sender];
    //    rewards[msg.sender] = 0;
    //    _mint(msg.sender, reward);
    //}
}
