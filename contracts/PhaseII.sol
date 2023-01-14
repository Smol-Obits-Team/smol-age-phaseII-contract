// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "hardhat/console.sol";
import {IPits} from "./interfaces/IPits.sol";
import {IToken} from "./interfaces/IToken.sol";
import {INeandersmol} from "./interfaces/INeandersmol.sol";
import {IConsumables, IERC1155} from "./interfaces/IConsumables.sol";

contract PhaseII {
    IPits pits;
    IToken bones;
    IERC1155 animals;
    IERC1155 supplies;
    IConsumables consumables;
    INeandersmol neandersmol;

    enum Job {
        Digging,
        Foraging,
        Mining
    }

    enum Grounds {
        Chambers,
        Garden,
        Battlefield
    }

    uint256 private constant TO_WEI = 10 ** 18;

    uint256 private constant INCREASE_RATE = 1;

    uint256 private constant MINIMUM_BONE_STAKE = 1000;

    struct DevelopmentGround {
        address owner;
        uint256 lockTime;
        uint256 lockPeriod;
        uint256 lastRewardTime;
        uint256 bonesStaked;
        uint256 amountPosition;
        Grounds ground;
    }

    struct LaborGround {
        address owner;
        uint256 lockTime;
    }

    mapping(uint256 => LaborGround) public laborGround;

    // tokenId -> amount position -> staking time
    mapping(uint256 => mapping(uint256 => uint256)) public trackTime;

    // tokenId -> time -> amount
    mapping(uint256 => mapping(uint256 => uint256)) public trackToken;

    mapping(uint256 => DevelopmentGround) private developmentGround;

    constructor(address _neandersmol, address _bones) {
        bones = IToken(_bones);
        neandersmol = INeandersmol(_neandersmol);
    }

    /// @notice this function only works for skilled Neandersmols

    function enterDevelopmentGround(
        uint256 _tokenId,
        uint256 _lockTime,
        Grounds _ground
    ) external {
        DevelopmentGround storage token = developmentGround[_tokenId];
        // require(neandersmol.getCommonSense(_tokenId) >= 100);
        // check that the bones staked is greater than 50% of the ts
        // require(pits.validation())
        require(neandersmol.ownerOf(_tokenId) == msg.sender);
        require(lockTimeExists(_lockTime));
        neandersmol.transferFrom(msg.sender, address(this), _tokenId);
        token.owner = msg.sender;
        token.lockTime = block.timestamp;
        token.lockPeriod = _lockTime;
        token.lastRewardTime = block.timestamp;
        token.ground = _ground;
    }

    function stakeBonesInDevelopementGround(
        uint256 _tokenId,
        uint256 _amount
    ) internal {
        DevelopmentGround storage token = developmentGround[_tokenId];
        uint256 newAmount;
        uint256 remainder = _amount % MINIMUM_BONE_STAKE;
        if (remainder == _amount) return;
        if (remainder != 0) {
            newAmount = _amount - remainder;
            bones.mint(msg.sender, remainder * TO_WEI);
            bones.mint(address(this), newAmount * TO_WEI);
        } else {
            newAmount = _amount;
            bones.mint(address(this), newAmount * TO_WEI);
        }

        updateDevelopmentGround(token, _tokenId, newAmount);
    }

    function stakeBonesInDevGround(uint256 _amount, uint256 _tokenId) public {
        // require(pits.validation())
        DevelopmentGround storage token = developmentGround[_tokenId];
        require(bones.balanceOf(msg.sender) >= _amount);
        require(token.owner == msg.sender);
        require(_amount % MINIMUM_BONE_STAKE == 0);
        bones.transferFrom(msg.sender, address(this), _amount * TO_WEI);
        updateDevelopmentGround(token, _tokenId, _amount);
    }

    function leaveDevelopmentGround(uint256 _tokenId) external {
        DevelopmentGround memory token = developmentGround[_tokenId];
        require(block.timestamp > token.lockTime + token.lockPeriod);
        require(token.owner == msg.sender);
        removeBones(_tokenId, true);
        delete developmentGround[_tokenId];
        neandersmol.transferFrom(address(this), msg.sender, _tokenId);
    }

    function removeBones(uint256 _tokenId, bool _all) public {
        DevelopmentGround memory token = developmentGround[_tokenId];
        uint256 amount;
        uint256 count;
        for (uint256 i = 1; i <= token.amountPosition; ) {
            developPrimarySkill(_tokenId);
            uint256 time = trackTime[_tokenId][i];
            uint256 prev = trackTime[_tokenId][i + 1];
            if (block.timestamp < time + 30 days && !_all) continue;
            block.timestamp < time + 30 days && _all
                ? amount += trackToken[_tokenId][time] / 2
                : amount += trackToken[_tokenId][time];

            // 1000 - 1
            // 1000 - 2 remove this -> trackTime[_tokenId][2] = 0
            // 1000 - 3 remove this -> trackTime[_tokenId][3] = this time
            // 1000 - 4 takes this time
            // 1000 - 5
            /**
             * uint prev = trackTime[_tokenId][i+1];
             * trackTime[_tokenId][i] = prev
             */
            _all || token.amountPosition == 1
                ? trackTime[_tokenId][i] = 0
                : trackTime[_tokenId][i] = prev;
            trackToken[_tokenId][time] = 0;
            unchecked {
                ++count;
                ++i;
            }
        }

        developmentGround[_tokenId].amountPosition -= count;

        if (_all) {
            developmentGround[_tokenId].bonesStaked = 0;
            if (token.bonesStaked - amount != 0)
                require(bones.transfer(address(1), token.bonesStaked - amount)); // change the address(1)
        } else {
            developmentGround[_tokenId].bonesStaked -= amount;
        }

        require(bones.transfer(msg.sender, amount));

        emit RemoveBones(msg.sender, _tokenId, amount);
    }

    event RemoveBones(address owner, uint256 tokenId, uint256 amount);

    function developPrimarySkill(uint256 _tokenId) internal {
        // make sure bones staked is more than 50% the total supply
        DevelopmentGround memory token = developmentGround[_tokenId];
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
        // make sure bones staked is more than 50% the total supply
        DevelopmentGround memory token = developmentGround[_tokenId];
        uint256 amount;
        for (uint256 i = 1; i <= token.amountPosition; ) {
            uint256 time = (block.timestamp - trackTime[_tokenId][i]) / 1 days;
            uint256 stakedAmount = trackToken[_tokenId][trackTime[_tokenId][i]];
            amount += (INCREASE_RATE * time * stakedAmount * TO_WEI) / 1000;
            unchecked {
                ++i;
            }
        }
        return amount;
    }

    /**
     * After the completion of one day then calculate the reward to be on
     */

    function getReward(uint256 _tokenId) public view returns (uint256) {
        DevelopmentGround memory token = developmentGround[_tokenId];
        uint256 rewardRate = getRewardRate(token.lockPeriod);
        uint256 time = (block.timestamp - token.lastRewardTime) / 1 days;
        return rewardRate * time;
    }

    function claimReward(uint256 _tokenId, bool _stake) public {
        DevelopmentGround memory token = developmentGround[_tokenId];
        require(token.owner == msg.sender);
        uint256 reward = getReward(_tokenId);
        developmentGround[_tokenId].lastRewardTime = block.timestamp;
        _stake
            ? stakeBonesInDevelopementGround(_tokenId, reward)
            : bones.mint(msg.sender, reward * TO_WEI);
    }

    function updateDevelopmentGround(
        DevelopmentGround storage _token,
        uint256 _tokenId,
        uint256 _amount
    ) internal {
        _token.bonesStaked += _amount;
        ++_token.amountPosition;
        trackToken[_tokenId][block.timestamp] = _amount;
        trackTime[_tokenId][_token.amountPosition] = block.timestamp;
    }

    // put a check for the common sense < 100
    // a function to leave labour ground
    // a function to generate random number ✅
    // a function to allow the owner of the token collect it consumbles
    function enterLaborGround(
        uint256 _tokenId,
        uint256 _suppliesId,
        Job _job
    ) external {
        require(neandersmol.ownerOf(_tokenId) == msg.sender);
        require(validateTokenId(_suppliesId, _job));
        supplies.safeTransferFrom(
            msg.sender,
            address(this),
            _suppliesId,
            1,
            ""
        );
        laborGround[_tokenId] = LaborGround(msg.sender, block.timestamp);
    }

    // 0 => got nothing
    // 1 - 3 => common
    // 4 - 6 rare
    // 7 break their supply
    function claimCollectables(uint256 _tokenId) public {
        LaborGround memory labor = laborGround[_tokenId];
        require(msg.sender == labor.owner);
        require(block.timestamp > labor.lockTime + 3 days);
        uint256 tokenId = getRandom(10);
        if (tokenId == 0) return;
        if (tokenId > 6) return; // break supply
        consumables.mint(msg.sender, tokenId, 1);
    }

    function leaveLaborGround(uint256 _tokenId) external {
        claimCollectables(_tokenId);
        delete laborGround[_tokenId];
        supplies.safeTransferFrom(address(this), msg.sender, 1, 1, "");
    }

    function validateTokenId(
        uint256 _tokenId,
        Job _job
    ) internal pure returns (bool res) {
        if (_job == Job.Digging) return _tokenId == 0;
        if (_job == Job.Foraging) return _tokenId == 1;
        if (_job == Job.Mining) return _tokenId == 2;
    }

    // @remind use a better solution than this
    function getRandom(uint256 _num) internal view returns (uint256) {
        return
            uint256(
                keccak256(
                    abi.encode(
                        msg.sender,
                        block.number,
                        block.timestamp,
                        block.coinbase
                    )
                )
            ) % _num;
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

    function getDevelopmentGroundInfo(
        uint256 _tokenId
    ) external view returns (DevelopmentGround memory) {
        return developmentGround[_tokenId];
    }
}
