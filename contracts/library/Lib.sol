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
        address _pits
    ) public view returns (uint256) {
        if (_token.lockPeriod == 0) return 0;
        uint256 rewardRate = getRewardRate(_token.lockPeriod);

        uint256 time = (block.timestamp - _token.lastRewardTime) / 1 days;
        return
            calculateFinalReward(_token, _pits, rewardRate * time) * 10 ** 18;
    }

    function calculateFinalReward(
        DevelopmentGround memory token,
        address _pits,
        uint256 _amount
    ) internal view returns (uint256) {
        uint256 amount;
        if (token.currentLockPeriod != IPits(_pits).getTimeOut()) {
            uint256 howLong = (block.timestamp - IPits(_pits).getTimeOut()) /
                1 days;
            amount =
                (IPits(_pits).getTotalDaysOff() -
                    IPits(_pits).getDaysOff(token.currentLockPeriod) +
                    howLong) *
                10;
        }
        if (token.currentLockPeriod == 0) {
            uint256 off;
            IPits(_pits).getTimeOut() != 0
                ? off = (block.timestamp - IPits(_pits).getTimeOut()) / 1 days
                : 0;
            if (IPits(_pits).validation()) off = IPits(_pits).getTotalDaysOff();
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
        DevelopmentGround storage token,
        address _neandersmol,
        address _pits,
        uint256 _tokenId,
        uint256 _lockTime,
        Grounds _ground
    ) external {
        if (!IPits(_pits).validation()) revert DevelopmentGroundIsLocked();

        if (INeandersmol(_neandersmol).getCommonSense(_tokenId) < 100)
            revert CsIsBellowHundred();
        if (INeandersmol(_neandersmol).ownerOf(_tokenId) != msg.sender)
            revert NotYourToken();
        if (!lockTimeExists(_lockTime)) revert InvalidLockTime();
        INeandersmol(_neandersmol).transferFrom(
            msg.sender,
            address(this),
            _tokenId
        );
        token.owner = msg.sender;
        token.lockTime = uint128(block.timestamp);
        token.lockPeriod = uint48(_lockTime);
        token.lastRewardTime = uint128(block.timestamp);
        token.ground = _ground;
        token.currentLockPeriod = IPits(_pits).getTimeOut();
    }

    function lockTimeExists(uint256 _lockTime) internal pure returns (bool) {
        return
            _lockTime == 50 days ||
            _lockTime == 100 days ||
            _lockTime == 150 days;
    }
}
