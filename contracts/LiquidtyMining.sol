// SPDX-License-Identifier: GPL-3.0

// Author: Matt Hooft 
// https://github.com/Civitas-Fundamenta
// mhooft@fundamenta.network)

pragma solidity ^0.8.0;

import "./TokenInterface.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/AccessControl.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/IERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/utils/SafeERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/math/SafeMath.sol";

contract LiquidityMining is Ownable, AccessControl {
    
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    
    //-------RBAC---------------------------

    bytes32 public constant _ADMIN = keccak256("_ADMIN");
    bytes32 public constant _REMOVAL = keccak256("_REMOVAL");
    bytes32 public constant _MOVE = keccak256("_MOVE");
    bytes32 public constant _RESCUE = keccak256("_RESCUE");
    
    //------------Token Vars-------------------
    
    bool public paused;
    bool public addDisabled;
    bool public removePositionOnly;
    
    uint private lockPeriod0;
    uint private lockPeriod1;
    uint private lockPeriod2;
    
    uint private lockPeriodBPScale;
    
    uint private preYieldDivisor;
    
    /**
     * `periodCalc` uses blocks instead of timestamps
     * as a way to determine days. approx. 6500 blocks a day
     *  are mined on the ethereum network. 
     * `periodCalc` can also be configured if this were ever 
     * needed to be changed.  It also helps to lower it during 
     * testing if you are looking at using any of this code.
     */
     
    uint public periodCalc;
    
    //-------Structs/Mappings/Arrays-------------
    
    /**
     * struct to keep track of Liquidity Providers who have 
     * chosen to stake UniswapV2 Liquidity Pool tokens towards 
     * earning FMTA. 
     */ 
    
    struct LiquidityProviders {
        address Provider;
        uint UnlockHeight;
        uint LockedAmount;
        uint Days;
        uint UserBP;
        uint TotalRewardsPaid;
    }
    
    /**
     * struct to keep track of liquidity pools, total
     * rewards paid and total value locked in said pools.
     */
    
    struct PoolInfo {
        IERC20 ContractAddress;
        IERC20 RewardsTokenAddress;
        uint TotalRewardsPaidByPool;
        uint TotalLPTokensLocked;
        uint PoolBonus;
        uint RewardsPool;
        uint lockPeriod0BasisPoint;
        uint lockPeriod1BasisPoint;
        uint lockPeriod2BasisPoint;
        uint compYield0;
        uint compYield1;
        uint compYield2;
        uint maxPoolBP;
    }
    
    /**
     * PoolInfo is tracked as an array. The length/index 
     * of the array will be used as the variable `_pid` (Pool ID) 
     * throughout the contract.
     */
    
    PoolInfo[] public poolInfo;
    
    /**
     * mapping to keep track of the struct LiquidityProviders 
     * mapeed to user addresses but also maps it to `uint _pid`
     * this makes tracking the same address across multiple pools 
     * with different positions possible as _pid will also be the 
     * index of PoolInfo[]
     */
    
    mapping (uint => mapping (address => LiquidityProviders)) public provider;

    //-------Events--------------

    event PositionAdded (address _account, uint _amount, uint _blockHeight);
    event PositionRemoved (address _account, uint _amount, uint _blockHeight);
    event PositionForceRemoved (address _account, uint _amount, uint _blockHeight);
    event PositionCompounded (address _account, uint _amountAdded, uint _blockHeight);
    event ETHRescued (address _movedBy, address _movedTo, uint _amount, uint _blockHeight);
    event ERC20Movement (address _movedBy, address _movedTo, uint _amount, uint _blockHeight);
    
    
    /**
     * constructor sets initial values for contract intiialization
     */ 
    
    constructor() {
        periodCalc = 6500;
        lockPeriodBPScale = 10000;
        preYieldDivisor = 2;
        lockPeriod0 = 5;
        lockPeriod1 = 10;
        lockPeriod2 = 15;
        removePositionOnly = false;
        _setupRole(_ADMIN, msg.sender);
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender); //God Mode. DEFAULT_ADMIN_ROLE Must Require _ADMIN ROLE Still to execute _ADMIN functions.
    }
     
     //------------State modifiers---------------------
     
      modifier unpaused() {
        require(!paused, "LiquidityMining: Contract is Paused");
        _;
    }
    
     modifier addPositionNotDisabled() {
        require(!addDisabled, "LiquidityMining: Adding a Position is currently disabled");
        _;
    }
    
    modifier remPosOnly() {
        require(!removePositionOnly, "LiquidityMining: Only Removing a position is allowed at the moment");
        _;
    }
    
    //----------Modifier Functions----------------------

    function setPaused(bool _paused) external {
        require(hasRole(_ADMIN, msg.sender),"LiquidityMining: Message Sender must be _ADMIN");
        paused = _paused;
    }
    
    function setRemovePosOnly(bool _removeOnly) external {
        require(hasRole(_ADMIN, msg.sender),"LiquidityMining: Message Sender must be _ADMIN");
        removePositionOnly = _removeOnly;
    }
    
      function disableAdd(bool _addDisabled) external {
          require(hasRole(_ADMIN, msg.sender),"LiquidityMining: Message Sender must be _ADMIN");
        addDisabled = _addDisabled;
    }
    
    //------------Token Functions----------------------
    
    /**
     * functions to add and remove liquidity Pool pairs to allow users to
     * stake the pools LP Tokens towards earnign rewards. Can only
     * be called by accounts with the `_ADMIN` role and should only 
     * be added once. The index at which the pool pair is stored 
     * will determine the pools `_pid`. Note if you remove a pool the 
     * index remians but is just left empty making the _pid return
     * zero value if called.
     */
    
    function addLiquidityPoolToken(
        IERC20 _lpTokenAddress, 
        IERC20 _rewardsTokenAddress,
        uint _bonus,
        uint _rewardsPool, 
        uint _lpbp0, 
        uint _lpbp1, 
        uint _lpbp2, 
        uint _cy0, 
        uint _cy1, 
        uint _cy2,
        uint _mbp) public {
        require(hasRole(_ADMIN, msg.sender),"LiquidityMining: Message Sender must be _ADMIN");
        poolInfo.push(PoolInfo({
            ContractAddress: _lpTokenAddress,
            RewardsTokenAddress: _rewardsTokenAddress,
            TotalRewardsPaidByPool: 0,
            TotalLPTokensLocked: 0,
            RewardsPool: _rewardsPool,
            PoolBonus: _bonus,
            lockPeriod0BasisPoint: _lpbp0,
            lockPeriod1BasisPoint: _lpbp1,
            lockPeriod2BasisPoint: _lpbp2,
            compYield0: _cy0,
            compYield1: _cy1,
            compYield2: _cy2,
            maxPoolBP: _mbp
        }));
        _rewardsTokenAddress.safeTransferFrom(msg.sender, address(this), _rewardsPool);
       
    }
    
    function removeLiquidityPoolToken(uint _pid) public {
        require(hasRole(_ADMIN, msg.sender),"LiquidityMining: Message Sender must be _ADMIN");
        delete poolInfo[_pid];
        
    }
    
    //------------Information Functions------------------
    
    /**
     * return the length of the pool array
     */
    
     function poolLength() external view returns (uint) {
        return poolInfo.length;
    }
    
    /**
     * function to return the contracts balances of LP Tokens
     * staked from different Uniswap pools.
     */

    function contractBalanceByPoolID(uint _pid) public view returns (uint _balance) {
        PoolInfo memory pool = poolInfo[_pid];
        address ca = address(this);
        return pool.ContractAddress.balanceOf(ca);
    }
    
    /**
     * funtion that returns a callers staked position in a pool 
     * using `_pid` as an argument.
     */
    
    function accountPosition(address _account, uint _pid) public view returns (
        address _accountAddress, 
        uint _unlockHeight, 
        uint _lockedAmount, 
        uint _lockPeriodInDays, 
        uint _userDPY, 
        IERC20 _lpTokenAddress,
        uint _totalRewardsPaidFromPool
    ) {
        LiquidityProviders memory p = provider[_pid][_account];
        PoolInfo memory pool = poolInfo[_pid];
        return (
            p.Provider, 
            p.UnlockHeight, 
            p.LockedAmount, 
            p.Days, 
            p.UserBP, 
            pool.ContractAddress,
            pool.TotalRewardsPaidByPool
        );
    }
    
    /**
     * funtion that returns a true or false regarding whether
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
     * function to show current lock periods.
     */
    
    function showCurrentLockPeriods() external view returns (
        uint _lockPeriod0, 
        uint _lockPeriod1, 
        uint _lockPeriod2
    ) {
        return (
            lockPeriod0, 
            lockPeriod1, 
            lockPeriod2
        );
    }
    
    //-----------Set Functions----------------------
    
    
    /**
     * allows accounts with the _ADMIN role to set new lock periods.
     */
    
    function setLockPeriods(uint _newPeriod0, uint _newPeriod1, uint _newPeriod2) public {
        require(hasRole(_ADMIN, msg.sender),"LiquidityMining: Message Sender must be _ADMIN");
        require(_newPeriod2 > _newPeriod1 && _newPeriod1 > _newPeriod0);
        lockPeriod0 = _newPeriod0;
        lockPeriod1 = _newPeriod1;
        lockPeriod2 = _newPeriod2;
    }
    
    /**
     * allows contract owner to set a new `periodCalc`
     */
    
    function setPeriodCalc(uint _newPeriodCalc) public {
        require(hasRole(_ADMIN, msg.sender),"LiquidityMining: Message Sender must be _ADMIN");
        periodCalc = _newPeriodCalc;
    }

    /**
     * set of functions to set parameters regarding 
     * lock periods and basis points which are used to  
     * calculate a users daily yield. Can only be called 
     * by contract _ADMIN.
     */
    
    function setLockPeriodBasisPoints (
        uint _newLockPeriod0BasisPoint, 
        uint _newLockPeriod1BasisPoint, 
        uint _newLockPeriod2BasisPoint,
        uint _pid) public {
        require(hasRole(_ADMIN, msg.sender),"LiquidityMining: Message Sender must be _ADMIN");
        poolInfo[_pid].lockPeriod0BasisPoint = _newLockPeriod0BasisPoint;
        poolInfo[_pid].lockPeriod1BasisPoint = _newLockPeriod1BasisPoint;
        poolInfo[_pid].lockPeriod2BasisPoint = _newLockPeriod2BasisPoint;
    }
    
    function setLockPeriodBPScale(uint _newLockPeriodScale) public {
        require(hasRole(_ADMIN, msg.sender),"LiquidityMining: Message Sender must be _ADMIN");
        lockPeriodBPScale = _newLockPeriodScale;
    
    }

    function setMaxUserBP(uint _newMaxPoolBP, uint _pid) public {
        require(hasRole(_ADMIN, msg.sender),"LiquidityMining: Message Sender must be _ADMIN");
        PoolInfo storage pool = poolInfo[_pid];
        pool.maxPoolBP = _newMaxPoolBP;
    }
    
    function setCompoundYield (
        uint _newCompoundYield0, 
        uint _newCompoundYield1, 
        uint _newCompoundYield2,
        uint _pid) public {
        require(hasRole(_ADMIN, msg.sender),"LiquidityMining: Message Sender must be _ADMIN");
        poolInfo[_pid].compYield0 = _newCompoundYield0;
        poolInfo[_pid].compYield1 = _newCompoundYield1;
        poolInfo[_pid].compYield2 = _newCompoundYield2;
        
    }
    
    function setPoolBonus(uint _pid, uint _bonus) public {
        require(hasRole(_ADMIN, msg.sender));
        poolInfo[_pid].PoolBonus = _bonus;
    }

    function setPreYieldDivisor(uint _newDivisor) public {
        require(hasRole(_ADMIN, msg.sender),"LiquidityMining: Message Sender must be _ADMIN");
        preYieldDivisor = _newDivisor;
    }
    
    //-----------Position/Rewards Functions------------------
    
    /**
     * this function allows a user to add a liquidity Staking
     * position.  The user will need to choose one of the three
     * configured lock Periods. Users may add to the position 
     * only once per lock period.
     */
    
    function addPosition(uint _lpTokenAmount, uint _lockPeriod, uint _pid) public addPositionNotDisabled unpaused{
        LiquidityProviders storage p = provider[_pid][msg.sender];
        PoolInfo storage pool = poolInfo[_pid];
        address ca = address(this);
        require(p.LockedAmount == 0, "LiquidityMining: This account already has a position");
        if(_lockPeriod == lockPeriod0) {
            pool.ContractAddress.safeTransferFrom(msg.sender, ca, _lpTokenAmount);
            provider[_pid][msg.sender] = LiquidityProviders (
                msg.sender, 
                block.number.add(periodCalc.mul(lockPeriod0)), 
                _lpTokenAmount, 
                lockPeriod0, 
                pool.lockPeriod0BasisPoint,
                p.TotalRewardsPaid
            );
            pool.TotalLPTokensLocked = pool.TotalLPTokensLocked.add(_lpTokenAmount);
        } else if (_lockPeriod == lockPeriod1) {
            pool.ContractAddress.safeTransferFrom(msg.sender, ca, _lpTokenAmount);
            provider[_pid][msg.sender] = LiquidityProviders (
                msg.sender, 
                block.number.add(periodCalc.mul(lockPeriod1)), 
                _lpTokenAmount, 
                lockPeriod1, 
                pool.lockPeriod1BasisPoint,
                p.TotalRewardsPaid
            );
            pool.TotalLPTokensLocked = pool.TotalLPTokensLocked.add(_lpTokenAmount);
        } else if (_lockPeriod == lockPeriod2) {
            pool.ContractAddress.safeTransferFrom(msg.sender, ca, _lpTokenAmount);
            provider[_pid][msg.sender] = LiquidityProviders (
                msg.sender, 
                block.number.add(periodCalc.mul(lockPeriod2)), 
                _lpTokenAmount, 
                lockPeriod2, 
                pool.lockPeriod2BasisPoint,
                p.TotalRewardsPaid
            );
            pool.TotalLPTokensLocked = pool.TotalLPTokensLocked.add(_lpTokenAmount);
        }else revert("LiquidityMining: Incompatible Lock Period");
      emit PositionAdded (
          msg.sender,
          _lpTokenAmount,
          block.number
      );
    }

    //function aP ()
    
    /**
     * allows a user to remove a liquidity staking position
     * and will withdraw any pending rewards. User must withdraw 
     * the entire position.
     */
    
    function removePosition(uint _pid) external unpaused {
        LiquidityProviders storage p = provider[_pid][msg.sender];
        PoolInfo storage pool = poolInfo[_pid];
        //require(_lpTokenAmount == p.LockedAmount, "LiquidyMining: Either you do not have a position or you must remove the entire amount.");
        require(p.UnlockHeight < block.number, "LiquidityMining: Not Long Enough");
            pool.ContractAddress.safeTransfer(msg.sender, p.LockedAmount);
            pool.RewardsTokenAddress.safeTransfer(msg.sender, p.LockedAmount);
            uint yield = calculateUserDailyYield(_pid);
            pool.RewardsTokenAddress.safeTransfer(msg.sender, yield);
            provider[_pid][msg.sender] = LiquidityProviders (
                msg.sender, 
                0, 
                p.LockedAmount.sub(p.LockedAmount),
                0, 
                0,
                p.TotalRewardsPaid.add(yield)
            );
        pool.TotalRewardsPaidByPool = pool.TotalRewardsPaidByPool.add(yield);
        pool.TotalLPTokensLocked = pool.TotalLPTokensLocked.sub(p.LockedAmount);
        emit PositionRemoved(
        msg.sender,
        p.LockedAmount,
        block.number
      );
    }

    /**
     * function to forcibly remove a users position.  This 
     * is required due to the fact that the basis points used to 
     * calculate user DPY will be constantly changing.
     * We will need to forceibly remove positions of lazy (or malicious)
     * users who will try to take advantage of DPY being lowered instead 
     * of raised and maintining thier current return levels.
     */
    
    function forcePositionRemoval(uint _pid, address _account) public {
        require(hasRole(_REMOVAL, msg.sender));
        LiquidityProviders storage p = provider[_pid][_account];
        PoolInfo storage pool = poolInfo[_pid];
        uint yield = p.LockedAmount.mul(p.UserBP.add(pool.PoolBonus)).div(lockPeriodBPScale).mul(p.Days);
        pool.RewardsTokenAddress.safeTransfer(_account, yield);
        uint _lpTokenAmount = p.LockedAmount;
        pool.ContractAddress.safeTransfer(_account, _lpTokenAmount);
        uint _newLpTokenAmount = p.LockedAmount.sub(_lpTokenAmount);
        provider[_pid][_account] = LiquidityProviders (
            _account, 
            0, 
            _newLpTokenAmount, 
            0, 
            0,
            p.TotalRewardsPaid.add(yield)
        );
        pool.TotalRewardsPaidByPool = pool.TotalRewardsPaidByPool.add(yield);
        pool.TotalLPTokensLocked = pool.TotalLPTokensLocked.sub(_lpTokenAmount);
        emit PositionForceRemoved(
        msg.sender,
        _lpTokenAmount,
        block.number
      );
    
    }

    /**
     * calculates a users daily yield. DY is calculated
     * using basis points and the lock period as a multiplier.
     * Basis Points and the scale used are configurble by accounts
     * or contracts that have the _ADMIN Role
     */
    
    function calculateUserDailyYield(uint _pid) public view returns (uint _dailyYield) {
        LiquidityProviders memory p = provider[_pid][msg.sender];
        PoolInfo memory pool = poolInfo[_pid];
        uint dailyYield = p.LockedAmount.mul(p.UserBP.add(pool.PoolBonus)).div(lockPeriodBPScale).mul(p.Days);
        return dailyYield;
    }
    
    /**
     * allow user to withdraw thier accrued yield. Reset 
     * the lock period to continue liquidity mining and apply
     * CDPY to DPY. Allow user to add more stake if desired
     * in the process. Once a user has reached the `maxUserBP`
     * DPY will no longer increase.
     */
    
    function withdrawAccruedYieldAndAdd(uint _pid, uint _lpTokenAmount) public remPosOnly unpaused{
        LiquidityProviders storage p = provider[_pid][msg.sender];
        PoolInfo storage pool = poolInfo[_pid];
        uint yield = calculateUserDailyYield(_pid);
        require(removePositionOnly == false);
        require(p.UnlockHeight < block.number);
        require(pool.RewardsPool > pool.TotalRewardsPaidByPool);
        if (_lpTokenAmount != 0) {
            if(p.Days == lockPeriod0) {
                if (yield.add(pool.TotalRewardsPaidByPool) > pool.RewardsPool) 
                    revert("LiqudiityMining: Rewards Too High");
                else
                pool.RewardsTokenAddress.safeTransfer(msg.sender, yield);
                pool.ContractAddress.safeTransferFrom(msg.sender, address(this), _lpTokenAmount);
                provider[_pid][msg.sender] = LiquidityProviders (
                msg.sender, 
                    block.number.add(periodCalc.mul(lockPeriod0)), 
                    _lpTokenAmount.add(p.LockedAmount), 
                    lockPeriod0, 
                    p.UserBP.add(p.UserBP >= pool.maxPoolBP ? 0 : pool.compYield0),
                    p.TotalRewardsPaid.add(yield)
                );
                pool.TotalRewardsPaidByPool = pool.TotalRewardsPaidByPool.add(yield);
                pool.TotalLPTokensLocked = pool.TotalLPTokensLocked.add(_lpTokenAmount);
            } else if (p.Days == lockPeriod1) {
                pool.RewardsTokenAddress.safeTransfer(msg.sender, yield);
                pool.ContractAddress.safeTransferFrom(msg.sender, address(this), _lpTokenAmount);
                provider[_pid][msg.sender] = LiquidityProviders (
                    msg.sender, 
                    block.number.add(periodCalc.mul(lockPeriod1)),
                    _lpTokenAmount.add(p.LockedAmount), 
                    lockPeriod1, 
                    p.UserBP.add(p.UserBP >= pool.maxPoolBP ? 0 : pool.compYield1),
                    p.TotalRewardsPaid.add(yield)
                );
                pool.TotalRewardsPaidByPool = pool.TotalRewardsPaidByPool.add(yield);
                pool.TotalLPTokensLocked = pool.TotalLPTokensLocked.add(_lpTokenAmount);
            } else if (p.Days == lockPeriod2) {
                pool.RewardsTokenAddress.safeTransfer(msg.sender, yield);
                pool.ContractAddress.safeTransferFrom(msg.sender, address(this), _lpTokenAmount);
                provider[_pid][msg.sender] = LiquidityProviders (
                    msg.sender, 
                    block.number.add(periodCalc.mul(lockPeriod2)), 
                    _lpTokenAmount.add(p.LockedAmount), 
                    lockPeriod2, 
                    p.UserBP.add(p.UserBP >= pool.maxPoolBP ? 0 : pool.compYield2),
                    p.TotalRewardsPaid.add(yield)
                );
                pool.TotalRewardsPaidByPool = pool.TotalRewardsPaidByPool.add(yield);
                pool.TotalLPTokensLocked = pool.TotalLPTokensLocked.add(_lpTokenAmount);
            } else revert("LiquidityMining: Incompatible Lock Period");
        } else if (_lpTokenAmount == 0) {
            if(p.Days == lockPeriod0) {
                pool.RewardsTokenAddress.safeTransfer(msg.sender, yield);
                provider[_pid][msg.sender] = LiquidityProviders (
                    msg.sender, 
                    block.number.add(periodCalc.mul(lockPeriod0)), 
                    p.LockedAmount, 
                    lockPeriod0, 
                    p.UserBP.add(p.UserBP >= pool.maxPoolBP ? 0 : pool.compYield0),
                    p.TotalRewardsPaid.add(yield)
                );
                pool.TotalRewardsPaidByPool = pool.TotalRewardsPaidByPool.add(yield);
            } else if (p.Days == lockPeriod1) {
                pool.RewardsTokenAddress.safeTransfer(msg.sender, yield);
                provider[_pid][msg.sender] = LiquidityProviders (
                    msg.sender, 
                    block.number.add(periodCalc.mul(lockPeriod1)), 
                    p.LockedAmount, 
                    lockPeriod1, 
                    p.UserBP.add(p.UserBP >= pool.maxPoolBP ? 0 : pool.compYield1),
                    p.TotalRewardsPaid.add(yield)
                );
                pool.TotalRewardsPaidByPool = pool.TotalRewardsPaidByPool.add(yield);
            } else if (p.Days == lockPeriod2) {
                provider[_pid][msg.sender] = LiquidityProviders (
                    msg.sender, 
                    block.number.add(periodCalc.mul(lockPeriod2)), 
                    p.LockedAmount, 
                    lockPeriod2, 
                    p.UserBP.add(p.UserBP >= pool.maxPoolBP ? 0 : pool.compYield2),
                    p.TotalRewardsPaid.add(yield)
                );
                pool.TotalRewardsPaidByPool = pool.TotalRewardsPaidByPool.add(yield);
            }else revert("LiquidityMining: Incompatible Lock Period");
        }else revert("LiquidityMining: ?" );
    }

    //function wdAY 
    
    //-------Movement Functions---------------------

    
    function moveERC20(address _ERC20, address _dest, uint _ERC20Amount) public {
        require(hasRole(_MOVE, msg.sender));
        IERC20(_ERC20).safeTransfer(_dest, _ERC20Amount);
        emit ERC20Movement (
            msg.sender,
            _dest,
            _ERC20Amount,
            block.number
        );

    }

    function ethRescue(address payable _dest, uint _etherAmount) public {
        require(hasRole(_RESCUE, msg.sender));
        _dest.transfer(_etherAmount);
        emit ETHRescued (
            msg.sender,
            _dest,
            _etherAmount,
            block.number
        );
    }
    
}