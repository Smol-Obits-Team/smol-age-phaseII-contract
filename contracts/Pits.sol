//SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { Lib } from "./library/Lib.sol";
import { SafeTransferLib } from "solady/src/utils/SafeTransferLib.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IERC1155 } from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {
    Initializable
} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {
    ReentrancyGuardUpgradeable
} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {
    BalanceIsInsufficient,
    ActiveStakeError,
    NoActiveStakeError
} from "./library/Error.sol";
import { Ownable } from "solady/src/auth/Ownable.sol";

contract Pits is Initializable, Ownable, ReentrancyGuardUpgradeable {
    IERC20 public bones;
    uint256 public bonesStaked;

    uint256 public timeOut;

    uint256 public totalDaysOff;

    uint256 public minimumPercent;

    mapping(address => uint256) private balance;
    mapping(uint256 => uint256) private trackDaysOff;

    mapping(address => bool) public staked;

    address public pass;
    uint256 public passBoost;

    uint256 public constant PASS_ID = 0;

    function initialize(address _bones) external initializer {
        _initializeOwner(msg.sender);
        bones = IERC20(_bones);
        minimumPercent = 3;
        __ReentrancyGuard_init();
    }

    function stakeBonesInYard(uint256 _amount) external nonReentrant {
        if (bones.balanceOf(msg.sender) < _amount)
            revert BalanceIsInsufficient();
        SafeTransferLib.safeTransferFrom(
            address(bones),
            msg.sender,
            address(this),
            _amount
        );
        balance[msg.sender] += _amount;
        bonesStaked += _amount;

        emit StakeBonesInYard(msg.sender, _amount);
    }

    function removeBonesFromYard(uint256 _amount) external nonReentrant {
        if (_amount > balance[msg.sender]) revert BalanceIsInsufficient();
        balance[msg.sender] -= _amount;
        bonesStaked -= _amount;
        SafeTransferLib.safeTransfer(address(bones), msg.sender, _amount);
        emit RemoveBonesFromYard(msg.sender, _amount);
    }

    function stakePass() external {
        if (staked[msg.sender]) revert ActiveStakeError();
        staked[msg.sender] = true;
        IERC1155(pass).safeTransferFrom(
            msg.sender,
            address(this),
            PASS_ID,
            1,
            ""
        );

        emit StakePass(msg.sender);
    }

    function unstakePass() external {
        if (!staked[msg.sender]) revert NoActiveStakeError();
        staked[msg.sender] = false;
        IERC1155(pass).safeTransferFrom(
            msg.sender,
            address(this),
            PASS_ID,
            1,
            ""
        );

        emit UnstakePass(msg.sender);
    }

    function getPassMultiplier(address _addr) external view returns (uint256) {
        return passBoost == 0 || !staked[_addr] ? 100 : passBoost;
    }

    function setPassAddress(address _pass) external onlyOwner {
        pass = _pass;
    }

    function setPassBoost(uint256 _passBoost) external onlyOwner {
        passBoost = _passBoost;
    }

    function setMinimumPercent(uint256 _minimumPercent) external onlyOwner {
        minimumPercent = _minimumPercent;
    }

    function getTotalDaysOff() external view returns (uint256) {
        return totalDaysOff;
    }

    function getDaysOff(uint256 _timestamp) external view returns (uint256) {
        return trackDaysOff[_timestamp];
    }

    function minimumBonesRequired() internal view returns (uint256) {
        return (bones.totalSupply() * minimumPercent) / 10;
    }

    function getBonesStaked(address _addr) external view returns (uint256) {
        return balance[_addr];
    }

    function getTimeOut() external view returns (uint256) {
        return timeOut;
    }

    function getTotalBonesStaked() external view returns (uint256) {
        return bonesStaked;
    }

    function validation() public view returns (bool) {
        return bonesStaked >= minimumBonesRequired();
    }

    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes calldata
    ) external pure returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    event StakeBonesInYard(address indexed owner, uint256 indexed amount);
    event RemoveBonesFromYard(address indexed owner, uint256 indexed amount);
    event StakePass(address indexed sender);
    event UnstakePass(address indexed sender);
}
