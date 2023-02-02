// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "hardhat/console.sol";
import {Lib} from "./library/Lib.sol";
import {IPits} from "./interfaces/IPits.sol";
import {IToken} from "./interfaces/IToken.sol";
import {INeandersmol} from "./interfaces/INeandersmol.sol";
import {IConsumables, IERC1155} from "./interfaces/IConsumables.sol";

contract Phase2 {
    IPits private pits;
    IToken private bones;
    IERC1155 private animals;
    IERC1155 private supplies;
    IConsumables private consumables;
    INeandersmol private neandersmol;

    uint256 private constant TO_WEI = 10 ** 18;

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
        checkLength(_tokenId, _lockTime);
        if (_lockTime.length != _ground.length) revert Lib.LengthsNotEqual();
        if (!pits.validation()) revert Lib.DevelopmentGroundIsLocked();
        for (; i < _tokenId.length; ) {
            (uint256 tokenId, uint256 lockTime) = (_tokenId[i], _lockTime[i]);
            Lib.DevelopmentGround storage token = developmentGround[tokenId];
            Lib.enterDevelopmentGround(neandersmol, pits, tokenId, lockTime);
            neandersmol.transferFrom(msg.sender, address(this), tokenId);
            token.owner = msg.sender;
            token.lockTime = uint128(block.timestamp);
            token.lockPeriod = uint48(lockTime);
            token.lastRewardTime = uint128(block.timestamp);
            token.ground = _ground[i];
            token.currentLockPeriod = pits.getTimeOut();

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
        if (!pits.validation()) revert Lib.DevelopmentGroundIsLocked();
        checkLength(_amount, _tokenId);
        uint256 i;
        for (; i < _amount.length; ) {
            (uint256 tokenId, uint256 amount) = (_tokenId[i], _amount[i]);
            Lib.DevelopmentGround storage devGround = developmentGround[
                tokenId
            ];
            if (bones.balanceOf(msg.sender) < amount)
                revert Lib.BalanceIsInsufficient();
            if (devGround.owner != msg.sender)
                revert Lib.TokenNotInDevelopmentGround();
            if (amount % MINIMUM_BONE_STAKE != 0) revert Lib.WrongMultiple();
            bones.transferFrom(msg.sender, address(this), amount);
            updateDevelopmentGround(devGround, tokenId, amount);
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

    function removeBones(
        uint256[] calldata _tokenId,
        bool[] calldata _all
    ) external {
        if (_tokenId.length != _all.length) revert Lib.LengthsNotEqual();
        uint256 i;
        for (; i < _tokenId.length; ) {
            removeBones(_tokenId[i], _all[i]);
            unchecked {
                ++i;
            }
        }
    }

    function removeBones(uint256 _tokenId, bool _all) internal {
        Lib.DevelopmentGround memory token = developmentGround[_tokenId];
        uint256 i = 1;
        uint256 amount;
        uint48 count;
        for (; i <= token.amountPosition; ++i) {
            // developPrimarySkill(_tokenId); -> dont forget this
            
            uint256 time = trackTime[_tokenId][i];
            uint256 prev = trackTime[_tokenId][i + 1];
            /**
             * init----------------unlock-----------current time
             * currenttime > init + unlock✅
             */
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
            }
        }
        unchecked {
            developmentGround[_tokenId].amountPosition -= count;
        }

        if (_all) {
            developmentGround[_tokenId].bonesStaked = 0;
            if (token.bonesStaked - amount != 0)
                if (!bones.transfer(address(1), token.bonesStaked - amount))
                    revert Lib.TransferFailed(); // change the address(1)
        } else {
            developmentGround[_tokenId].bonesStaked -= amount;
        }
        if (amount != 0)
            if (!bones.transfer(msg.sender, amount))
                revert Lib.TransferFailed();

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

        return
            Lib.calculatePrimarySkill(
                token,
                _tokenId,
                pits,
                trackTime,
                trackToken
            );
    }

    function claimDevelopementGroundBonesReward(
        uint256[] calldata _tokenId,
        bool[] calldata _stake
    ) external {
        if (_tokenId.length != _stake.length) revert Lib.LengthsNotEqual();
        uint256 i;
        for (; i < _tokenId.length; ) {
            uint256 tokenId = _tokenId[i];
            Lib.DevelopmentGround memory token = developmentGround[tokenId];
            if (token.owner != msg.sender) revert Lib.NotYourToken();
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

    function getDevelopmentGroundBonesReward(
        uint256 _tokenId
    ) public view returns (uint256) {
        Lib.DevelopmentGround memory token = developmentGround[_tokenId];
        return Lib.getDevelopmentGroundBonesReward(token, pits);
    }

    function leaveDevelopmentGround(uint256 _tokenId) external {
        Lib.DevelopmentGround memory token = developmentGround[_tokenId];
        if (block.timestamp < token.lockTime + token.lockPeriod)
            revert Lib.NeandersmolsIsLocked();
        if (token.owner != msg.sender) revert Lib.NotYourToken();
        removeBones(_tokenId, true);
        delete developmentGround[_tokenId];
        neandersmol.transferFrom(address(this), msg.sender, _tokenId);
        emit LeaveDevelopmentGround(msg.sender, _tokenId);
    }

    function enterCaves(uint256[] calldata _tokenId) external {
        uint256 i;
        for (; i < _tokenId.length; ) {
            uint256 tokenId = _tokenId[i];
            Lib.Caves storage cave = caves[tokenId];
            if (neandersmol.ownerOf(tokenId) != msg.sender)
                revert Lib.NotYourToken();
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
            if (cave.owner != msg.sender) revert Lib.NotYourToken();
            if (100 days + cave.stakingTime > block.timestamp)
                revert Lib.NeandersmolsIsLocked();
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
        if (reward == 0) revert Lib.ZeroBalanceError();
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
        ) revert Lib.LengthsNotEqual();
        uint256 i;
        for (; i < _tokenId.length; ) {
            (uint256 tokenId, uint256 supplyId) = (_tokenId[i], _supplyId[i]);
            Lib.LaborGround storage labor = laborGround[tokenId];
            Lib.enterLaborGround(neandersmol, tokenId, supplyId, _job[i]);
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

    // update the skill here too
    function removeAnimalsFromLaborGround(
        uint256[] calldata _tokenId,
        uint256[] calldata _animalsId
    ) external {
        checkLength(_tokenId, _animalsId);
        uint256 i;
        for (; i < _tokenId.length; ) {
            uint256 animalsId = _animalsId[i];
            Lib.LaborGround storage labor = laborGround[_tokenId[i]];
            if (labor.owner != msg.sender) revert Lib.NotYourToken();
            if (labor.animalId != animalsId + 1) revert Lib.NotYourToken();
            animals.safeTransferFrom(
                address(this),
                msg.sender,
                animalsId,
                1,
                ""
            );
            labor.animalId = uint32(animalsId) - 1; // added one since animals token id starts from 0
            emit RemoveAnimalsFromLaborGround(
                msg.sender,
                _tokenId[i],
                animalsId
            );
            unchecked {
                ++i;
            }
        }
    }

    // ability of them to remove animals and update the skill
    function bringInAnimalsToLaborGround(
        uint256[] calldata _tokenId,
        uint256[] calldata _animalsId
    ) external {
        checkLength(_tokenId, _animalsId);
        uint256 i;
        for (; i < _tokenId.length; ) {
            uint256 animalsId = _animalsId[i];
            Lib.LaborGround storage labor = laborGround[_tokenId[i]];
            if (labor.owner != msg.sender) revert Lib.NotYourToken();

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

    function claimCollectable(uint256 _tokenId) internal {
        Lib.LaborGround memory labor = laborGround[_tokenId];
        if (msg.sender != labor.owner) revert Lib.NotYourToken();
        if (block.timestamp < labor.lockTime + 3 days)
            revert Lib.CannotClaimNow();
        uint256 consumablesTokenId = checkPossibleClaims(_tokenId, labor);
        if (consumablesTokenId != 0) {
            consumables.mint(msg.sender, consumablesTokenId, 1);
        }
        laborGround[_tokenId].supplyId = 0;
        // set time to zero here
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
                    labor.animalId - 1,
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

    // still check this
    function updateDevelopmentGround(
        Lib.DevelopmentGround storage _devGround,
        uint256 _tokenId,
        uint256 _amount
    ) internal {
        _devGround.bonesStaked += _amount;
        ++_devGround.amountPosition;
        trackToken[_tokenId][block.timestamp] = _amount;
        trackTime[_tokenId][_devGround.amountPosition] = block.timestamp;
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
        return Lib.timeLeftToLeaveCaveInDays(cave);
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

    function checkLength(
        uint256[] calldata _tokenId,
        uint256[] calldata _animalsId
    ) internal pure {
        if (_tokenId.length != _animalsId.length) revert Lib.LengthsNotEqual();
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

    function getAddress()
        external
        view
        returns (address, address, address, address, address, address)
    {
        return (
            address(pits),
            address(bones),
            address(animals),
            address(supplies),
            address(consumables),
            address(neandersmol)
        );
    }

    event EnterCaves(address indexed owner, uint256 indexed tokenId);

    event ClaimDevelopementGroundBonesReward(
        address indexed owner,
        uint256 indexed tokenId,
        bool indexed stake
    );

    event LeaveDevelopmentGround(
        address indexed owner,
        uint256 indexed tokenId
    );

    event ClaimCollectable(address indexed owner, uint256 indexed tokenId);

    event LeaveLaborGround(address indexed owner, uint256 indexed tokenId);

    event RemoveBones(
        address indexed owner,
        uint256 indexed tokenId,
        uint256 indexed amount
    );

    event StakeBonesInDevelopmentGround(
        address indexed owner,
        uint256 indexed amount,
        uint256 indexed tokenId
    );

    event RemoveAnimalsFromLaborGround(
        address indexed owner,
        uint256 indexed tokenId,
        uint256 indexed animalsId
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
