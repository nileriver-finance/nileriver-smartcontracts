// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/GSN/Context.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import "./interfaces/IStrategy.sol";

contract NileRiverBank is ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // governance
    address public operator; // should be an at least 6h timelock

    // flags
    bool public initialized = false;

    // Info of each user.
    struct UserInfo {
        uint256 shares; // How many LP tokens the user has provided.
        mapping(uint256 => uint256) rewardDebt; // Reward debt. See explanation below.
        uint256 lastStakeTime;
        uint256 totalDeposit;
        uint256 totalWithdraw;
    }

    struct PoolInfo {
        IERC20 want; // Address of the want token.
        uint256 allocPoint; // How many allocation points assigned to this pool. BDO to distribute per block.
        uint256 lastRewardTime; // Last block number that reward distribution occurs.
        mapping(uint256 => uint256) accRewardPerShare; // Accumulated rewardPool per share, times 1e18.
        address strategy; // Strategy address that will auto compound want tokens
        uint256 earlyWithdrawFee; // 10000
        uint256 earlyWithdrawTime; // 10000
    }

    // Info of each rewardPool funding.
    struct RewardPoolInfo {
        address rewardToken; // Address of rewardPool token contract.
        uint256 rewardPerSecond; // Reward token amount to distribute per block.
        uint256 totalPaidRewards;
    }

    uint256 public startTime = 1635417737;

    PoolInfo[] public poolInfo; // Info of each pool.
    mapping(uint256 => mapping(address => UserInfo)) public userInfo; // Info of each user that stakes LP tokens.
    RewardPoolInfo[] public rewardPoolInfo;
    uint256 public totalAllocPoint = 0; // Total allocation points. Must be the sum of all allocation points in all pools.
    uint256 public unstakingFrozenTime = 1 hours;

    address public timelock = address(0x0000000000000000000000000000000000000000); // 6h timelock

    /* =================== Added variables (need to keep orders for proxy to work) =================== */
    mapping(address => bool) public whitelistedContract;
    mapping(address => bool) public whitelisted;
    mapping(uint256 => bool) public stopRewardPool;
    mapping(uint256 => bool) public pausePool;

    /* ========== EVENTS ========== */

    event Initialized(address indexed executor, uint256 at);
    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event RewardPaid(uint256 indexed rewardPid, address indexed token, address indexed user, uint256 amount);

    function initialize() public notInitialized {
        initialized = true;
        operator = msg.sender;
        emit Initialized(msg.sender, block.timestamp);
    }

    modifier onlyOperator() {
        require(operator == msg.sender, "NileRiverBank: caller is not the operator");
        _;
    }

    modifier onlyTimelock() {
        require(timelock == msg.sender, "NileRiverBank: caller is not timelock");
        _;
    }

    modifier notInitialized() {
        require(!initialized, "NileRiverBank: already initialized");
        _;
    }

    modifier notContract() {
        if (!whitelistedContract[msg.sender]) {
            uint256 size;
            address addr = msg.sender;
            assembly {
                size := extcodesize(addr)
            }
            require(size == 0, "contract not allowed");
            require(tx.origin == msg.sender, "contract not allowed");
        }
        _;
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    function addVault(uint256 _allocPoint, IERC20 _want, bool _withUpdate, address _strategy, uint256 _earlyWithdrawFee, uint256 _earlyWithdrawTime) public onlyOperator {
        if (_withUpdate) {
            massUpdatePools();
        }
        uint256 _lastRewardTime = block.timestamp > startTime ? block.timestamp : startTime;
        totalAllocPoint = totalAllocPoint.add(_allocPoint);
        poolInfo.push(
            PoolInfo({
                want: _want,
                allocPoint: _allocPoint,
                lastRewardTime: _lastRewardTime,
                strategy : _strategy,
                earlyWithdrawFee: _earlyWithdrawFee,
                earlyWithdrawTime: _earlyWithdrawTime
            }));
    }

    // Update the given pool's reward allocation point. Can only be called by the owner.
    function setAllocPoint(uint256 _pid, uint256 _allocPoint) public onlyOperator {
        massUpdatePools();
        totalAllocPoint = totalAllocPoint.sub(poolInfo[_pid].allocPoint).add(_allocPoint);
        poolInfo[_pid].allocPoint = _allocPoint;
    }

    function setEarlyWithdrawFee(uint256 _pid, uint256 _earlyWithdrawFee) public onlyOperator {
        poolInfo[_pid].earlyWithdrawFee = _earlyWithdrawFee;
    }

    function setEarlyWithdrawTime(uint256 _pid, uint256 _earlyWithdrawTime) public onlyOperator {
        poolInfo[_pid].earlyWithdrawTime = _earlyWithdrawTime;
    }

    function rewardPoolLength() external view returns (uint256) {
        return rewardPoolInfo.length;
    }

    function addRewardPool(address _rewardToken, uint256 _rewardPerSecond) public nonReentrant onlyOperator {
        require(rewardPoolInfo.length <= 16, "NileRiverBank: Reward pool length > 16");
        massUpdatePools();
        rewardPoolInfo.push(RewardPoolInfo({
            rewardToken : _rewardToken,
            rewardPerSecond : _rewardPerSecond,
            totalPaidRewards : 0
            }));
    }

    function updateRewardToken(uint256 _rewardPid, address _rewardToken, uint256 _rewardPerSecond) external nonReentrant onlyOperator {
        RewardPoolInfo storage rewardPool = rewardPoolInfo[_rewardPid];
        require(_rewardPid >= 2, "core reward pool");
        require(rewardPool.rewardPerSecond == 0, "old pool still running");
        massUpdatePools();
        rewardPool.rewardToken = _rewardToken;
        rewardPool.rewardPerSecond = _rewardPerSecond;
        rewardPool.totalPaidRewards = 0;
    }

    function updateRewardPerSecond(uint256 _rewardPid, uint256 _rewardPerSecond) external nonReentrant onlyOperator {
        massUpdatePools();
        RewardPoolInfo storage rewardPool = rewardPoolInfo[_rewardPid];
        rewardPool.rewardPerSecond = _rewardPerSecond;
    }

    function setUnstakingFrozenTime(uint256 _unstakingFrozenTime) external nonReentrant onlyOperator {
        require(_unstakingFrozenTime <= 7 days, "NileRiverBank: !safe - dont lock for too long");
        unstakingFrozenTime = _unstakingFrozenTime;
    }

    // Return reward multiplier over the given _from to _to block.
    function getMultiplier(uint256 _from, uint256 _to) public pure returns (uint256) {
        return _to.sub(_from);
    }

    // View function to see pending reward on frontend.
    function pendingReward(uint256 _pid, uint256 _rewardPid, address _user) external view returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 _accRewardPerShare = pool.accRewardPerShare[_rewardPid];
        uint256 sharesTotal = IStrategy(pool.strategy).sharesTotal();
        if (block.timestamp > pool.lastRewardTime && sharesTotal != 0) {
            uint256 _multiplier = getMultiplier(pool.lastRewardTime, block.timestamp);
            uint256 _rewardPerSecond = rewardPoolInfo[_rewardPid].rewardPerSecond;
            uint256 _reward = _multiplier.mul(_rewardPerSecond).mul(pool.allocPoint).div(totalAllocPoint);
            _accRewardPerShare = _accRewardPerShare.add(_reward.mul(1e18).div(sharesTotal));
        }
        return user.shares.mul(_accRewardPerShare).div(1e18).sub(user.rewardDebt[_rewardPid]);
    }

    // View function to see staked Want tokens on frontend.
    function stakedWantTokens(uint256 _pid, address _user) external view returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];

        uint256 sharesTotal = IStrategy(pool.strategy).sharesTotal();
        uint256 wantLockedTotal = IStrategy(poolInfo[_pid].strategy).wantLockedTotal();
        if (sharesTotal == 0) {
            return 0;
        }
        return user.shares.mul(wantLockedTotal).div(sharesTotal);
    }

    // Update reward variables for all pools. Be careful of gas spending!
    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        if (address(pool.want) == address(0)) {
            return;
        }
        if (block.timestamp <= pool.lastRewardTime) {
            return;
        }
        uint256 sharesTotal = IStrategy(pool.strategy).sharesTotal();
        if (sharesTotal == 0) {
            pool.lastRewardTime = block.timestamp;
            return;
        }
        uint256 multiplier = getMultiplier(pool.lastRewardTime, block.timestamp);
        if (multiplier <= 0) {
            return;
        }
        uint256 _rewardPoolLength = rewardPoolInfo.length;
        for (uint256 _rewardPid = 0; _rewardPid < _rewardPoolLength; ++_rewardPid) {
            uint256 _rewardPerSecond = rewardPoolInfo[_rewardPid].rewardPerSecond;
            uint256 _reward = multiplier.mul(_rewardPerSecond).mul(pool.allocPoint).div(totalAllocPoint);
            pool.accRewardPerShare[_rewardPid] = pool.accRewardPerShare[_rewardPid].add(_reward.mul(1e18).div(sharesTotal));
            pool.lastRewardTime = block.timestamp;
        }
    }

    function _getReward(uint256 _pid) internal {
        PoolInfo storage _pool = poolInfo[_pid];
        UserInfo storage _user = userInfo[_pid][msg.sender];
        uint256 _rewardPoolLength = rewardPoolInfo.length;
        for (uint256 _rewardPid = 0; _rewardPid < _rewardPoolLength; ++_rewardPid) {
            if (!stopRewardPool[_rewardPid]) {
                uint256 _pending = _user.shares.mul(_pool.accRewardPerShare[_rewardPid]).div(1e18).sub(_user.rewardDebt[_rewardPid]);
                if (_pending > 0) {
                    RewardPoolInfo storage rewardPool = rewardPoolInfo[_rewardPid];
                    address _rewardToken = rewardPool.rewardToken;
                    safeRewardTransfer(_rewardToken, msg.sender, _pending);
                    rewardPool.totalPaidRewards = rewardPool.totalPaidRewards.add(_pending);
                    emit RewardPaid(_rewardPid, _rewardToken, msg.sender, _pending);
                }
            }
        }
    }

    function _checkStrategyBalanceAfterDeposit(address _strategy, uint256 _depositAmount, uint256 _oldInFarmBalance, uint256 _oldTotalBalance) internal view {
        require(_oldInFarmBalance + _depositAmount <= IStrategy(_strategy).inFarmBalance(), "Short of strategy infarm balance: need audit!");
        require(_oldTotalBalance + _depositAmount <= IStrategy(_strategy).totalBalance(), "Short of strategy total balance: need audit!");
    }

    function _checkStrategyBalanceAfterWithdraw(address _strategy, uint256 _withdrawAmount, uint256 _oldInFarmBalance, uint256 _oldTotalBalance) internal view {
        require(_oldInFarmBalance <= _withdrawAmount + IStrategy(_strategy).inFarmBalance(), "Short of strategy infarm balance: need audit!");
        require(_oldTotalBalance <= _withdrawAmount + IStrategy(_strategy).totalBalance(), "Short of strategy total balance: need audit!");
    }

    // Want tokens moved from user -> BDOFarm (BDO allocation) -> Strat (compounding)
    function deposit(uint256 _pid, uint256 _wantAmt) public nonReentrant notContract {
        require(!pausePool[_pid], "paused");
        updatePool(_pid);
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];

        if (user.shares > 0) {
            _getReward(_pid);
        }
        if (_wantAmt > 0) {
            IERC20 _want = pool.want;
            address _strategy = pool.strategy;
            uint256 _before = _want.balanceOf(address(this));
            _want.safeTransferFrom(address(msg.sender), address(this), _wantAmt);
            uint256 _after = _want.balanceOf(address(this));
            _wantAmt = _after - _before; // fix issue of deflation token
            _want.safeIncreaseAllowance(_strategy, _wantAmt);

            uint256 sharesAdded;
            {
                uint256 _oldInFarmBalance = IStrategy(_strategy).inFarmBalance();
                uint256 _oldTotalBalance = IStrategy(_strategy).totalBalance();
                sharesAdded = IStrategy(_strategy).deposit(msg.sender, _wantAmt);
                _checkStrategyBalanceAfterDeposit(_strategy, _wantAmt, _oldInFarmBalance, _oldTotalBalance);
            }

            user.shares = user.shares.add(sharesAdded);
            user.totalDeposit = user.totalDeposit.add(_wantAmt);
            user.lastStakeTime = block.timestamp;
        }
        uint256 _rewardPoolLength = rewardPoolInfo.length;
        for (uint256 _rewardPid = 0; _rewardPid < _rewardPoolLength; ++_rewardPid) {
            user.rewardDebt[_rewardPid] = user.shares.mul(pool.accRewardPerShare[_rewardPid]).div(1e18);
        }
        emit Deposit(msg.sender, _pid, _wantAmt);
    }

    function unfrozenStakeTime(uint256 _pid, address _account) public view returns (uint256) {
        return (whitelisted[_account]) ? userInfo[_pid][_account].lastStakeTime : userInfo[_pid][_account].lastStakeTime + unstakingFrozenTime;
    }

    function earlyWithdrawTimeEnd(uint256 _pid, address _account) public view returns (uint256) {
        return (whitelisted[_account]) ? userInfo[_pid][_account].lastStakeTime : userInfo[_pid][_account].lastStakeTime + poolInfo[_pid].earlyWithdrawTime;
    }

    // Withdraw LP tokens from MasterChef.
    function withdraw(uint256 _pid, uint256 _wantAmt) public nonReentrant notContract {
        require(!pausePool[_pid], "paused");
        updatePool(_pid);

        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];

        uint256 wantLockedTotal = IStrategy(poolInfo[_pid].strategy).wantLockedTotal();
        uint256 sharesTotal = IStrategy(poolInfo[_pid].strategy).sharesTotal();
        address _strategy = pool.strategy;

        require(user.shares > 0, "NileRiverBank: user.shares is 0");
        require(sharesTotal > 0, "NileRiverBank: sharesTotal is 0");

        _getReward(_pid);

        // Withdraw want tokens
        uint256 amount = user.shares.mul(wantLockedTotal).div(sharesTotal);
        if (_wantAmt > amount) {
            _wantAmt = amount;
        }
        if (_wantAmt > 0) {
            uint256 sharesRemoved;
            {
                uint256 _oldInFarmBalance = IStrategy(_strategy).inFarmBalance();
                uint256 _oldTotalBalance = IStrategy(_strategy).totalBalance();
                sharesRemoved = IStrategy(_strategy).withdraw(msg.sender, _wantAmt);
                _checkStrategyBalanceAfterWithdraw(_strategy, _wantAmt, _oldInFarmBalance, _oldTotalBalance);
            }

            if (sharesRemoved > user.shares) {
                user.shares = 0;
            } else {
                user.shares = user.shares.sub(sharesRemoved);
            }

            uint256 wantBal = IERC20(pool.want).balanceOf(address(this));
            if (wantBal < _wantAmt) {
                _wantAmt = wantBal;
            }

            if (_wantAmt > 0) {
                require(whitelisted[msg.sender] || block.timestamp >= unfrozenStakeTime(_pid, msg.sender), "NileRiverBank: frozen");
                if (block.timestamp >= earlyWithdrawTimeEnd(_pid, msg.sender)) {
                    pool.want.safeTransfer(address(msg.sender), _wantAmt);
                } else {
                    uint256 fee = _wantAmt.mul(poolInfo[_pid].earlyWithdrawFee.div(10000));
                    uint256 userReceivedAmount = _wantAmt.sub(fee);
                    pool.want.safeTransfer(operator, fee);
                    pool.want.safeTransfer(address(msg.sender), userReceivedAmount);
                }
                user.totalWithdraw = user.totalWithdraw.add(_wantAmt);
            }
        }
        uint256 _rewardPoolLength = rewardPoolInfo.length;
        for (uint256 _rewardPid = 0; _rewardPid < _rewardPoolLength; ++_rewardPid) {
            user.rewardDebt[_rewardPid] = user.shares.mul(pool.accRewardPerShare[_rewardPid]).div(1e18);
        }
        emit Withdraw(msg.sender, _pid, _wantAmt);
    }

    function withdrawAll(uint256 _pid)  external notContract {
        withdraw(_pid, uint256(-1));
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) public notContract nonReentrant {
        require(!pausePool[_pid], "paused");

        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];

        uint256 wantLockedTotal = IStrategy(poolInfo[_pid].strategy).wantLockedTotal();
        uint256 sharesTotal = IStrategy(poolInfo[_pid].strategy).sharesTotal();
        uint256 amount = user.shares.mul(wantLockedTotal).div(sharesTotal);

        IStrategy(poolInfo[_pid].strategy).withdraw(msg.sender, amount);
        if (amount > 0) {
            require(whitelisted[msg.sender] || block.timestamp >= unfrozenStakeTime(_pid, msg.sender), "NileRiverBank: frozen");
            if (block.timestamp >= earlyWithdrawTimeEnd(_pid, msg.sender)) {
                pool.want.safeTransfer(address(msg.sender), amount);
            } else {
                uint256 fee = amount.mul(poolInfo[_pid].earlyWithdrawFee.div(10000));
                uint256 userReceivedAmount = amount.sub(fee);
                pool.want.safeTransfer(operator, fee);
                pool.want.safeTransfer(address(msg.sender), userReceivedAmount);
            }
            user.totalWithdraw = user.totalWithdraw.add(amount);
        }

        emit EmergencyWithdraw(msg.sender, _pid, amount);
        user.shares = 0;
        uint256 _rewardPoolLength = rewardPoolInfo.length;
        for (uint256 _rewardPid = 0; _rewardPid < _rewardPoolLength; ++_rewardPid) {
            user.rewardDebt[_rewardPid] = 0;
        }
    }

    // Safe reward token transfer function, just in case if rounding error causes pool to not have enough
    function safeRewardTransfer(address _rewardToken, address _to, uint256 _amount) internal {
        uint256 _bal = IERC20(_rewardToken).balanceOf(address(this));
        if (_amount > _bal) {
            IERC20(_rewardToken).transfer(_to, _bal);
        } else {
            IERC20(_rewardToken).transfer(_to, _amount);
        }
    }

    function setWhitelisted(address _account, bool _whitelisted) external nonReentrant onlyOperator {
        whitelisted[_account] = _whitelisted;
    }

    function setWhitelistedContract(address _contract, bool _whitelisted) external onlyOperator {
        whitelistedContract[_contract] = _whitelisted;
    }

    function setStopRewardPool(uint256 _pid, bool _stopRewardPool) external nonReentrant onlyOperator {
        stopRewardPool[_pid] = _stopRewardPool;
    }

    function setPausePool(uint256 _pid, bool _pausePool) external nonReentrant onlyOperator {
        pausePool[_pid] = _pausePool;
    }

    /* ========== EMERGENCY ========== */

    function setTimelock(address _timelock) external {
        require(msg.sender == timelock || (timelock == address(0) && msg.sender == operator), "NileRiverBank: !authorised");
        timelock = _timelock;
    }

    function inCaseTokensGetStuck(address _token, uint256 _amount, address _to) external onlyTimelock {
        IERC20(_token).safeTransfer(_to, _amount);
    }

    event ExecuteTransaction(address indexed target, uint256 value, string signature, bytes data);

    /**
     * @dev This is from Timelock contract.
     */
    function executeTransaction(address target, uint256 value, string memory signature, bytes memory data) external onlyTimelock returns (bytes memory) {
        bytes memory callData;

        if (bytes(signature).length == 0) {
            callData = data;
        } else {
            callData = abi.encodePacked(bytes4(keccak256(bytes(signature))), data);
        }

        // solium-disable-next-line security/no-call-value
        (bool success, bytes memory returnData) = target.call{value : value}(callData);
        require(success, "NileRiver::executeTransaction: Transaction execution reverted.");

        emit ExecuteTransaction(target, value, signature, data);

        return returnData;
    }
}
