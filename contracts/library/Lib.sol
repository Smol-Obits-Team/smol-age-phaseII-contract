// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IPits} from "../interfaces/IPits.sol";
import {INeandersmol} from "../interfaces/INeandersmol.sol";
import {IBones} from "../interfaces/IBones.sol";

library Lib {
    error CsToHigh();
    error NotYourToken();
    error NotAuthorized();
    error WrongMultiple();
    error CannotClaimNow();
    error TransferFailed();
    error InvalidTokenId();
    error InvalidLockTime();
    error NoMoreAnimalsAllowed();
    error LengthsNotEqual();
    error ZeroBalanceError();
    error CsIsBellowHundred();
    error NeandersmolsIsLocked();
    error BalanceIsInsufficient();
    error InvalidTokenForThisJob();
    error DevelopmentGroundIsLocked();
    error TokenNotInDevelopmentGround();

    struct DevelopmentGround {
        address owner;
        uint48 lockPeriod;
        uint48 amountPosition;
        uint128 lockTime;
        uint128 lastRewardTime;
        uint256 bonesStaked;
        uint256 currentLockPeriod;
        Grounds ground;
    }

    struct LaborGround {
        address owner;
        uint32 lockTime;
        uint32 supplyId;
        uint32 animalId;
        Jobs job;
    }

    struct Caves {
        address owner;
        uint48 stakingTime;
        uint48 lastRewardTimestamp;
    }

    enum Jobs {
        Digging,
        Foraging,
        Mining
    }

    enum Grounds {
        Chambers,
        Garden,
        Battlefield
    }

    uint256 private constant MINIMUM_BONE_STAKE = 1000 * 10 ** 18;

    function getDevelopmentGroundBonesReward(
        uint256 _currentLockPeriod,
        uint256 _lockPeriod,
        uint256 _lastRewardTime,
        IPits _pits
    ) external view returns (uint256) {
        if (_lockPeriod == 0) return 0;
        uint256 rewardRate = getRewardRate(_lockPeriod);

        uint256 time = (block.timestamp - _lastRewardTime) / 1 days;

        return
            (rewardRate *
                time -
                calculateFinalReward(_currentLockPeriod, _pits)) * 10 ** 18;
    }

    // check if this can be fixed to reduce gas cost
    function calculatePrimarySkill(
        uint256 _bonesStaked,
        uint256 _amountPosition,
        uint256 _currentLockPeriod,
        uint256 _tokenId,
        IPits _pits,
        mapping(uint256 => mapping(uint256 => uint256)) storage trackTime,
        mapping(uint256 => mapping(uint256 => uint256)) storage trackToken
    ) external view returns (uint256) {
        // make sure bones staked is more than 30% the total supply
        if (_bonesStaked == 0) return 0;
        uint256 amount;
        for (uint256 i = 1; i <= _amountPosition; ) {
            uint256 time = (block.timestamp - trackTime[_tokenId][i]) / 1 days;
            uint256 stakedAmount = trackToken[_tokenId][trackTime[_tokenId][i]];
            amount += (time * stakedAmount);

            unchecked {
                ++i;
            }
        }

        return
            (amount -
                calculateFinalReward(_currentLockPeriod, _pits) *
                10 ** 20) / 10 ** 4;
    }

    function calculateFinalReward(
        uint256 _currentLockPeriod,
        IPits _pits
    ) internal view returns (uint256) {
        uint256 amount;

        if (_currentLockPeriod != _pits.getTimeOut()) {
            uint256 howLong = (block.timestamp - _pits.getTimeOut()) / 1 days;
            amount = (_pits.getTotalDaysOff() -
                _pits.getDaysOff(_currentLockPeriod) +
                howLong);
        }
        if (_currentLockPeriod == 0) {
            uint256 off;
            _pits.getTimeOut() != 0
                ? off = (block.timestamp - _pits.getTimeOut()) / 1 days
                : 0;
            if (_pits.validation()) off = _pits.getTotalDaysOff();
            amount = off;
        }
        return amount * 10;
    }

    function getRewardRate(
        uint _lockTime
    ) internal pure returns (uint256 rewardRate) {
        if (_lockTime == 50 days) rewardRate = 10;
        if (_lockTime == 100 days) rewardRate = 50;
        if (_lockTime == 150 days) rewardRate = 100;
    }

    function enterDevelopmentGround(
        INeandersmol _neandersmol,
        IPits _pits,
        uint256 _tokenId,
        uint256 _lockTime
    ) external view {
        if (!_pits.validation()) revert DevelopmentGroundIsLocked();
        if (_neandersmol.getCommonSense(_tokenId) < 100)
            revert CsIsBellowHundred();
        if (_neandersmol.ownerOf(_tokenId) != msg.sender) revert NotYourToken();
        if (!lockTimeExists(_lockTime)) revert InvalidLockTime();
    }

    function lockTimeExists(uint256 _lockTime) internal pure returns (bool) {
        return
            _lockTime == 50 days ||
            _lockTime == 100 days ||
            _lockTime == 150 days;
    }

    function enterLaborGround(
        INeandersmol _neandersmol,
        uint256 _tokenId,
        uint256 _supplyId,
        Jobs _job
    ) external view {
        if (_neandersmol.ownerOf(_tokenId) != msg.sender) revert NotYourToken();
        if (_neandersmol.getCommonSense(_tokenId) > 99) revert CsToHigh();
        if (!validateTokenId(_supplyId, _job)) revert InvalidTokenForThisJob();
    }

    function validateTokenId(
        uint256 _tokenId,
        Jobs _job
    ) internal pure returns (bool res) {
        if (_job == Jobs.Digging) return _tokenId == 1;
        if (_job == Jobs.Foraging) return _tokenId == 2;
        if (_job == Jobs.Mining) return _tokenId == 3;
    }

    function leaveDevelopmentGround(
        DevelopmentGround storage _devGround
    ) external view {
        DevelopmentGround memory devGround = _devGround;
        if (devGround.owner != msg.sender) revert NotYourToken();
        if (block.timestamp < devGround.lockTime + devGround.lockPeriod)
            revert NeandersmolsIsLocked();
    }

    function stakeBonesInDevelopmentGround(
        DevelopmentGround storage _devGround,
        IBones _bones,
        uint256 _amount
    ) external view {
        if (_bones.balanceOf(msg.sender) < _amount)
            revert BalanceIsInsufficient();
        if (_devGround.owner != msg.sender)
            revert TokenNotInDevelopmentGround();
        if (_amount % MINIMUM_BONE_STAKE != 0) revert WrongMultiple();
    }

    function bringInAnimalsToLaborGround(
        LaborGround storage _labor
    ) external view {
        if (_labor.owner != msg.sender) revert NotYourToken();
        if (_labor.animalId != 0) revert NoMoreAnimalsAllowed();
    }

    function removeAnimalsFromLaborGround(
        LaborGround storage _labor,
        uint256 _animalsId
    ) external view {
        if (_labor.owner != msg.sender && _labor.animalId != _animalsId + 1)
            revert Lib.NotYourToken();
    }
}
