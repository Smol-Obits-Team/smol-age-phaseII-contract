//SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { Lib } from "./library/Lib.sol";
import { SafeTransferLib } from "solady/src/utils/SafeTransferLib.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {
    Initializable
} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {
    ReentrancyGuardUpgradeable
} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import { BalanceIsInsufficient } from "./library/Error.sol";
import { Ownable } from "solady/src/auth/Ownable.sol";

contract Pits is Initializable, Ownable, ReentrancyGuardUpgradeable {
    IERC20 public bones;
    uint256 public bonesStaked;

    uint256 public timeOut;

    uint256 public totalDaysOff;

    uint256 public minimumPercent;

    mapping(address => uint256) private balance;
    mapping(uint256 => uint256) private trackDaysOff;

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
        /**
         * The balance before was greater than the minimum
         * and now it is smaller than it
         */

        SafeTransferLib.safeTransfer(address(bones), msg.sender, _amount);
        emit RemoveBonesFromYard(msg.sender, _amount);
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

    event StakeBonesInYard(address indexed owner, uint256 indexed amount);
    event RemoveBonesFromYard(address indexed owner, uint256 indexed amount);
}
