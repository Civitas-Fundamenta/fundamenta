// SPDX-License-Identifier: MIT

// Author: Matt Hooft 
// https://github.com/Civitas-Fundamenta
// mhooft@fundamenta.network)

// This is a Liquidty Token Staking Contract that will allow users to deposit or "stake" Uniswap Liquidty Pool Tokens to 
// earn rewards in the form of the FMTA Token. It is designed to be highly configureable to be able to adapt to 
// market and ecosystem conditions overtime. Liqudidty pools must be added by the conract owner and only added Tokens
// will be eleigible for rewards.  This also uses Role Based Access Control (RBAC) to allow other accounts and contracts
// to function as `_ADMIN` allowing them to securly interact with the contract and providing possible future extensibility.

pragma solidity ^0.7.0;

import "./Ownable.sol";
import "./AccessControl.sol";
import "./SafeMath.sol";
import "./TokenInterface.sol";
import "./IERC20.sol";
import "./SafeERC20.sol";

contract LockLPToken is Ownable, AccessControl {
    
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    
    TokenInterface private fundamenta;
    
    //-------RBAC---------------------------

    bytes32 public constant _ADMIN = keccak256("_ADMIN");
    
    //------------Token Vars-------------------
    
    bool public paused;
    bool public addDisabled;
    
    /**
     * @dev variables to define three seperate lockPeriod's.
     * Each period uses different multipliers and basis points 
     * to calculate Liquidity Miners daily yield.
     */
    
    uint256 private lockPeriod0;
    uint256 private lockPeriod1;
    uint256 private lockPeriod2;
    
    uint256 private lockPeriod0BasisPoint;
    uint256 private lockPeriod1BasisPoint;
    uint256 private lockPeriod2BasisPoint;
    
    uint256 private lockPeriod0BPScale;
    uint256 private lockPeriod1BPScale;
    uint256 private lockPeriod2BPScale;
    
    /**
     * @dev `periodCalc` uses blocks instead of timestamps
     * as a way to determine days. approx. 6500 blocks a day
     *  are mined on the ethereum network. 
     * `periodCalc` can also be configured if this were ever 
     * needed to be changed.  It also helps to lower it during 
     * testing if you are looking at using any of this code.
     */
     
    uint256 private periodCalc;
    
    //-------Structs/Mappings/Arrays-------------
    
    /**
     * @dev struct to keep track of Liquidity Providers who have 
     * chosen to stake UniswapV2 Liquidity Pool tokens towards 
     * earning _____. 
     */ 
    
    struct LiquidityProviders {
        address Provider;
        uint UnlockHeight;
        uint LockedAmount;
        uint Days;
    }
    
    /**
     * @dev struct to keep track of liquidty pools and the pairs
     * they are using. These can only be added by the Owner of 
     * the contract.
     */
    
    struct PoolInfo {
        IERC20 ContractAddress;
    }
    
    /**
     * @dev PoolInfo is tracked as an array. The length/index 
     * of the array will be used as the variable `_pid` 
     * throughout the contract.
     */
    
    PoolInfo[] public poolInfo;
    
    /**
     * @dev mapping to keep track of the struct LiquidityProviders 
     * mapeed to user addresses but also maps it to `uint256 _pid`
     * this makes tracking the same address across multiple pools 
     * with different positions possible.
     */
    
    mapping (uint256 => mapping (address => LiquidityProviders)) public provider;
    
    //----------------Events---------------------
    
    event accruedYieldWithdrawn (address _account, uint256 _accruedYield, uint256 _prevYieldLockPeriod, uint256 _newYieldLockPeriod, uint256 _blockHeight);
    event poolAdded (IERC20 _lpTokenAddress, uint256 _blockHeightAdded);
    event poolRemoved (IERC20 _lpTokenAddress, uint256 _blockHeightRemoved);
    event periodCalcChanged (uint256 _newPeriodCalc, uint256 _blockHeightChanged);
    event lockPeriodsChanged (uint256 _newLockPeriod0, uint256 _newLockPeriod1, uint256 _newLockPeriod2, uint256 _blockHeightChanged);
    event lockPeriodBasisPointsChanged (uint256 _newLockPeriod0BasisPoint, uint256 _newLockPeriod1BasisPoint, uint256 _newLockPeriod2BasisPoint, uint256 _blockHeightChanged);
    event lockPeriodBasisPointScalesChanged (uint256 _newLockPeriod0Scale, uint256 _newLockPeriod1Scale, uint256 _newLockPeriod2Scale, uint256 _blockHeightChanged);
    event positionAdded (address _provider, uint256 _lockPeriod, uint256 _lockedAmount, uint256 _blockHeightAdded);
    event positionRemoved (address _provider, uint256 _accruedYieldWithdrawn, uint256 _lockedAmountRemoved, uint256 _blockHeightRemoved);
    event accruedYieldWithdrawn (address _provider, uint256 _accruedYieldWithdrawn, uint256 _newLockHeight, uint256 _blockHeightWithdrawn);
    event tokensRescued (address _pebcak, address _ERC20, uint256 _ERC20Amount, uint256 _blockHeightRescued);
    
    /**
     * @dev constructor sets initial values for contract intiialization
     */ 
    
    constructor() {
        periodCalc = 6500;
        lockPeriod0BPScale = 10000;
        lockPeriod1BPScale = 10000;  
        lockPeriod2BPScale = 10000;
        lockPeriod0BasisPoint = 1500;
        lockPeriod1BasisPoint = 1800;
        lockPeriod2BasisPoint = 2500;
        lockPeriod0 = 7;
        lockPeriod1 = 14;
        lockPeriod2 = 21;
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }
     
     //------------State modifiers---------------------
     
      modifier pause() {
        require(!paused, "Contract is Paused");
        _;
    }
    
     modifier addPosDis() {
        require(!addDisabled, "Adding a Position is currently disabled");
        _;
    }
    
    //------------Token Functions----------------------
    
    /**
     * @dev functions to add and remove Liquidty Pool pairs to allow users to
     * stake the pools LP Tokens towards earnign rewards. Can only
     * be called by accounts with the `_ADMIN` role and should only 
     * be added once. The index at which the pool pair is stored 
     * will determine the pools `_pid`.
     */
    
    function addLiquidtyPoolToken(IERC20 _lpTokenAddress) public {
        require(hasRole(_ADMIN, msg.sender));
        poolInfo.push(PoolInfo({
            ContractAddress: _lpTokenAddress
        }));
        emit poolAdded (_lpTokenAddress, block.number);
    }
    
    function removeLiquidtyPoolToken(uint256 _pid) public {
        require(hasRole(_ADMIN, msg.sender));
        PoolInfo memory pool = poolInfo[_pid];
        emit poolRemoved (pool.ContractAddress, block.number);
        delete poolInfo[_pid];
        
    }
    
     function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }
    
    /**
     * @dev function to return stored pool info by passing its 
     * `_pid` as an argument.
     */
    
    function getPoolInfoByPID(uint256 _pid) public view returns (IERC20 _lpTokenAddress) {
        PoolInfo storage pool = poolInfo[_pid];
        return (pool.ContractAddress);
    }
    
    /**
     * @dev function to set the token that will be minting rewards 
     * for Liquidity Providers.
     */
    
    function setTokenContract(TokenInterface _fmta) public onlyOwner {
        fundamenta = _fmta;
    }
    
    /**
     * @dev function to return the contracts balances of LP Tokens
     * staked from different Uniswap pools.
     */

    function contractBalanceByPoolID(uint _pid) public view returns (uint _balance) {
        PoolInfo storage pool = poolInfo[_pid];
        address ca = address(this);
        return pool.ContractAddress.balanceOf(ca);
    }
    
    /**
     * @dev funtion that returns a callers staked position in a pool 
     * using `_pid` as an argument.
     */
    
    function myPosition(uint256 _pid) public view returns (address _myAddress, uint256 _unlockHeight, uint256 _lockedAmount, IERC20 _lpTokenAddress) {
        LiquidityProviders memory p = provider[_pid][msg.sender];
        PoolInfo storage pool = poolInfo[_pid];
        if(p.LockedAmount == 0)
        revert("You do not have a position");
        else
        return (p.Provider, p.UnlockHeight, p.LockedAmount, pool.ContractAddress);
    }
    
    /**
     * @dev funtion that returns a true or false regarding whether
     * an account as a position in a pool.  Takes the account address
     * and `_pid` as arguments
     */
    
    function hasPosition(address _userAddress, uint256 _pid) public view returns (bool _hasPosition) {
        LiquidityProviders memory p = provider[_pid][_userAddress];
        if(p.LockedAmount == 0)
        return false;
        else 
        return true;
    }
    
    /**
     * @dev allows contract owner to set new lock periods.
     */
    
    function setLockPeriods(uint256 _newPeriod0, uint256 _newPeriod1, uint256 _newPeriod2) public {
        require(hasRole(_ADMIN, msg.sender));
        lockPeriod0 = _newPeriod0;
        lockPeriod1 = _newPeriod1;
        lockPeriod2 = _newPeriod2;
        emit lockPeriodsChanged (_newPeriod0, _newPeriod1, _newPeriod2, block.number);
    }
    
    /**
     * @dev allows contract owner to set a new `periodCalc`
     */
    
    function setPeriodCalc(uint256 _newPeriodCalc) public {
        require(hasRole(_ADMIN, msg.sender));
        periodCalc = _newPeriodCalc;
        emit periodCalcChanged (_newPeriodCalc, block.number);
    }
    
    /**
     * @dev function to show current lock periods.
     */
    
    function showCurrentLockPeriods() external view returns (uint256 _lockPeriod0, uint256 _lockPeriod1, uint256 _lockPeriod2) {
        return (lockPeriod0, lockPeriod1, lockPeriod2);
    }
    
    /**
     * @dev this function allows a user to add a liquidity Staking
     * position.  The user will need to choose one of the three
     * configured lock Periods. Users may add to the position 
     * only once per lock period.
     */
    
    function addPosition(uint256 _lpTokenAmount, uint256 _lockPeriod, uint256 _pid) public addPosDis pause{
        LiquidityProviders storage p = provider[_pid][msg.sender];
        PoolInfo storage pool = poolInfo[_pid];
        address ca = address(this);
        require(p.LockedAmount == 0, "This account already has a position");
        if(_lockPeriod == lockPeriod0) {
            uint256 _newLpTokenAmount = _lpTokenAmount.add(p.LockedAmount);
            uint256 _periodCalc = lockPeriod0.mul(periodCalc);
            uint256 _setLockPeriod = block.number.add(_periodCalc);
            pool.ContractAddress.safeTransferFrom(msg.sender, ca, _lpTokenAmount);
            provider[_pid][msg.sender] = LiquidityProviders(msg.sender, _setLockPeriod, _newLpTokenAmount, lockPeriod0);
            emit positionAdded (msg.sender, _setLockPeriod, _newLpTokenAmount, block.number);
        } else if (_lockPeriod == lockPeriod1) {
            uint256 _newLpTokenAmount = _lpTokenAmount.add(p.LockedAmount);
            uint256 _periodCalc = lockPeriod1.mul(periodCalc);
            uint256 _setLockPeriod = block.number.add(_periodCalc);
            pool.ContractAddress.safeTransferFrom(msg.sender, ca, _lpTokenAmount);
            provider[_pid][msg.sender] = LiquidityProviders(msg.sender, _setLockPeriod, _newLpTokenAmount, lockPeriod1);
            emit positionAdded (msg.sender, _setLockPeriod, _newLpTokenAmount, block.number);
        } else if (_lockPeriod == lockPeriod2) {
            uint256 _newLpTokenAmount = _lpTokenAmount.add(p.LockedAmount);
            uint256 _periodCalc = lockPeriod2.mul(periodCalc);
            uint256 _setLockPeriod = block.number.add(_periodCalc);
            pool.ContractAddress.safeTransferFrom(msg.sender, ca, _lpTokenAmount);
            provider[_pid][msg.sender] = LiquidityProviders(msg.sender, _setLockPeriod, _newLpTokenAmount, lockPeriod2);
            emit positionAdded (msg.sender, _setLockPeriod, _newLpTokenAmount, block.number);
        } else
            revert("Lock Period must be one of the three available options");
    }
    
    /**
     * @dev allows a user to remove a liquidity staking position
     * and will withdraw any pending rewards. User must withdraw 
     * the entire position.
     */
    
    function removePosition(uint _lpTokenAmount, uint256 _pid) external pause {
        LiquidityProviders storage p = provider[_pid][msg.sender];
        PoolInfo storage pool = poolInfo[_pid];
        require(_lpTokenAmount == p.LockedAmount, "You must remove the entire position");
        if(p.UnlockHeight < block.number) {
            pool.ContractAddress.safeTransfer(msg.sender, _lpTokenAmount);
            uint256 _newLpTokenAmount = p.LockedAmount.sub(_lpTokenAmount);
            uint yield = calculateUserDailyYield(_pid);
            fundamenta.mintTo(msg.sender, yield);
            provider[_pid][msg.sender] = LiquidityProviders(msg.sender, 0, _newLpTokenAmount, 0);
            emit positionRemoved (msg.sender, yield, _lpTokenAmount, block.number);
        } else 
            revert("Tokens have not been locked for the agreed upon period");
    }
    
    /**
     * @dev set of functions to set parameters regarding 
     * lock periods and basis points which are used to  
     * calculate a users daily yield. Can only be called 
     * by contract owner.
     */
    
    function setLockPeriodBasisPoints(uint256 _newLockPeriod0BasisPoint, uint256 _newLockPeriod1BasisPoint, uint256 _newLockPeriod2BasisPoint) public {
        require(hasRole(_ADMIN, msg.sender));
        lockPeriod0BasisPoint = _newLockPeriod0BasisPoint;
        lockPeriod1BasisPoint = _newLockPeriod1BasisPoint;
        lockPeriod2BasisPoint = _newLockPeriod2BasisPoint;
        emit lockPeriodBasisPointsChanged (_newLockPeriod0BasisPoint, _newLockPeriod1BasisPoint,  _newLockPeriod2BasisPoint, block.number);
    }
    
    function setLockPeriodBPScale(uint256 _newLockPeriod0Scale, uint256 _newLockPeriod1Scale, uint256 _newLockPeriod2Scale) public {
        require(hasRole(_ADMIN, msg.sender));
        lockPeriod0BPScale = _newLockPeriod0Scale;
        lockPeriod1BPScale = _newLockPeriod1Scale;
        lockPeriod2BPScale = _newLockPeriod2Scale;
        emit lockPeriodBasisPointScalesChanged (_newLockPeriod0Scale, _newLockPeriod1Scale, _newLockPeriod2Scale, block.number);
    }
    
    /**
     * @dev calculates a users daily yield. DY is calculated
     * using basis points and the lock period as a multiplier.
     * Basis Points and the scale used are configurble by the
     * contract owner.
     */
    
    function calculateUserDailyYield(uint256 _pid) public view returns (uint256 _dailyYield) {
        LiquidityProviders storage p = provider[_pid][msg.sender];
        if(p.Days == lockPeriod0){
            uint256 bp = lockPeriod0BasisPoint;
            uint256 _userAmount = p.LockedAmount;
            uint256 dailyYield = _userAmount.mul(bp).div(lockPeriod0BPScale).mul(p.Days);
            return dailyYield;
        } else if(p.Days == lockPeriod1) {
            uint256 bp = lockPeriod1BasisPoint;
            uint256 _userAmount = p.LockedAmount;
            uint256 dailyYield = _userAmount.mul(bp).div(lockPeriod0BPScale).mul(p.Days);
            return dailyYield;
        } else if(p.Days == lockPeriod2) {
            uint256 bp = lockPeriod2BasisPoint;
            uint256 _userAmount = p.LockedAmount;
            uint256 dailyYield = _userAmount.mul(bp).div(lockPeriod0BPScale).mul(p.Days);
            return dailyYield;
        } revert("Lock Period is incompatible");
        
    }
    
    /**
     * @dev allow user to withdraw thier accrued yield and reset 
     * the lock period to continue liquidity mining.
     */
    
    function withdrawAccruedYield(uint256 _pid) public pause{
        LiquidityProviders storage p = provider[_pid][msg.sender];
        uint yield = calculateUserDailyYield(_pid);
        require(p.UnlockHeight < block.number);
        fundamenta.mintTo(msg.sender, yield);
        uint256 _periodCalc = periodCalc.mul(p.Days);
        uint256 _newLockPeriod = block.number.add(_periodCalc);
        provider[_pid][msg.sender] = LiquidityProviders(msg.sender, _newLockPeriod , p.LockedAmount, p.Days);
        emit accruedYieldWithdrawn (msg.sender, _newLockPeriod, yield, block.number);
        
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