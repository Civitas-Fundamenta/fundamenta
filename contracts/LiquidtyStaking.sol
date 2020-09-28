// SPDX-License-Identifier: MIT

// Author: Matt Hooft 
// https://github.com/Civitas-Fundamenta
// mhooft@fundamenta.network)

// This is a Liquidty Token Staking Contract that will allow users to deposit or "stake" Liquidty Pool Tokens to 
// earn rewards in the form of the FMTA Token. It is designed to be highly configureable so it can adapt to market
// and ecosystem conditions overtime. Liqudidty pools must be added by the conract owner and only added Tokens
// will be eleigible for rewards.  This also uses Role Based Access Control (RBAC) to allow other accounts and contracts
// (such as oracles) to function as `_ADMIN` allowing them to securly interact with the contract and providing possible 
// future extensibility.

// Liquidity Providers will earn rewards based on a Daily Percentage Yield (DPY) and will be able to compound thier positions
// to increase thier DPY based on a configurable factor (Compunding Daily Percentage Yield or CDPY). Liquidity Providers will 
// have a choice of three lock periods to choose from all with different CDPY factors.

// For example lets use 7, 14 and 21 as our choices for lock periods and have our user Stake 1000 LP Tokens: 

// LP Tokens Staked = 1000
// 7 days = DPY of 10% and CDPY of 0.5%, 
// 14 days  = DPY of 12% and CDPY of 0.75%
// 21 days = DPY of 15% and CDPY of 1.15%. 

// 7 Day Return = 700 FMTA
// 14 Day Return = 1680 FMTA
// 21 Day Return = 3150 FMTA

// DPY after CDPY is applied if users do not remove positions and just remove accrued DPY:

// 7 Day DPY = 10.5%
// 14 Day DPY = 12.75%
// 21 Day DPY = 16.15%

pragma solidity ^0.7.0;

import "./TokenInterface.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

contract LockLPToken is Ownable, AccessControl {
    
    using SafeMath for uint;
    using SafeERC20 for IERC20;
    
    TokenInterface private fundamenta;
    
    //-------RBAC---------------------------

    bytes32 public constant _ADMIN = keccak256("_ADMIN");
    
    //------------Token Vars-------------------
    
    bool public paused;
    bool public addDisabled;
    bool public removePositionOnly;
    
    /**
     * @dev variables to define three seperate lockPeriod's.
     * Each period uses different multipliers and basis points 
     * to calculate Liquidity Miners daily yield.
     */
    
    uint private lockPeriod0;
    uint private lockPeriod1;
    uint private lockPeriod2;
    
    uint private lockPeriod0BasisPoint;
    uint private lockPeriod1BasisPoint;
    uint private lockPeriod2BasisPoint;
    
    uint private lockPeriod0BPScale;
    uint private lockPeriod1BPScale;
    uint private lockPeriod2BPScale;
    
    uint private compYield0;
    uint private compYield1;
    uint private compYield2;
    
    /**
     * @dev `periodCalc` uses blocks instead of timestamps
     * as a way to determine days. approx. 6500 blocks a day
     *  are mined on the ethereum network. 
     * `periodCalc` can also be configured if this were ever 
     * needed to be changed.  It also helps to lower it during 
     * testing if you are looking at using any of this code.
     */
     
    uint private periodCalc;
    
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
        uint UserBP;
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
     * mapeed to user addresses but also maps it to `uint _pid`
     * this makes tracking the same address across multiple pools 
     * with different positions possible.
     */
    
    mapping (uint => mapping (address => LiquidityProviders)) public provider;
    
    //----------------Events---------------------
    
    event accruedYieldWithdrawn (address _account, uint _accruedYield, uint _prevYieldLockPeriod, uint _newYieldLockPeriod, uint _blockHeight);
    event poolAdded (IERC20 _lpTokenAddress, uint _blockHeightAdded);
    event poolRemoved (IERC20 _lpTokenAddress, uint _blockHeightRemoved);
    event periodCalcChanged (uint _newPeriodCalc, uint _blockHeightChanged);
    event lockPeriodsChanged (uint _newLockPeriod0, uint _newLockPeriod1, uint _newLockPeriod2, uint _blockHeightChanged);
    event lockPeriodBasisPointsChanged (uint _newLockPeriod0BasisPoint, uint _newLockPeriod1BasisPoint, uint _newLockPeriod2BasisPoint, uint _blockHeightChanged);
    event lockPeriodBasisPointScalesChanged (uint _newLockPeriod0Scale, uint _newLockPeriod1Scale, uint _newLockPeriod2Scale, uint _blockHeightChanged);
    event positionAdded (address _provider, uint _lockPeriod, uint _lockedAmount, uint _blockHeightAdded);
    event positionRemoved (address _provider, uint _accruedYieldWithdrawn, uint _lockedAmountRemoved, uint _blockHeightRemoved);
    event accruedYieldWithdrawn (address _provider, uint _accruedYieldWithdrawn, uint _newLockHeight, uint _blockHeightWithdrawn);
    event tokensRescued (address _pebcak, address _ERC20, uint _ERC20Amount, uint _blockHeightRescued);
    
    /**
     * @dev constructor sets initial values for contract intiialization
     */ 
    
    constructor() {
        periodCalc = 10;
        lockPeriod0BPScale = 10000;
        lockPeriod1BPScale = 10000;  
        lockPeriod2BPScale = 10000;
        lockPeriod0BasisPoint = 1500;
        lockPeriod1BasisPoint = 1800;
        lockPeriod2BasisPoint = 2500;
        compYield0 = 50;
        compYield1 = 75;
        compYield2 = 100;
        lockPeriod0 = 1;
        lockPeriod1 = 2;
        lockPeriod2 = 3;
        removePositionOnly = false;
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
    
    modifier remPosOnly() {
        require(!removePositionOnly, "Only Removing a position is allowed at the moment");
        _;
    }
    
    //----------Modifier Functions----------------------

    function setPaused(bool _paused) external onlyOwner {
        paused = _paused;
    }
    
    function setRemovePosOnly(bool _removeOnly) external onlyOwner {
        removePositionOnly = _removeOnly;
    }
    
      function disableAdd(bool _addDisabled) external onlyOwner {
        addDisabled = _addDisabled;
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
        require(hasRole(_ADMIN, msg.sender),"Message Sender must be _ADMIN");
        poolInfo.push(PoolInfo({
            ContractAddress: _lpTokenAddress
        }));
        emit poolAdded (_lpTokenAddress, block.number);
    }
    
    function removeLiquidtyPoolToken(uint _pid) public {
        require(hasRole(_ADMIN, msg.sender),"Message Sender must be _ADMIN");
        PoolInfo storage pool = poolInfo[_pid];
        emit poolRemoved (pool.ContractAddress, block.number);
        delete poolInfo[_pid];
        poolInfo.pop();
        
    }
    
     function poolLength() external view returns (uint) {
        return poolInfo.length;
    }
    
    /**
     * @dev function to return stored pool info by passing its 
     * `_pid` as an argument.
     */
    
    function getPoolInfoByPID(uint _pid) public view returns (IERC20 _lpTokenAddress) {
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
    
    function myPosition(uint _pid) public view returns (address _myAddress, uint _unlockHeight, uint _lockedAmount, IERC20 _lpTokenAddress) {
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
    
    function hasPosition(address _userAddress, uint _pid) public view returns (bool _hasPosition) {
        LiquidityProviders memory p = provider[_pid][_userAddress];
        if(p.LockedAmount == 0)
        return false;
        else 
        return true;
    }
    
    /**
     * @dev allows contract owner to set new lock periods.
     */
    
    function setLockPeriods(uint _newPeriod0, uint _newPeriod1, uint _newPeriod2) public {
        require(hasRole(_ADMIN, msg.sender),"Message Sender must be _ADMIN");
        lockPeriod0 = _newPeriod0;
        lockPeriod1 = _newPeriod1;
        lockPeriod2 = _newPeriod2;
        emit lockPeriodsChanged (_newPeriod0, _newPeriod1, _newPeriod2, block.number);
    }
    
    /**
     * @dev allows contract owner to set a new `periodCalc`
     */
    
    function setPeriodCalc(uint _newPeriodCalc) public {
        require(hasRole(_ADMIN, msg.sender),"Message Sender must be _ADMIN");
        periodCalc = _newPeriodCalc;
        emit periodCalcChanged (_newPeriodCalc, block.number);
    }
    
    /**
     * @dev function to show current lock periods.
     */
    
    function showCurrentLockPeriods() external view returns (uint _lockPeriod0, uint _lockPeriod1, uint _lockPeriod2) {
        return (lockPeriod0, lockPeriod1, lockPeriod2);
    }
    
    /**
     * @dev this function allows a user to add a liquidity Staking
     * position.  The user will need to choose one of the three
     * configured lock Periods. Users may add to the position 
     * only once per lock period.
     */
    
    function addPosition(uint _lpTokenAmount, uint _lockPeriod, uint _pid) public addPosDis pause{
        LiquidityProviders storage p = provider[_pid][msg.sender];
        PoolInfo storage pool = poolInfo[_pid];
        address ca = address(this);
        require(p.LockedAmount == 0, "This account already has a position");
        if(_lockPeriod == lockPeriod0) {
            uint _newLpTokenAmount = _lpTokenAmount.add(p.LockedAmount);
            uint _periodCalc = lockPeriod0.mul(periodCalc);
            uint _setLockPeriod = block.number.add(_periodCalc);
            pool.ContractAddress.safeTransferFrom(msg.sender, ca, _lpTokenAmount);
            provider[_pid][msg.sender] = LiquidityProviders(msg.sender, _setLockPeriod, _newLpTokenAmount, lockPeriod0, lockPeriod0BasisPoint);
            emit positionAdded (msg.sender, _setLockPeriod, _newLpTokenAmount, block.number);
        } else if (_lockPeriod == lockPeriod1) {
            uint _newLpTokenAmount = _lpTokenAmount.add(p.LockedAmount);
            uint _periodCalc = lockPeriod1.mul(periodCalc);
            uint _setLockPeriod = block.number.add(_periodCalc);
            pool.ContractAddress.safeTransferFrom(msg.sender, ca, _lpTokenAmount);
            provider[_pid][msg.sender] = LiquidityProviders(msg.sender, _setLockPeriod, _newLpTokenAmount, lockPeriod1, lockPeriod1BasisPoint);
            emit positionAdded (msg.sender, _setLockPeriod, _newLpTokenAmount, block.number);
        } else if (_lockPeriod == lockPeriod2) {
            uint _newLpTokenAmount = _lpTokenAmount.add(p.LockedAmount);
            uint _periodCalc = lockPeriod2.mul(periodCalc);
            uint _setLockPeriod = block.number.add(_periodCalc);
            pool.ContractAddress.safeTransferFrom(msg.sender, ca, _lpTokenAmount);
            provider[_pid][msg.sender] = LiquidityProviders(msg.sender, _setLockPeriod, _newLpTokenAmount, lockPeriod2, lockPeriod2BasisPoint);
            emit positionAdded (msg.sender, _setLockPeriod, _newLpTokenAmount, block.number);
        } else
            revert("Lock Period must be one of the three available options");
    }
    
    /**
     * @dev allows a user to remove a liquidity staking position
     * and will withdraw any pending rewards. User must withdraw 
     * the entire position.
     */
    
    function removePosition(uint _lpTokenAmount, uint _pid) external pause {
        LiquidityProviders storage p = provider[_pid][msg.sender];
        PoolInfo storage pool = poolInfo[_pid];
        require(_lpTokenAmount == p.LockedAmount, "Either you do not have a position or you must remove the entire amount.");
        if(p.UnlockHeight < block.number) {
            pool.ContractAddress.safeTransfer(msg.sender, _lpTokenAmount);
            uint _newLpTokenAmount = p.LockedAmount.sub(_lpTokenAmount);
            uint yield = calculateUserDailyYield(_pid);
            fundamenta.mintTo(msg.sender, yield);
            provider[_pid][msg.sender] = LiquidityProviders(msg.sender, 0, _newLpTokenAmount, 0, 0);
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
    
    function setLockPeriodBasisPoints(uint _newLockPeriod0BasisPoint, uint _newLockPeriod1BasisPoint, uint _newLockPeriod2BasisPoint) public {
        require(hasRole(_ADMIN, msg.sender),"Message Sender must be _ADMIN");
        lockPeriod0BasisPoint = _newLockPeriod0BasisPoint;
        lockPeriod1BasisPoint = _newLockPeriod1BasisPoint;
        lockPeriod2BasisPoint = _newLockPeriod2BasisPoint;
        emit lockPeriodBasisPointsChanged (_newLockPeriod0BasisPoint, _newLockPeriod1BasisPoint,  _newLockPeriod2BasisPoint, block.number);
    }
    
    function setLockPeriodBPScale(uint _newLockPeriod0Scale, uint _newLockPeriod1Scale, uint _newLockPeriod2Scale) public {
        require(hasRole(_ADMIN, msg.sender),"Message Sender must be _ADMIN");
        lockPeriod0BPScale = _newLockPeriod0Scale;
        lockPeriod1BPScale = _newLockPeriod1Scale;
        lockPeriod2BPScale = _newLockPeriod2Scale;
        emit lockPeriodBasisPointScalesChanged (_newLockPeriod0Scale, _newLockPeriod1Scale, _newLockPeriod2Scale, block.number);
    }
    
    function setCoumpundYield(uint _newCompoundYield0, uint _newCompoundYield1, uint _newCompoundYield2) public {
        require(hasRole(_ADMIN, msg.sender),"Message Sender must be _ADMIN");
        compYield0 = _newCompoundYield0;
        compYield1 = _newCompoundYield1;
        compYield2 = _newCompoundYield2;
        
    }
    
    /**
     * @dev calculates a users daily yield. DY is calculated
     * using basis points and the lock period as a multiplier.
     * Basis Points and the scale used are configurble by the
     * contract owner.
     */
    
    function calculateUserDailyYield(uint _pid) public view returns (uint _dailyYield) {
        LiquidityProviders storage p = provider[_pid][msg.sender];
        if(p.Days == lockPeriod0){
            uint bp = p.UserBP;
            uint _userAmount = p.LockedAmount;
            uint dailyYield = _userAmount.mul(bp).div(lockPeriod0BPScale).mul(p.Days);
            return dailyYield;
        } else if(p.Days == lockPeriod1) {
            uint bp = p.UserBP;
            uint _userAmount = p.LockedAmount;
            uint dailyYield = _userAmount.mul(bp).div(lockPeriod0BPScale).mul(p.Days);
            return dailyYield;
        } else if(p.Days == lockPeriod2) {
            uint bp = p.UserBP;
            uint _userAmount = p.LockedAmount;
            uint dailyYield = _userAmount.mul(bp).div(lockPeriod0BPScale).mul(p.Days);
            return dailyYield;
        } revert("Lock Period is incompatible");
        
    }
    
    /**
     * @dev allow user to withdraw thier accrued yield. Reset 
     * the lock period to continue liquidity mining and apply
     * CPDY to DPY. Allow user to add more stake if desired
     * in the process.
     */
    
    function withdrawAccruedYieldAndAdd(uint _pid, uint _lpTokenAmount) public remPosOnly pause{
        LiquidityProviders storage p = provider[_pid][msg.sender];
        PoolInfo storage pool = poolInfo[_pid];
        address ca = address(this);
        uint yield = calculateUserDailyYield(_pid);
        uint lpTokenAmount = _lpTokenAmount;
        require(removePositionOnly == false);
        require(p.UnlockHeight < block.number);
        if (lpTokenAmount != 0) {
            if(p.Days == lockPeriod0) {
                fundamenta.mintTo(msg.sender, yield);
                uint comp = p.UserBP.add(compYield0);
                uint _newLpTokenAmount = lpTokenAmount.add(p.LockedAmount);
                uint _periodCalc = lockPeriod0.mul(periodCalc);
                uint _setLockPeriod = block.number.add(_periodCalc);
                pool.ContractAddress.safeTransferFrom(msg.sender, ca, _lpTokenAmount);
                provider[_pid][msg.sender] = LiquidityProviders(msg.sender, _setLockPeriod , _newLpTokenAmount, p.Days, comp);
                emit accruedYieldWithdrawn (msg.sender, _setLockPeriod, yield, block.number);
            } else if (p.Days == lockPeriod1) {
                fundamenta.mintTo(msg.sender, yield);
                uint comp = p.UserBP.add(compYield1);
                uint _periodCalc = periodCalc.mul(p.Days);
                uint _newLockPeriod = block.number.add(_periodCalc);
                provider[_pid][msg.sender] = LiquidityProviders(msg.sender, _newLockPeriod , p.LockedAmount, p.Days, comp);
                emit accruedYieldWithdrawn (msg.sender, _newLockPeriod, yield, block.number);
            } else if (p.Days == lockPeriod2) {
                fundamenta.mintTo(msg.sender, yield);
                uint comp = p.UserBP.add(compYield2);
                uint _periodCalc = periodCalc.mul(p.Days);
                uint _newLockPeriod = block.number.add(_periodCalc);
                provider[_pid][msg.sender] = LiquidityProviders(msg.sender, _newLockPeriod , p.LockedAmount, p.Days, comp);
                emit accruedYieldWithdrawn (msg.sender, _newLockPeriod, yield, block.number);
            }else revert("No");
        } else if (lpTokenAmount == 0) {
            if(p.Days == lockPeriod0) {
                fundamenta.mintTo(msg.sender, yield);
                uint comp = p.UserBP.add(compYield0);
                uint _periodCalc = periodCalc.mul(p.Days);
                uint _newLockPeriod = block.number.add(_periodCalc);
                provider[_pid][msg.sender] = LiquidityProviders(msg.sender, _newLockPeriod , p.LockedAmount, p.Days, comp);
                emit accruedYieldWithdrawn (msg.sender, _newLockPeriod, yield, block.number);
            } else if (p.Days == lockPeriod1) {
                fundamenta.mintTo(msg.sender, yield);
                uint comp = p.UserBP.add(compYield1);
                uint _periodCalc = periodCalc.mul(p.Days);
                uint _newLockPeriod = block.number.add(_periodCalc);
                provider[_pid][msg.sender] = LiquidityProviders(msg.sender, _newLockPeriod , p.LockedAmount, p.Days, comp);
                emit accruedYieldWithdrawn (msg.sender, _newLockPeriod, yield, block.number);
            } else if (p.Days == lockPeriod2) {
                fundamenta.mintTo(msg.sender, yield);
                uint comp = p.UserBP.add(compYield2);
                uint _periodCalc = periodCalc.mul(p.Days);
                uint _newLockPeriod = block.number.add(_periodCalc);
                provider[_pid][msg.sender] = LiquidityProviders(msg.sender, _newLockPeriod , p.LockedAmount, p.Days, comp);
                emit accruedYieldWithdrawn (msg.sender, _newLockPeriod, yield, block.number);
            }else revert("No");
        }else revert("No");
    }
    
    /**
     * @dev funtion for forcibly remove a users position.  This is required due to the fact that
     * the basis points and scales used to calculate user DPY will be constantly changing.  We 
     * will need to forceibly remove positions of lazy (or malicious) users who will try to take 
     * advantage of DPY being lowered instead of raised and maintining thier current return levels.
     */
    
    function forcePositionRemoval(uint _pid, address _account) public {
        require(hasRole(_ADMIN, msg.sender), "Message Sender must be Admin");
        LiquidityProviders storage p = provider[_pid][_account];
        PoolInfo storage pool = poolInfo[_pid];
        uint _lpTokenAmount = p.LockedAmount;
        pool.ContractAddress.safeTransfer(_account, _lpTokenAmount);
        uint _newLpTokenAmount = p.LockedAmount.sub(_lpTokenAmount);
        uint yield = calculateUserDailyYield(_pid);
        fundamenta.mintTo(msg.sender, yield);
        provider[_pid][_account] = LiquidityProviders(_account, 0, _newLpTokenAmount, 0, 0);
        emit positionRemoved (msg.sender, yield, _lpTokenAmount, block.number);
    
    }
    
    //----Emergency PEBCAK Functions---------------------
    
    function mistakenERC20DepositRescue(address _ERC20, address _pebcak, uint _ERC20Amount) public onlyOwner {
        IERC20(_ERC20).safeTransfer(_pebcak, _ERC20Amount);
        emit tokensRescued (_pebcak, _ERC20, _ERC20Amount, block.number);
    }

    function mistakenDepositRescue(address payable _pebcak, uint _etherAmount) public onlyOwner {
        _pebcak.transfer(_etherAmount);
    }
    
}