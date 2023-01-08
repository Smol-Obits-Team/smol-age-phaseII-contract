// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "hardhat/console.sol";
import {IPits} from "./interfaces/IPits.sol";
import {IToken} from "./interfaces/IToken.sol";
import {INeandersmol} from "./interfaces/INeandersmol.sol";

/**
 * Development Ground - Skilled Neandersmol i.e cs >= 100
 * -The chamber - Mystics
 * -The Garden - Farmers
 * -The Battlefield - Fighters
 * Labor Ground
 * The Caverns
 */

contract PhaseII {
    IToken bones;
    IPits pits;
    INeandersmol neandersmol;

    enum Grounds {
        Chambers,
        Garden,
        Battlefield
    }

    uint256 private constant TO_WEI = 10 ** 18;

    uint256 private constant INCREASE_RATE = 1;

    uint256 private constant MINIMUM_BONE_STAKE = 1000;

    struct TokenInfo {
        address owner;
        uint256 lockTime;
        uint256 lockPeriod;
        uint256 lastRewardTime;
        uint256 bonesStaked;
        uint256[] stakedAmount;
        Grounds ground;
    }

    // tokenId -> amount position -> staking time
    mapping(uint256 => mapping(uint256 => uint256)) private trackTime;

    // tokenId -> timestamp
    // 1000 staked at 1:00pm -> 7:00 pm
    //
    // 1000 staked at 2:00pm -> 8:00pm
    // 2000 staked
    // 7:00 pm -> 8:00 pm

    mapping(uint256 => mapping(uint256 => uint256)) private tokenTiming;

    mapping(uint256 => TokenInfo) private tokenInfo;

    constructor(address _neandersmol, address _bones) {
        bones = IToken(_bones);
        neandersmol = INeandersmol(_neandersmol);
    }

    /*
     * Development Ground - Skilled Neandersmol i.e cs >= 100
     * -The chamber - Mystics
     * -The Garden - Farmers
     * -The Battlefield - Fighters
     * stake smols in chamber, garden or battlefield
     * calculate the bones earn
     * stake bones in chamber, garden or battlefield
     * boost it primary skills
     */

    /// @notice this function only works for skilled Neandersmols

    function enterDevelopmentGround(
        uint256 _tokenId,
        uint256 _lockTime,
        Grounds _ground
    ) external {
        // require(neandersmol.getCommonSense(_tokenId) >= 100);
        // check that the bones staked is greater than 50% of the ts
        // require(pits.validation())
        require(lockTimeExists(_lockTime));
        neandersmol.transferFrom(msg.sender, address(this), _tokenId);
        tokenInfo[_tokenId] = TokenInfo(
            msg.sender,
            block.timestamp,
            _lockTime,
            block.timestamp,
            0,
            new uint256[](0),
            _ground
        );
    }

    function stakeBonesInDevelopementGround(
        uint256 _tokenId,
        uint256 _amount
    ) internal {
        TokenInfo storage token = tokenInfo[_tokenId];
        uint256 newAmount;
        uint256 remainder = _amount % MINIMUM_BONE_STAKE;
        if (_amount % MINIMUM_BONE_STAKE == _amount) return;
        if (remainder != 0) {
            newAmount = _amount - remainder;
            bones.mint(msg.sender, remainder * TO_WEI);
            bones.mint(address(this), newAmount * TO_WEI);
        } else {
            newAmount = _amount;
            bones.mint(address(this), newAmount * TO_WEI);
        }

        updateTokenInfo(token, _tokenId, newAmount);
    }

    function stakeBonesInDevGround(uint256 _amount, uint256 _tokenId) public {
        // require(pits.validation())
        TokenInfo storage token = tokenInfo[_tokenId];
        require(token.owner == msg.sender, "NOT_YOURS");
        require(_amount % MINIMUM_BONE_STAKE == 0, "WRONG_MULTIPLE");
        require(bones.balanceOf(msg.sender) >= _amount, "LOW_BALANCE");
        bones.transferFrom(msg.sender, address(this), _amount * TO_WEI);
        updateTokenInfo(token, _tokenId, _amount);
    }

    function leaveDevelopmentGround(uint256 _tokenId) external {
        TokenInfo memory token = tokenInfo[_tokenId];
        require(token.owner == msg.sender);
        removeBones(_tokenId, true);
        delete tokenInfo[_tokenId];
        developPrimarySkill(_tokenId);
        neandersmol.transferFrom(address(this), msg.sender, _tokenId);
    }

    function removeBones(uint256 _tokenId, bool _all) public {
        TokenInfo memory token = tokenInfo[_tokenId];
        uint256 amount;
        uint256 length = token.stakedAmount.length;
        for (uint256 i; i < length; ++i) {
            uint256 time = trackTime[_tokenId][i];
            if (block.timestamp < time + 30 days && !_all) continue;
            if (block.timestamp < time + 30 days && _all)
                amount += token.stakedAmount[i] / 2;

            amount += token.stakedAmount[i];

            tokenInfo[_tokenId].stakedAmount[i] = token.stakedAmount[
                length - 1
            ];
            tokenInfo[_tokenId].stakedAmount.pop();
            break;
        }
        tokenInfo[_tokenId].bonesStaked -= amount;
        require(bones.transfer(msg.sender, amount));
    }

    function developPrimarySkill(uint256 _tokenId) internal {
        TokenInfo memory token = tokenInfo[_tokenId];
        uint256 amount = calculatePrimarySkill(_tokenId);
        Grounds ground = token.ground;
        if (ground == Grounds.Chambers) {
            neandersmol.developMystics(_tokenId, amount);
        } else if (ground == Grounds.Garden) {
            neandersmol.developFarmers(_tokenId, amount);
        } else {
            neandersmol.developFighter(_tokenId, amount);
        }
    }

    function calculatePrimarySkill(
        uint256 _tokenId
    ) public view returns (uint256) {
        TokenInfo memory token = tokenInfo[_tokenId];

        uint256 amount;
        for (uint256 i; i < token.stakedAmount.length; ++i) {
            uint256 time = (block.timestamp - trackTime[_tokenId][i]) / 1 days;
            amount +=
                (INCREASE_RATE * time * token.stakedAmount[i] * TO_WEI) /
                1000;
        }

        return amount;
    }

    /**
     * After the completion of one day then calculate the reward to be on
     */

    function getReward(uint256 _tokenId) public view returns (uint256) {
        TokenInfo memory token = tokenInfo[_tokenId];
        uint256 rewardRate = getRewardRate(token.lockPeriod);
        uint256 time = (block.timestamp - token.lastRewardTime) / 1 days;
        return rewardRate * time;
    }

    function claimReward(uint256 _tokenId, bool _stake) public {
        TokenInfo memory token = tokenInfo[_tokenId];
        require(token.owner == msg.sender);
        uint256 reward = getReward(_tokenId);
        tokenInfo[_tokenId].lastRewardTime = block.timestamp;
        _stake
            ? stakeBonesInDevelopementGround(_tokenId, reward)
            : bones.mint(msg.sender, reward);
    }

    function updateTokenInfo(
        TokenInfo storage _token,
        uint256 _tokenId,
        uint256 _amount
    ) internal {
        _token.bonesStaked += _amount;
        _token.stakedAmount.push(_amount);
        trackTime[_tokenId][_token.stakedAmount.length - 1] = block.timestamp;
    }

    // This could also be in a library
    function getRewardRate(uint _lockTime) internal pure returns (uint256) {
        uint256 rewardRate;
        if (_lockTime == 50 days) rewardRate = 10;
        if (_lockTime == 100 days) rewardRate = 50;
        if (_lockTime == 150 days) rewardRate = 100;

        return rewardRate;
    }

    // This could go into a library
    function lockTimeExists(uint256 _lockTime) internal pure returns (bool) {
        return
            _lockTime == 50 days ||
            _lockTime == 100 days ||
            _lockTime == 150 days;
    }

    function getTokenInfo(
        uint256 _tokenId
    ) external view returns (TokenInfo memory) {
        return tokenInfo[_tokenId];
    }
}
