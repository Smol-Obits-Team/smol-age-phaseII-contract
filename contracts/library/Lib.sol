// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;
import {IPits} from "../interfaces/IPits.sol";
import {INeandersmol} from "../interfaces/INeandersmol.sol";

library Lib {
    error LengthsNotEqual();
    error DevelopmentGroundIsLocked();
    error CsIsBellowHundred();
    error NotYourToken();
    error InvalidLockTime();
    error InvalidTokenForThisJob();
    error CsToHigh();
    error CannotClaimNow();

    error BalanceIsInsufficient();
    error TokenNotInDevelopementGround();
    error WrongMultiple();
    error TransferFailed();
    error NeandersmolsIsLocked();
    error ZeroBalanceError();

    uint256 private constant INCREASE_RATE = 1;

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
        uint96 stakingTime;
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

    function timeLeftToLeaveCaveInDays(
        Caves memory cave
    ) external view returns (uint256) {
        if (cave.stakingTime == 0) return 0;
        return (block.timestamp - cave.stakingTime) / 1 days;
    }

    function getDevelopmentGroundBonesReward(
        DevelopmentGround memory _token,
        IPits _pits
    ) external view returns (uint256) {
        if (_token.lockPeriod == 0) return 0;
        uint256 rewardRate = getRewardRate(_token.lockPeriod);

        uint256 time = (block.timestamp - _token.lastRewardTime) / 1 days;
        return
            calculateFinalReward(_token, _pits, rewardRate * time) * 10 ** 18;
    }

    function calculatePrimarySkill(
        DevelopmentGround memory token,
        uint256 _tokenId,
        IPits _pits,
        mapping(uint256 => mapping(uint256 => uint256)) storage trackTime,
        mapping(uint256 => mapping(uint256 => uint256)) storage trackToken
    ) external view returns (uint256) {
        // make sure bones staked is more than 30% the total supply
        uint256 amount;
        for (uint256 i = 1; i <= token.amountPosition; ) {
            if (trackTime[_tokenId][i] == 0) {
                amount = 0;
            } else {
                uint256 time = (block.timestamp - trackTime[_tokenId][i]) /
                    1 days;
                uint256 stakedAmount = trackToken[_tokenId][
                    trackTime[_tokenId][i]
                ];
                amount += (INCREASE_RATE * time * stakedAmount * 10 ** 15);
            }
            unchecked {
                ++i;
            }
        }
        return calculateFinalReward(token, _pits, 11);
    }

    function calculateFinalReward(
        DevelopmentGround memory token,
        IPits _pits,
        uint256 _amount
    ) internal view returns (uint256) {
        uint256 amount;
        if (token.currentLockPeriod != _pits.getTimeOut()) {
            uint256 howLong = (block.timestamp - _pits.getTimeOut()) / 1 days;
            amount =
                (_pits.getTotalDaysOff() -
                    _pits.getDaysOff(token.currentLockPeriod) +
                    howLong) *
                10;
        }
        if (token.currentLockPeriod == 0) {
            uint256 off;
            _pits.getTimeOut() != 0
                ? off = (block.timestamp - _pits.getTimeOut()) / 1 days
                : 0;
            if (_pits.validation()) off = _pits.getTotalDaysOff();
            amount = off * 10;
        }
        return _amount - amount;
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
        if (_neandersmol.ownerOf(_tokenId) != msg.sender)
            revert Lib.NotYourToken();
        if (_neandersmol.getCommonSense(_tokenId) > 99) revert Lib.CsToHigh();
        if (!validateTokenId(_supplyId, _job))
            revert Lib.InvalidTokenForThisJob();
    }

    function validateTokenId(
        uint256 _tokenId,
        Jobs _job
    ) internal pure returns (bool res) {
        if (_job == Jobs.Digging) return _tokenId == 1;
        if (_job == Jobs.Foraging) return _tokenId == 2;
        if (_job == Jobs.Mining) return _tokenId == 3;
    }
}
