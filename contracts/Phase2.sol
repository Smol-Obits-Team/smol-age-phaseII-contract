// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "hardhat/console.sol";
import {Lib} from "./library/Lib.sol";
import {IError} from "./interfaces/IError.sol";
import {IPits} from "./interfaces/IPits.sol";
import {IToken} from "./interfaces/IToken.sol";
import {INeandersmol} from "./interfaces/INeandersmol.sol";
import {IConsumables, IERC1155} from "./interfaces/IConsumables.sol";

contract Phase2 is IError {
    IPits public pits;
    IToken public bones; 
    IERC1155 public animals;
    IERC1155 public supplies;
    IConsumables public consumables;
    INeandersmol public neandersmol; 

    uint256 private constant TO_WEI = 10 ** 18;

    uint256 private constant INCREASE_RATE = 1;

    uint256 private constant MINIMUM_BONE_STAKE = 1000 * 10 ** 18;

    mapping(uint256 => Lib.Caves) private caves;
    mapping(uint256 => Lib.LaborGround) private laborGround;
    mapping(uint256 => Lib.DevelopmentGround) private developmentGround;
    // tokenId -> amount position -> staking time
    mapping(uint256 => mapping(uint256 => uint256)) private trackTime;
    // tokenId -> time -> amount
    mapping(uint256 => mapping(uint256 => uint256)) private trackToken;

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

    function enterDevelopmentGround(
        uint256[] calldata _tokenId,
        uint256[] calldata _lockTime,
        Lib.Grounds[] calldata _ground
    ) external {
        uint256 i;

        if (
            _tokenId.length != _lockTime.length ||
            _lockTime.length != _ground.length
        ) revert LengthsNotEqual();
        if (!pits.validation()) revert DevelopmentGroundIsLocked();
        for (; i < _tokenId.length; ) {
            (uint256 tokenId, uint256 lockTime) = (_tokenId[i], _lockTime[i]);
            Lib.DevelopmentGround storage token = developmentGround[tokenId];
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

            emit EnterDevelopmentGround(
                msg.sender,
                tokenId,
                lockTime,
                _ground[i]
            );
            unchecked {
                ++i;
            }
        }
    }

    function stakeBonesInDevelopmentGround(
        uint256[] calldata _amount,
        uint256[] calldata _tokenId
    ) external {
        if (!pits.validation()) revert DevelopmentGroundIsLocked();
        uint256 i;
        for (; i < _amount.length; ) {
            uint256 tokenId = _tokenId[i];
            uint256 amount = _amount[i];
            Lib.DevelopmentGround storage token = developmentGround[tokenId];
            if (bones.balanceOf(msg.sender) < amount)
                revert BalanceIsInsufficient();
            if (token.owner != msg.sender)
                revert TokenNotInDevelopementGround();

            if (amount % MINIMUM_BONE_STAKE != 0) revert WrongMultiple();
            bones.transferFrom(msg.sender, address(this), amount);
            updateDevelopmentGround(token, tokenId, amount);
            emit StakeBonesInDevelopmentGround(msg.sender, amount, tokenId);
            unchecked {
                ++i;
            }
        }
    }

    function stakeBonesInDevelopmentGround(
        uint256 _tokenId,
        uint256 _amount
    ) internal {
        Lib.DevelopmentGround storage token = developmentGround[_tokenId];
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
        emit StakeBonesInDevelopmentGround(msg.sender, _amount, _tokenId);
    }

    function getDevelopmentGroundBonesReward(
        uint256 _tokenId
    ) public view returns (uint256) {
        Lib.DevelopmentGround memory token = developmentGround[_tokenId];
        if (token.lockPeriod == 0) return 0;
        uint256 rewardRate = getRewardRate(token.lockPeriod);

        uint256 time = (block.timestamp - token.lastRewardTime) / 1 days;
        return calculateFinalReward(rewardRate * time) * TO_WEI;
    }

    function leaveDevelopmentGround(uint256 _tokenId) external {
        Lib.DevelopmentGround memory token = developmentGround[_tokenId];
        if (block.timestamp < token.lockTime + token.lockPeriod)
            revert NeandersmolsIsLocked();
        if (token.owner != msg.sender) revert NotYourToken();
        removeBones(_tokenId, true);
        delete developmentGround[_tokenId];
        neandersmol.transferFrom(address(this), msg.sender, _tokenId);
        emit LeaveDevelopmentGround(msg.sender, _tokenId);
    }

    function removeBones(
        uint256[] calldata _tokenId,
        bool[] calldata _all
    ) external {
        if (_tokenId.length != _all.length) revert LengthsNotEqual();
        uint256 i;
        for (; i < _tokenId.length; ) {
            removeBones(_tokenId[i], _all[i]);
            unchecked {
                ++i;
            }
        }
    }

    function removeBones(uint256 _tokenId, bool _all) public {
        Lib.DevelopmentGround memory token = developmentGround[_tokenId];
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
        unchecked {
            developmentGround[_tokenId].amountPosition -= count;
        }

        if (_all) {
            developmentGround[_tokenId].bonesStaked = 0;
            if (token.bonesStaked - amount != 0)
                if (!bones.transfer(address(1), token.bonesStaked - amount))
                    revert TransferFailed(); // change the address(1)
        } else {
            developmentGround[_tokenId].bonesStaked -= amount;
        }

        if (!bones.transfer(msg.sender, amount)) revert TransferFailed();

        emit RemoveBones(msg.sender, _tokenId, amount);
    }

    function developPrimarySkill(uint256 _tokenId) internal {
        // make sure bones staked is more than 50% the total supply
        Lib.DevelopmentGround memory token = developmentGround[_tokenId];
        uint256 amount = calculatePrimarySkill(_tokenId);
        Lib.Grounds ground = token.ground;
        if (ground == Lib.Grounds.Chambers) {
            neandersmol.developMystics(_tokenId, amount);
        } else if (ground == Lib.Grounds.Garden) {
            neandersmol.developFarmers(_tokenId, amount);
        } else {
            neandersmol.developFighter(_tokenId, amount);
        }
    }

    function calculatePrimarySkill(
        uint256 _tokenId
    ) public view returns (uint256) {
        // make sure bones staked is more than 30% the total supply
        Lib.DevelopmentGround memory token = developmentGround[_tokenId];
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
        return calculateFinalReward(amount);
    }

    function calculateFinalReward(
        uint256 _amount
    ) internal view returns (uint256) {
        uint256 finalAmount;
        uint256 timeBelow = pits.getTimeBelowMinimum();
        uint256 time;

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
    ) external {
        if (_tokenId.length != _stake.length) revert LengthsNotEqual();
        uint256 i;
        for (; i < _tokenId.length; ) {
            uint256 tokenId = _tokenId[i];
            Lib.DevelopmentGround memory token = developmentGround[tokenId];
            require(token.owner == msg.sender);
            uint256 reward = getDevelopmentGroundBonesReward(tokenId);
            developmentGround[tokenId].lastRewardTime = uint128(
                block.timestamp
            );
            _stake[i]
                ? stakeBonesInDevelopmentGround(tokenId, reward)
                : bones.mint(msg.sender, reward);

            emit ClaimDevelopementGroundBonesReward(
                msg.sender,
                tokenId,
                _stake[i]
            );
            unchecked {
                ++i;
            }
        }
    }

    function enterCaves(uint256[] calldata _tokenId) external {
        uint256 i;
        for (; i < _tokenId.length; ) {
            uint256 tokenId = _tokenId[i];
            Lib.Caves storage cave = caves[tokenId];
            if (neandersmol.ownerOf(tokenId) != msg.sender)
                revert NotYourToken();
            neandersmol.transferFrom(msg.sender, address(this), tokenId);
            cave.owner = msg.sender;
            cave.stakingTime = uint96(block.timestamp);
            emit EnterCaves(msg.sender, tokenId);
            unchecked {
                ++i;
            }
        }
    }

    function leaveCave(uint256[] calldata _tokenId) external {
        uint256 i;
        for (; i < _tokenId.length; ) {
            uint256 tokenId = _tokenId[i];
            Lib.Caves memory cave = caves[tokenId];
            if (cave.owner != msg.sender) revert NotYourToken();
            if (100 days + cave.stakingTime > block.timestamp)
                revert NeandersmolsIsLocked();
            if (getCavesReward(tokenId) != 0) claimCaveReward(tokenId);
            delete caves[tokenId];
            neandersmol.transferFrom(address(this), msg.sender, tokenId);
            unchecked {
                ++i;
            }
        }
    }

    function claimCaveReward(uint256 _tokenId) internal {
        uint256 reward = getCavesReward(_tokenId);
        if (reward == 0) revert ZeroBalanceError();
        caves[_tokenId].stakingTime = uint96(block.timestamp);
        bones.mint(msg.sender, reward);
        emit ClaimCaveReward(msg.sender, _tokenId, reward);
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

    function enterLaborGround(
        uint256[] calldata _tokenId,
        uint256[] calldata _supplyId,
        Lib.Jobs[] calldata _job
    ) external {
        if (
            _tokenId.length != _supplyId.length ||
            _supplyId.length != _job.length
        ) revert LengthsNotEqual();
        uint256 i;
        for (; i < _tokenId.length; ) {
            uint256 supplyId = _supplyId[i];
            uint256 tokenId = _tokenId[i];
            Lib.LaborGround storage labor = laborGround[tokenId];
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
    ) external {
        if (_tokenId.length != _animalsId.length) revert LengthsNotEqual();
        uint256 i;
        for (; i < _tokenId.length; ) {
            uint256 animalsId = _animalsId[i];
            Lib.LaborGround storage labor = laborGround[_tokenId[i]];
            if (labor.owner != msg.sender) revert NotYourToken();

            animals.safeTransferFrom(
                msg.sender,
                address(this),
                animalsId,
                1,
                ""
            );
            labor.animalId = uint32(animalsId) + 1; // added one since animals token id starts from 0
            emit BringInAnimalsToLaborGround(
                msg.sender,
                _tokenId[i],
                animalsId
            );
            unchecked {
                ++i;
            }
        }
    }

    function claimCollectable(uint256 _tokenId) public {
        Lib.LaborGround memory labor = laborGround[_tokenId];
        if (msg.sender != labor.owner) revert NotYourToken();
        if (block.timestamp < labor.lockTime + 3 days) revert CannotClaimNow();
        uint256 consumablesTokenId = checkPossibleClaims(_tokenId, labor);
        if (consumablesTokenId != 0) {
            consumables.mint(msg.sender, consumablesTokenId, 1);
        }
        laborGround[_tokenId].lockTime = 0;
        emit ClaimCollectable(msg.sender, _tokenId);
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
            Lib.LaborGround memory labor = laborGround[tokenId];
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
            emit LeaveLaborGround(msg.sender, tokenId);
            unchecked {
                ++i;
            }
        }
    }

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

    function updateDevelopmentGround(
        Lib.DevelopmentGround storage _token,
        uint256 _tokenId,
        uint256 _amount
    ) internal {
        _token.bonesStaked += _amount;
        ++_token.amountPosition;
        trackToken[_tokenId][block.timestamp] = _amount;
        trackTime[_tokenId][_token.amountPosition] = block.timestamp;
    }

    function checkPossibleClaims(
        uint256 _tokenId,
        Lib.LaborGround memory labor
    ) internal returns (uint256) {
        uint256 rnd = getRandom(101);
        uint animalId = labor.animalId;
        uint256 consumablesTokenId;
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

        if (max != 0 && min != 0)
            breakOrFailed(_tokenId, labor.supplyId, max, min);

        if (animalId == 4) {
            rnd < 71
                ? consumablesTokenId = tokenOne
                : consumablesTokenId = tokenTwo;
        }
        if (animalId == 5) {
            rnd < 66
                ? consumablesTokenId = tokenOne
                : consumablesTokenId = tokenTwo;
        }
        if (animalId == 6) {
            rnd < 61
                ? consumablesTokenId = tokenOne
                : consumablesTokenId = tokenTwo;
        }
        return consumablesTokenId;
    }

    function timeLeftToLeaveCaveInDays(
        uint256 _tokenId
    ) internal view returns (uint256) {
        Lib.Caves memory cave = caves[_tokenId];
        if (cave.stakingTime == 0) return 0;
        return (block.timestamp - cave.stakingTime) / 1 days;
    }

    function lockTimeExists(uint256 _lockTime) internal pure returns (bool) {
        return
            _lockTime == 50 days ||
            _lockTime == 100 days ||
            _lockTime == 150 days;
    }

    function getConsumablesTokenId(
        Lib.Jobs _job
    ) internal pure returns (uint256 tokenIdOne, uint256 tokenIdTwo) {
        if (_job == Lib.Jobs.Digging) (tokenIdOne, tokenIdTwo) = (1, 4);
        if (_job == Lib.Jobs.Foraging) (tokenIdOne, tokenIdTwo) = (2, 5);
        if (_job == Lib.Jobs.Mining) (tokenIdOne, tokenIdTwo) = (3, 6);
    }

    function getRewardRate(
        uint _lockTime
    ) internal pure returns (uint256 rewardRate) {
        if (_lockTime == 50 days) rewardRate = 10;
        if (_lockTime == 100 days) rewardRate = 50;
        if (_lockTime == 150 days) rewardRate = 100;
    }

    function validateTokenId(
        uint256 _tokenId,
        Lib.Jobs _job
    ) internal pure returns (bool res) {
        if (_job == Lib.Jobs.Digging) return _tokenId == 1;
        if (_job == Lib.Jobs.Foraging) return _tokenId == 2;
        if (_job == Lib.Jobs.Mining) return _tokenId == 3;
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

    function getCavesInfo(
        uint256 _tokenId
    ) external view returns (address, uint256) {
        Lib.Caves memory cave = caves[_tokenId];
        return (cave.owner, cave.stakingTime);
    }

    function getLaborGroundInfo(
        uint256 _tokenId
    ) external view returns (Lib.LaborGround memory) {
        return laborGround[_tokenId];
    }

    function getDevelopmentGroundInfo(
        uint256 _tokenId
    ) external view returns (Lib.DevelopmentGround memory) {
        return developmentGround[_tokenId];
    }

    event EnterCaves(address indexed owner, uint256 indexed tokenId);

    event ClaimDevelopementGroundBonesReward(
        address indexed owner,
        uint256 indexed tokenId,
        bool stake
    );

    event LeaveDevelopmentGround(
        address indexed owner,
        uint256 indexed tokenId
    );

    event ClaimCollectable(address indexed owner, uint256 indexed tokenId);

    event LeaveLaborGround(address indexed owner, uint256 indexed tokenId);

    event RemoveBones(address owner, uint256 tokenId, uint256 amount);

    event StakeBonesInDevelopmentGround(
        address indexed owner,
        uint256 indexed amount,
        uint256 indexed tokenId
    );

    event EnterDevelopmentGround(
        address indexed owner,
        uint256 indexed tokenId,
        uint256 indexed lockTime,
        Lib.Grounds ground
    );

    event BringInAnimalsToLaborGround(
        address indexed owner,
        uint256 indexed tokenId,
        uint256 indexed animalsId
    );

    event ClaimCaveReward(
        address indexed owner,
        uint256 indexed tokenId,
        uint256 indexed amount
    );
}
