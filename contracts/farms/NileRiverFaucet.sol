// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

contract NileRiverFaucet {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    address payable public governance;
    mapping(address => bool) public isFaucet;

    address public admin;
    uint256 public totalFaucetAmount;
    uint256 public totalFaucetReceivers;

    // flags
    uint256 private _locked = 0;
    bool public paused = false;

    struct PoolInfo {
        address faucetToken;
        uint256 amount;
    }

    PoolInfo[] public poolInfo;

    event FaucetSent(address indexed receiver, address indexed token, uint256 amount);

    constructor(uint256 _movrAmount) public {
        governance = msg.sender;
        add(address(0), _movrAmount);
    }

    modifier lock() {
        require(_locked == 0, "LOCKED");
        _locked = 1;
        _;
        _locked = 0;
    }

    modifier onlyGovernance() {
        require(msg.sender == governance, "!governance");
        _;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "!admin");
        _;
    }

    modifier notPaused() {
        require(!paused, "paused");
        _;
    }

    function setGovernance(address payable _governance) external onlyGovernance {
        require(_governance != address(0), "zero");
        governance = _governance;
    }

    function setAdmin(address payable _admin) external onlyGovernance {
        require(_admin != address(0), "zero");
        admin = _admin;
    }

    function pause() external onlyGovernance {
        paused = true;
    }

    function unpause() external onlyGovernance {
        paused = false;
    }

    function checkPoolDuplicate(address _faucetToken) internal view {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            require(poolInfo[pid].faucetToken != _faucetToken, "add: existing pool?");
        }
    }

    function add(address _faucetToken, uint256 _amount) public onlyGovernance {
        checkPoolDuplicate(_faucetToken);
        poolInfo.push(
            PoolInfo({
            faucetToken : _faucetToken,
            amount : _amount
            })
        );
    }

    function setPoolFaucetToken(uint256 _pid, address _faucetToken) public onlyGovernance {
        require(_pid > 0, "Cant update pool 0 (MOVR)");
        PoolInfo storage pool = poolInfo[_pid];
        pool.faucetToken = _faucetToken;
    }

    function setPoolAmount(uint256 _pid, uint256 _amount) public onlyGovernance {
        PoolInfo storage pool = poolInfo[_pid];
        pool.amount = _amount;
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    function faucet(address payable _receiver) external onlyAdmin lock notPaused {
        require(!isFaucet[_receiver], "already faucet");
        uint256 _movrAmount = poolInfo[0].amount;
        require(address(this).balance >= _movrAmount, "contract balance is not enough");
        isFaucet[_receiver] = true;
        totalFaucetAmount = totalFaucetAmount.add(_movrAmount);
        totalFaucetReceivers = totalFaucetReceivers.add(1);
        _receiver.transfer(_movrAmount);
        emit FaucetSent(_receiver, address(0), _movrAmount);
        uint256 length = poolInfo.length;
        for (uint256 i = 1; i < length; i++) {
            PoolInfo memory pool = poolInfo[i];
            _safeTokenTransfer(pool.faucetToken, _receiver, pool.amount);
        }
    }

    function _safeTokenTransfer(address _token, address _receiver, uint256 _amount) internal {
        uint256 _bal = IERC20(_token).balanceOf(address(this));
        if (_bal > 0) {
            if (_amount > _bal) {
                IERC20(_token).safeTransfer(_receiver, _bal);
                emit FaucetSent(_receiver, _token, _bal);
            } else {
                IERC20(_token).safeTransfer(_receiver, _amount);
                emit FaucetSent(_receiver, _token, _amount);
            }
        }
    }

    function isRunning() external view returns (bool) {
        return !paused && address(this).balance >= poolInfo[0].amount;
    }

    function governanceRecoverUnsupported(address _token, address _to, uint256 _amount) external onlyGovernance {
        IERC20(_token).safeTransfer(_to, _amount);
    }

    function governanceRecoverMOVR() external onlyGovernance {
        governance.transfer(address(this).balance);
    }

    /**
     * @dev fallback function ***DO NOT OVERRIDE***
     */
    receive() external payable {
    }
}
