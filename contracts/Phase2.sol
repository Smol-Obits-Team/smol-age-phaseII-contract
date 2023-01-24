// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "hardhat/console.sol";
import {IPits} from "./interfaces/IPits.sol";
import {IToken} from "./interfaces/IToken.sol";
import {INeandersmol} from "./interfaces/INeandersmol.sol";
import {IConsumables, IERC1155} from "./interfaces/IConsumables.sol";

contract Phase2 {
    IPits pits;
    IToken bones;
    IERC1155 animals;
    IERC1155 supplies;
    IConsumables consumables;
    INeandersmol neandersmol;

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

    uint256 private constant TO_WEI = 10 ** 18;

    uint256 private constant INCREASE_RATE = 1;

    uint256 private constant MINIMUM_BONE_STAKE = 1000 * 10 ** 18;

    struct DevelopmentGround {
        address owner;
        uint48 lockPeriod;
        uint48 amountPosition;
        uint128 lockTime;
        uint128 lastRewardTime;
        uint256 bonesStaked;
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

    mapping(uint256 => Caves) private caves;
    mapping(uint256 => LaborGround) public laborGround;
    // tokenId -> amount position -> staking time
    mapping(uint256 => mapping(uint256 => uint256)) public trackTime;
    // tokenId -> time -> amount
    mapping(uint256 => mapping(uint256 => uint256)) public trackToken;
    mapping(uint256 => DevelopmentGround) private developmentGround;

    /**
     * get all the days off,
     * get the timestamp of the whole contract
     * get the timestamo of the address
     * assuming a certain user staked at 1pm and we start giving reward by 2pm
     * how do we go about this?
     */
    constructor(
        address _pits,
        address _bones,
        address _animals,
        address _supplies,
        address _consumables,
        address _neandersmol
    ) {
        bones = IToken(_bones);
        animals = IERC1155(_animals);
        pits = IPits(_pits);
        supplies = IERC1155(_supplies);
        consumables = IConsumables(_consumables);
        neandersmol = INeandersmol(_neandersmol);
    }

    /// @notice this function only works for skilled Neandersmols

    error LengthsNotEqual();
    error DevelopmentGroundIsLocked();
    error CsIsBellowHundred();
    error NotYourToken();
    error InvalidLockTime();

    function enterDevelopmentGround(
        uint256[] calldata _tokenId,
        uint256[] calldata _lockTime,
        Grounds[] calldata _ground
    ) external {
        uint256 i;
        /**
         * ([1,2],[0], [1,3])
         * true and true =>  revert
         * ([1,2],[0], [1])
         * true and false => not revert
         */
        if (
            _tokenId.length != _lockTime.length ||
            _lockTime.length != _ground.length
        ) revert LengthsNotEqual();
        if (!pits.validation()) revert DevelopmentGroundIsLocked();
        for (; i < _tokenId.length; ) {
            (uint256 tokenId, uint256 lockTime) = (_tokenId[i], _lockTime[i]);
            DevelopmentGround storage token = developmentGround[tokenId];
            if (neandersmol.getCommonSense(tokenId) < 100)
                revert CsIsBellowHundred();
            if (neandersmol.ownerOf(tokenId) != msg.sender)
                revert NotYourToken();
            if (!lockTimeExists(lockTime)) revert InvalidLockTime();
            neandersmol.transferFrom(msg.sender, address(this), tokenId);
            token.owner = msg.sender;
            token.lockTime = uint128(block.timestamp);
            token.lockPeriod = uint48(lockTime);
            token.lastRewardTime = uint128(block.timestamp);
            token.ground = _ground[i];
            unchecked {
                ++i;
            }
        }
    }

    error BalanceIsInsufficient();
    error TokenNotInDevelopementGround();
    error WrongMultiple();

    function stakeBonesInDevelopmentGround(
        uint256[] calldata _amount,
        uint256[] calldata _tokenId
    ) external {
        if (!pits.validation()) revert DevelopmentGroundIsLocked();
        uint256 i;
        for (; i < _amount.length; ) {
            uint256 tokenId = _tokenId[i];
            uint256 amount = _amount[i];
            DevelopmentGround storage token = developmentGround[tokenId];
            if (bones.balanceOf(msg.sender) < amount)
                revert BalanceIsInsufficient();
            if (token.owner != msg.sender)
                revert TokenNotInDevelopementGround();

            if (amount % MINIMUM_BONE_STAKE != 0) revert WrongMultiple();
            bones.transferFrom(msg.sender, address(this), amount);
            updateDevelopmentGround(token, tokenId, amount);
            unchecked {
                ++i;
            }
        }
    }

    function stakeBonesInDevelopmentGround(
        uint256 _tokenId,
        uint256 _amount
    ) internal {
        DevelopmentGround storage token = developmentGround[_tokenId];
        uint256 newAmount;
        uint256 remainder = _amount % MINIMUM_BONE_STAKE;
        if (remainder == _amount) return;
        if (remainder != 0) {
            newAmount = _amount - remainder;
            bones.mint(msg.sender, remainder);
            bones.mint(address(this), newAmount);
        } else {
            newAmount = _amount;
            bones.mint(address(this), newAmount);
        }

        updateDevelopmentGround(token, _tokenId, newAmount);
    }

    /**
     * After the completion of one day then calculate the reward to be on
     */

    function getDevelopmentGroundBonesReward(
        uint256 _tokenId
    ) public view returns (uint256) {
        DevelopmentGround memory token = developmentGround[_tokenId];
        uint256 rewardRate = getRewardRate(token.lockPeriod);
        uint256 time = (block.timestamp - token.lastRewardTime) / 1 days;
        return calculateFinalReward(rewardRate * time) * TO_WEI;
    }

    function leaveDevelopmentGround(uint256 _tokenId) external {
        DevelopmentGround memory token = developmentGround[_tokenId];
        require(block.timestamp > token.lockTime + token.lockPeriod);
        require(token.owner == msg.sender);
        removeBones(_tokenId, true);
        delete developmentGround[_tokenId];
        neandersmol.transferFrom(address(this), msg.sender, _tokenId);
    }

    function removeBones(
        uint256[] calldata _tokenId,
        bool[] calldata _all
    ) external {
        uint256 i;
        for (; i < _tokenId.length; ) {
            removeBones(_tokenId[i], _all[i]);
            unchecked {
                ++i;
            }
        }
    }

    function removeBones(uint256 _tokenId, bool _all) public {
        DevelopmentGround memory token = developmentGround[_tokenId];
        uint256 i = 1;
        uint256 amount;
        uint48 count;
        for (; i <= token.amountPosition; ) {
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
        // make sure bones staked is more than 30% the total supply
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
        return calculateFinalReward(amount);
    }

    function calculateFinalReward(
        uint256 _amount
    ) internal view returns (uint256) {
        uint256 finalAmount;
        uint256 timeBelow = pits.getTimeBelowMinimum();
        uint256 time;
        timeBelow == 0 ? time = 0 : time =
            (block.timestamp - timeBelow) /
            1 days;
        // check this when get to the primary level
        // pits.getTimeBelowMinimum() != 0 && _amount != 0
        //     ? finalAmount = _amount - (10 * time)
        //     : finalAmount = _amount;
        /**
         * the time should only come to play if we are below minimum stake
         * 0 -> 1 days <==> 10 default
         * 1 -> 3 days <==> 10 (3*10) - (10*2) -  2 days off
         * 3 -> 6 days <==> 40 (6*10) - (2*10)
         * 6 -> 8 days <==> 40 default -  2 days off
         * 8 -> 10 days <==> 60 (10*10) - (10*4)
         * reward = totalTimeReward - (reward_per_day * days off);
         * How to get days off
         *
         */

        finalAmount = _amount - (10 * time);

        return finalAmount;
    }

    function claimDevelopementGroundBonesReward(
        uint256[] calldata _tokenId,
        bool[] calldata _stake
    ) public {
        uint256 i;
        for (; i < _tokenId.length; ) {
            uint256 tokenId = _tokenId[i];
            DevelopmentGround memory token = developmentGround[tokenId];
            require(token.owner == msg.sender);
            uint256 reward = getDevelopmentGroundBonesReward(tokenId);
            developmentGround[tokenId].lastRewardTime = uint128(
                block.timestamp
            );
            _stake[i]
                ? stakeBonesInDevelopmentGround(tokenId, reward)
                : bones.mint(msg.sender, reward);

            unchecked {
                ++i;
            }
        }
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

    function enterCaves(uint256[] calldata _tokenId) external {
        uint256 i;
        for (; i < _tokenId.length; ) {
            uint256 tokenId = _tokenId[i];
            Caves storage cave = caves[tokenId];
            if (neandersmol.ownerOf(tokenId) != msg.sender)
                revert NotYourToken();
            neandersmol.transferFrom(msg.sender, address(this), tokenId);
            cave.owner = msg.sender;
            cave.stakingTime = uint96(block.timestamp);
            unchecked {
                ++i;
            }
        }
    }

    function getCavesInfo(
        uint256 _tokenId
    ) external view returns (Caves memory) {
        return caves[_tokenId];
    }

    error NeandersmolsIsLocked();

    function leaveCave(uint256[] calldata _tokenId) external {
        uint256 i;
        for (; i < _tokenId.length; ) {
            uint256 tokenId = _tokenId[i];
            Caves memory cave = caves[tokenId];
            if (cave.owner != msg.sender) revert NotYourToken();

            if (100 days + cave.stakingTime > block.timestamp)
                revert NeandersmolsIsLocked();
            uint256 reward = getCavesReward(tokenId);
            if (reward != 0) claimCaveReward(tokenId);
            delete caves[tokenId];
            neandersmol.transferFrom(address(this), msg.sender, tokenId);
            unchecked {
                ++i;
            }
        }
    }

    error ZeroBalanceError();

    function claimCaveReward(uint256 _tokenId) internal {
        uint256 reward = getCavesReward(_tokenId);
        if (reward == 0) revert ZeroBalanceError();
        caves[_tokenId].stakingTime = uint96(block.timestamp);
        bones.mint(msg.sender, reward);
    }

    // after making first claim the time should be updated

    function claimCaveReward(uint256[] calldata _tokenId) external {
        uint256 i;
        for (; i < _tokenId.length; ) {
            claimCaveReward(_tokenId[i]);
            unchecked {
                ++i;
            }
        }
    }

    function getCavesReward(uint256 _tokenId) public view returns (uint256) {
        return (timeLeftToLeaveCaveInDays(_tokenId) * 10 * TO_WEI);
    }

    function timeLeftToLeaveCaveInDays(
        uint256 _tokenId
    ) public view returns (uint256) {
        Caves memory cave = caves[_tokenId];
        return (block.timestamp - cave.stakingTime) / 1 days;
    }

    // put a check for the common sense < 100 ✅
    // a function to leave labour ground ✅
    // a function to generate random number ✅
    // a function to allow the owner of the token collect it consumbles ✅

    error InvalidTokenForThisJob();
    error CsToHigh();

    function enterLaborGround(
        uint256[] calldata _tokenId,
        uint256[] calldata _supplyId,
        Jobs[] calldata _job
    ) external {
        if (
            _tokenId.length != _supplyId.length ||
            _supplyId.length != _job.length
        ) revert LengthsNotEqual();
        uint256 i;
        for (; i < _tokenId.length; ) {
            uint256 supplyId = _supplyId[i];
            uint256 tokenId = _tokenId[i];
            LaborGround storage labor = laborGround[_tokenId[i]];
            if (neandersmol.ownerOf(tokenId) != msg.sender)
                revert NotYourToken();
            if (neandersmol.getCommonSense(tokenId) > 99) revert CsToHigh();
            if (!validateTokenId(supplyId, _job[i]))
                revert InvalidTokenForThisJob();
            supplies.safeTransferFrom(
                msg.sender,
                address(this),
                supplyId,
                1,
                ""
            );
            neandersmol.transferFrom(msg.sender, address(this), tokenId);
            labor.owner = msg.sender;
            labor.lockTime = uint32(block.timestamp);
            labor.supplyId = uint32(supplyId);
            labor.job = _job[i];

            unchecked {
                ++i;
            }
        }
    }

    function bringInAnimalsToLaborGround(
        uint256[] calldata _tokenId,
        uint256[] calldata _animalsId
    ) public {
        if (_tokenId.length != _animalsId.length) revert LengthsNotEqual();
        uint256 i;
        for (; i < _tokenId.length; ) {
            uint256 animalsId = _animalsId[i];
            LaborGround storage labor = laborGround[_tokenId[i]];
            if (labor.owner != msg.sender) revert NotYourToken();

            animals.safeTransferFrom(
                msg.sender,
                address(this),
                animalsId,
                1,
                ""
            );
            labor.animalId = uint32(animalsId) + 1; // added one since animals token id starts from 0
            unchecked {
                ++i;
            }
        }
    }

    error CannotClaimNow();

    function claimCollectable(uint256 _tokenId) public {
        LaborGround memory labor = laborGround[_tokenId];
        if (msg.sender != labor.owner) revert NotYourToken();
        if (block.timestamp < labor.lockTime + 3 days) revert CannotClaimNow();
        uint256 consumablesTokenId = checkPossibleClaims(_tokenId, labor);
        if (consumablesTokenId != 0) {
            consumables.mint(msg.sender, consumablesTokenId, 1);
        }
        laborGround[_tokenId].lockTime = 0;
    }

    function claimCollectables(uint256[] calldata _tokenId) external {
        uint256 i;
        for (; i < _tokenId.length; ) {
            claimCollectable(_tokenId[i]);
            unchecked {
                ++i;
            }
        }
    }

    function checkPossibleClaims(
        uint256 _tokenId,
        LaborGround memory labor
    ) internal returns (uint256) {
        uint256 rnd = getRandom(101);
        uint animalId = labor.animalId;
        uint256 consumablesTokenId;
        uint256 supplyId = labor.supplyId;
        (uint256 tokenOne, uint256 tokenTwo) = getConsumablesTokenId(labor.job);
        uint256 max;
        uint256 min;
        if (animalId == 0) {
            if (rnd < 61) {
                consumablesTokenId = tokenOne;
            } else if (rnd > 60 && rnd < 81) {
                consumablesTokenId = tokenTwo;
            } else {
                max = 3;
                min = 2;
            }
        }
        if (animalId == 1) {
            if (rnd < 66) {
                consumablesTokenId = tokenOne;
            } else if (rnd > 66 && rnd < 86) {
                consumablesTokenId = tokenTwo;
            } else {
                max = 16;
                min = 5;
            }
        }
        if (animalId == 2) {
            if (rnd < 66) {
                consumablesTokenId = tokenOne;
            } else if (rnd > 65 && rnd < 96) {
                consumablesTokenId = tokenTwo;
            } else {
                max = 11;
                min = 6;
            }
        }
        if (animalId == 3) {
            if (rnd < 71) {
                consumablesTokenId = tokenOne;
            } else if (rnd > 70 && rnd < 96) {
                consumablesTokenId = tokenTwo;
            } else {
                max = 6;
                min = 1;
            }
        }

        if (max != 0 && min != 0) breakOrFailed(_tokenId, supplyId, max, min);

        if (animalId == 4)
            rnd < 71
                ? consumablesTokenId = tokenOne
                : consumablesTokenId = tokenTwo;

        if (animalId == 5)
            rnd < 66
                ? consumablesTokenId = tokenOne
                : consumablesTokenId = tokenTwo;

        if (animalId == 6)
            rnd < 61
                ? consumablesTokenId = tokenOne
                : consumablesTokenId = tokenTwo;

        return consumablesTokenId;
    }

    function getConsumablesTokenId(
        Jobs _job
    ) internal pure returns (uint256, uint256) {
        uint256 tokenIdOne;
        uint256 tokenIdTwo;
        if (_job == Jobs.Digging) (tokenIdOne, tokenIdTwo) = (1, 4);
        if (_job == Jobs.Foraging) (tokenIdOne, tokenIdTwo) = (2, 5);
        if (_job == Jobs.Mining) (tokenIdOne, tokenIdTwo) = (3, 6);

        return (tokenIdOne, tokenIdTwo);
    }

    function breakOrFailed(
        uint256 _tokenId,
        uint256 _supplyId,
        uint256 _amount,
        uint256 _min
    ) internal {
        uint256 random = getRandom(_amount);
        if (random < _min) {
            supplies.safeTransferFrom(
                address(this),
                msg.sender,
                _supplyId,
                1,
                ""
            );
            laborGround[_tokenId].supplyId = 0;
        }
    }

    function leaveLaborGround(uint256[] calldata _tokenId) external {
        uint256 i;

        for (; i < _tokenId.length; ) {
            uint256 tokenId = _tokenId[i];
            claimCollectable(tokenId);
            LaborGround memory labor = laborGround[tokenId];
            delete laborGround[tokenId];
            if (labor.animalId != 0) {
                animals.safeTransferFrom(
                    address(this),
                    msg.sender,
                    labor.animalId + 1,
                    1,
                    ""
                );
            }
            if (labor.supplyId != 0)
                supplies.safeTransferFrom(
                    address(this),
                    msg.sender,
                    labor.supplyId,
                    1,
                    ""
                );
            neandersmol.transferFrom(address(this), msg.sender, tokenId);
            unchecked {
                ++i;
            }
        }
    }

    function validateTokenId(
        uint256 _tokenId,
        Jobs _job
    ) internal pure returns (bool res) {
        if (_job == Jobs.Digging) return _tokenId == 1;
        if (_job == Jobs.Foraging) return _tokenId == 2;
        if (_job == Jobs.Mining) return _tokenId == 3;
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

    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes memory
    ) external pure returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    function getLaborGroundInfo(
        uint256 _tokenId
    ) external view returns (LaborGround memory) {
        return laborGround[_tokenId];
    }

    function getDevelopmentGroundInfo(
        uint256 _tokenId
    ) external view returns (DevelopmentGround memory) {
        return developmentGround[_tokenId];
    }
}
