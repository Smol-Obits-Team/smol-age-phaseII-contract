// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Pits {
    IERC20 public bones;
    uint256 private bonesStaked;

    uint256 private timeBelowMinimum;
    uint256 private unlockTime;

    uint256 private timesOff;

    uint256 private constant TO_WEI = 10 ** 18;

    mapping(address => uint256) private balance;

    constructor(address _bones) {
        bones = IERC20(_bones);
    }

    function stakeBonesInYard(uint256 _amount) external {
        require(bones.balanceOf(msg.sender) >= _amount, "Balance is low");
        uint256 bonesBalance = bonesStaked;
        bones.transferFrom(msg.sender, address(this), _amount);
        balance[msg.sender] += _amount;
        bonesStaked += _amount;
        // if(bonesBalance > minimumBonesRequired())
    }

    /**
     * finalAmount = totalRewardFromOnSet - (rewardPerDay * TF)
     * how do we calculate all the days off??
     * T0 = (block.timestamp - LT0) /  1 days <==> This should only set if stake was >minimum then removed
     * T1 = (block.timestamp - LT1) /  1 days <==> This should only set if stake was >minimum the removed
     * daysOff = TF = T0 + T1 + ...... + Tn;
     * How to set the lock time at the correct interval??
     * To set LT0 after a certain removal that satisfies the condition, update the timestamp
     * if after adding more bones now > minimum
     * 0 -> 1 days <==> 10 default
     * 1 -> 3 days <==> 10 (3*10) - (10*2) -  2 days off
     * 3 -> 6 days <==> 40 (6*10) - (2*10)
     * 6 -> 8 days <==> 40 default -  2 days off
     * 8 -> 10 days <==> 60 (10*10) - (10*4)
     *
     */

    function daysOff() internal {
        uint256 timeOff = (block.timestamp - timeBelowMinimum) / 1 days;
        timesOff += timeOff;
    }

    function removeBonesFromYard(uint256 _amount) external {
        if (_amount > balance[msg.sender]) revert();
        uint256 bonesBalance = bonesStaked;
        balance[msg.sender] -= _amount;
        bonesStaked -= _amount;
        /**
         * initially the time is below minimum yeah?
         */
        if (bonesBalance >= minimumBonesRequired() && !validation()) {
            daysOff();
            timeBelowMinimum = block.timestamp;
        }
        require(bones.transfer(msg.sender, _amount));
    }

    function minimumBonesRequired() internal view returns (uint256) {
        return (bones.totalSupply() * 3) / 10;
    }

    function getBonesStaked(address _addr) external view returns (uint256) {
        return balance[_addr];
    }

    function getUnlockTime() external view returns (uint256) {
        return unlockTime;
    }

    function getTotalBonesStaked() external view returns (uint256) {
        return bonesStaked;
    }

    function validation() public view returns (bool) {
        return bonesStaked >= (bones.totalSupply() * 3) / 10;
    }

    function getTimeBelowMinimum() external view returns (uint256) {
        return timeBelowMinimum;
    }
}
