// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "hardhat/console.sol";
import {Lib} from "./library/Lib.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Pits {
    IERC20 public bones;
    uint256 private bonesStaked;

    uint256 private timeOut;

    uint256 private totalDaysOff;

    mapping(address => uint256) private balance;
    mapping(uint256 => uint256) private trackDaysOff;

    constructor(address _bones) {
        bones = IERC20(_bones);
    }

    function stakeBonesInYard(uint256 _amount) external {
        if (bones.balanceOf(msg.sender) < _amount)
            revert Lib.BalanceIsInsufficient();
        uint256 bonesBalance = bonesStaked;
        bones.transferFrom(msg.sender, address(this), _amount);
        balance[msg.sender] += _amount;
        bonesStaked += _amount;
        if (bonesBalance < minimumBonesRequired() && validation()) {
            uint256 daysOut;
            timeOut == 0 ? daysOut = 0 : daysOut =
                (block.timestamp - timeOut) /
                1 days;
            trackDaysOff[timeOut] = daysOut;
            totalDaysOff += daysOut;
        }
    }

    function getTotalDaysOff() external view returns (uint256) {
        return totalDaysOff;
    }

    function getDaysOff(uint256 _timestamp) external view returns (uint256) {
        return trackDaysOff[_timestamp];
    }

    /**
     * timestamp = dayOff[timestamp]✅ + unknowdays +currDaysOff✅
     * unknowdays = totalDaysOff - (currTimestamp - timestamp) -(timestamp - initialTime)
     * note some of the 👆 are needed in days
     * start----stop----start----stop----start----stop----start----stop
     * 0---------3-------5---
     */
    /**
     * (str - stp) + (str - stp) + (str - stp) => convert str - stp to 1/any amount days
     * after check str = block.timestamp
     * after check stp = block.timestamp
     *
     * diff = ? days
     * mapping(str => days?)  => when they enter we mark their str time yeah
     * note for the str below is for the neandersmols struct
     * if timeBelowMinimum is str we see a reward variable that is set to the
     * reward gotten when stake is below 30% and we return that
     * Another one is if timeBelowMinimum is str we just sub those days from the reward
     * else if timeBelowMinimum is not str i.e now greater, we add the time of the initial
     * str of the token and calculate that of the current with time off
     * or after the end of a certain cycle you add the days off and use calculation
     * to check the period off
     */

    function removeBonesFromYard(uint256 _amount) external {
        if (_amount > balance[msg.sender]) revert();
        uint256 bonesBalance = bonesStaked;
        balance[msg.sender] -= _amount;
        bonesStaked -= _amount;
        /**
         * The balance before was greater than the minimum
         * and now it is smaller than it
         */
        if (
            bonesBalance >= minimumBonesRequired() &&
            bonesStaked < (bones.totalSupply() * 3) / 10
        ) timeOut = block.timestamp;

        if (!bones.transfer(msg.sender, _amount)) revert Lib.TransferFailed();
    }

    function minimumBonesRequired() internal view returns (uint256) {
        return (bones.totalSupply() * 3) / 10;
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
        return bonesStaked >= (bones.totalSupply() * 3) / 10;
    }
}
