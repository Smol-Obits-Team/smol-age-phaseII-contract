//SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { IPits } from "../interfaces/IPits.sol";
import { DevelopmentGroundIsLocked } from "./Error.sol";

library Lib {
    function getDevGroundBonesReward(
        uint256 _lockPeriod,
        uint256 _lastRewardTime,
        IPits _pits
    ) internal view returns (uint256) {
        if (_lockPeriod == 0) return 0;
        uint256 rewardRate = getRewardRate(_lockPeriod);
        if (_lastRewardTime == 0) return 0;
        uint256 time = (block.timestamp - _lastRewardTime) / 1 days;
        if (time == 0) return 0;
        return ((rewardRate * 10 ** 18) + fetchBoost(msg.sender, _pits)) * time;
    }

    function calculatePrimarySkill(
        uint256 _bonesStaked,
        uint256 _amountPosition,
        uint256 _tokenId,
        IPits _pits,
        mapping(uint256 => mapping(uint256 => uint256)) storage trackTime,
        mapping(uint256 => mapping(uint256 => uint256)) storage trackToken
    ) internal view returns (uint256) {
        if (_bonesStaked == 0) return 0;
        uint256 amount;
        uint256 i = 1;
        for (; i <= _amountPosition; ) {
            uint256 time = (block.timestamp - trackTime[_tokenId][i]) / 1 days;
            uint256 stakedAmount = trackToken[_tokenId][trackTime[_tokenId][i]];
            amount += (time *
                (stakedAmount + (fetchBoost(msg.sender, _pits)) * 100));
            unchecked {
                ++i;
            }
        }

        return amount / 10 ** 4;
    }

    function fetchBoost(
        address _owner,
        IPits _pits
    ) internal view returns (uint256 a) {
        uint256 stakedBones = _pits.getBonesStaked(_owner);
        if (stakedBones < 5000 ether) return 0;
        if (stakedBones < 10000 ether) return 1 ether;
        else if (stakedBones < 20000 ether) return 1.5 ether;
        else if (stakedBones < 30000 ether) return 2 ether;
        else if (stakedBones < 40000 ether) return 2.5 ether;
        else if (stakedBones < 50000 ether) return 3 ether;
        else if (stakedBones < 100000 ether) return 3.5 ether;
        else if (stakedBones < 250000 ether) return 4 ether;
        else if (stakedBones < 500000 ether) return 4.5 ether;
        else if (stakedBones > 499999 ether) return 5 ether;
    }

    function getRewardRate(
        uint _lockTime
    ) internal pure returns (uint256 rewardRate) {
        if (_lockTime == 50 days) rewardRate = 10;
        if (_lockTime == 100 days) rewardRate = 50;
        if (_lockTime == 150 days) rewardRate = 100;
    }

    function pitsValidation(IPits _pits) internal view {
        if (!_pits.validation()) revert DevelopmentGroundIsLocked();
    }

    function removeItem(
        uint256[] storage _element,
        uint256 _removeElement
    ) internal {
        uint256 i;
        for (; i < _element.length; ) {
            if (_element[i] == _removeElement) {
                _element[i] = _element[_element.length - 1];
                _element.pop();
                break;
            }

            unchecked {
                ++i;
            }
        }
    }
}
