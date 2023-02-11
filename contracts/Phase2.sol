// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Lib} from "./library/Lib.sol";
import {IPits} from "./interfaces/IPits.sol";
import {IBones} from "./interfaces/IBones.sol";
import {SafeTransferLib} from "solady/src/utils/SafeTransferLib.sol";
import {IRandomizer} from "./interfaces/IRandomizer.sol";
import {INeandersmol} from "./interfaces/INeandersmol.sol";
import {IConsumables, IERC1155} from "./interfaces/IConsumables.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract Phase2 is Initializable {
    IPits private pits;
    IBones private bones;
    IERC1155 private animals;
    IERC1155 private supplies;
    IRandomizer private randomizer;
    IConsumables private consumables;
    INeandersmol private neandersmol;

    uint256 private constant TO_WEI = 10 ** 18;

    uint256 private constant MINIMUM_BONE_STAKE = 1000 * TO_WEI;

    mapping(uint256 => Lib.Caves) private caves;
    mapping(uint256 => Lib.LaborGround) private laborGround;
    mapping(uint256 => Lib.DevelopmentGround) private developmentGround;
    // tokenId -> amount position -> staking time
    mapping(uint256 => mapping(uint256 => uint256)) private trackTime;
    // tokenId -> time -> amount
    mapping(uint256 => mapping(uint256 => uint256)) private trackToken;

    function initialize(
        address _pits,
        address _bones,
        address _animals,
        address _supplies,
        address _consumables,
        address _neandersmol,
        address _randomizer
    ) external initializer {
        bones = IBones(_bones);
        animals = IERC1155(_animals);
        pits = IPits(_pits);
        supplies = IERC1155(_supplies);
        randomizer = IRandomizer(_randomizer);
        consumables = IConsumables(_consumables);
        neandersmol = INeandersmol(_neandersmol);
    }

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
                block.timestamp,
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
            Lib.stakeBonesInDevelopmentGround(devGround, bones, amount);
            SafeTransferLib.safeTransferFrom(
                address(bones),
                msg.sender,
                address(this),
                amount
            );
            updateDevelopmentGround(devGround, tokenId, amount);
            emit StakeBonesInDevelopmentGround(msg.sender, amount, tokenId);
            unchecked {
                ++i;
            }
        }
    }

    function removeBones(
        uint256[] calldata _tokenId,
        bool[] calldata _all
    ) external {
        if (_tokenId.length != _all.length) revert Lib.LengthsNotEqual();
        uint256 i;
        for (; i < _tokenId.length; ) {
            developPrimarySkill(_tokenId[i]);
            removeBones(_tokenId[i], _all[i]);
            unchecked {
                ++i;
            }
        }
    }

    //@remind check this function again
    function removeBones(uint256 _tokenId, bool _all) internal {
        Lib.DevelopmentGround memory devGround = developmentGround[_tokenId];
        if (devGround.bonesStaked == 0) revert Lib.ZeroBalanceError();
        uint256 bal;
        uint256 i = 1;
        uint256 amount;
        uint48 count;
        unchecked {
            for (; i <= devGround.amountPosition; ++i) {
                (uint256 time, uint256 prev) = (
                    trackTime[_tokenId][i],
                    trackTime[_tokenId][i + 1]
                );
                /*
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
                _all || devGround.amountPosition == 1
                    ? trackTime[_tokenId][i] = 0
                    : trackTime[_tokenId][i] = prev;
                trackToken[_tokenId][time] = 0;

                ++count;
            }

            developmentGround[_tokenId].amountPosition -= count;
            developmentGround[_tokenId].bonesStaked -= amount;

            bal = devGround.bonesStaked - amount;
        }
        if (bal != 0 && _all)
            SafeTransferLib.safeTransfer(address(bones), address(1), bal);

        if (amount != 0)
            SafeTransferLib.safeTransfer(address(bones), msg.sender, bal);

        emit RemoveBones(msg.sender, _tokenId, amount);
    }

    // check this with gas
    function developPrimarySkill(uint256 _tokenId) internal {
        // make sure bones staked is more than 30% the total supply
        Lib.DevelopmentGround memory devGround = developmentGround[_tokenId];
        (uint256 amount, Lib.Grounds ground) = (
            getPrimarySkill(_tokenId),
            devGround.ground
        );
        if (ground == Lib.Grounds.Chambers) {
            neandersmol.developMystics(_tokenId, amount);
        } else if (ground == Lib.Grounds.Garden) {
            neandersmol.developFarmers(_tokenId, amount);
        } else {
            neandersmol.developFighter(_tokenId, amount);
        }
    }

    function getPrimarySkill(uint256 _tokenId) public view returns (uint256) {
        Lib.DevelopmentGround memory token = developmentGround[_tokenId];

        return
            Lib.calculatePrimarySkill(
                token.bonesStaked,
                token.amountPosition,
                token.currentLockPeriod,
                _tokenId,
                pits,
                trackTime,
                trackToken
            );
    }

    function claimDevelopmentGroundBonesReward(
        uint256 _tokenId,
        bool _stake
    ) internal {
        Lib.DevelopmentGround memory devGround = developmentGround[_tokenId];
        if (devGround.owner != msg.sender) revert Lib.NotYourToken();
        uint256 reward = getDevelopmentGroundBonesReward(_tokenId);
        if (reward == 0) revert Lib.ZeroBalanceError();
        developmentGround[_tokenId].lastRewardTime = uint128(block.timestamp);
        _stake
            ? stakeBonesInDevelopmentGround(_tokenId, reward)
            : bones.mint(msg.sender, reward);

        emit ClaimDevelopmentGroundBonesReward(msg.sender, _tokenId, _stake);
    }

    function claimDevelopmentGroundBonesReward(
        uint256[] calldata _tokenId,
        bool[] calldata _stake
    ) external {
        if (_tokenId.length != _stake.length) revert Lib.LengthsNotEqual();
        uint256 i;
        for (; i < _tokenId.length; ) {
            claimDevelopmentGroundBonesReward(_tokenId[i], _stake[i]);
            unchecked {
                ++i;
            }
        }
    }

    function stakeBonesInDevelopmentGround(
        uint256 _tokenId,
        uint256 _amount
    ) internal {
        uint256 remainder = _amount % MINIMUM_BONE_STAKE;
        if (remainder == _amount) revert Lib.WrongMultiple(); // if the amount is less than Minimum
        if (remainder != 0) bones.mint(msg.sender, remainder); // if the amount is greater than minimum but wrong multiple
        uint256 newAmount = _amount - remainder;
        bones.mint(address(this), newAmount);

        updateDevelopmentGround(
            developmentGround[_tokenId],
            _tokenId,
            newAmount
        );
        emit StakeBonesInDevelopmentGround(msg.sender, newAmount, _tokenId);
    }

    function getDevelopmentGroundBonesReward(
        uint256 _tokenId
    ) public view returns (uint256) {
        Lib.DevelopmentGround memory devGround = developmentGround[_tokenId];
        return
            Lib.getDevelopmentGroundBonesReward(
                devGround.currentLockPeriod,
                devGround.lockPeriod,
                devGround.lastRewardTime,
                pits
            );
    }

    function leaveDevelopmentGround(uint256[] calldata _tokenId) external {
        uint256 i;
        for (; i < _tokenId.length; ) {
            leaveDevelopmentGround(_tokenId[i]);
            unchecked {
                ++i;
            }
        }
    }

    function leaveDevelopmentGround(uint256 _tokenId) internal {
        Lib.DevelopmentGround storage devGround = developmentGround[_tokenId];
        Lib.leaveDevelopmentGround(devGround);
        if (devGround.bonesStaked > 0) removeBones(_tokenId, true);
        if (getDevelopmentGroundBonesReward(_tokenId) > 0)
            claimDevelopmentGroundBonesReward(_tokenId, false);
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
            emit EnterCaves(msg.sender, tokenId, block.timestamp);
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
        Lib.Caves memory cave = caves[_tokenId];
        if (cave.stakingTime == 0) return 0;
        return ((block.timestamp - cave.stakingTime) / 1 days) * 10 * TO_WEI;
    }

    function enterLaborGround(
        uint256[] calldata _tokenId,
        uint256[] calldata _supplyId,
        Lib.Jobs[] calldata _job
    ) external {
        checkLength(_tokenId, _supplyId);
        if (_supplyId.length != _job.length) revert Lib.LengthsNotEqual();
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

            emit EnterLaborGround(msg.sender, tokenId, supplyId, _job[i]);

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
            Lib.removeAnimalsFromLaborGround(labor, animalsId);

            animals.safeTransferFrom(
                address(this),
                msg.sender,
                animalsId,
                1,
                ""
            );
            labor.animalId = 0; // added one since animals token id starts from 0
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
            Lib.bringInAnimalsToLaborGround(labor);
            animals.safeTransferFrom(
                msg.sender,
                address(this),
                animalsId,
                1,
                ""
            );
            unchecked {
                labor.animalId = uint32(animalsId) + 1; // added one since animals token id starts from 0
            }

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
        Lib.LaborGround storage labor = laborGround[_tokenId];
        if (msg.sender != labor.owner) revert Lib.NotYourToken();
        if (block.timestamp < labor.lockTime + 3 days)
            revert Lib.CannotClaimNow();
        uint256 consumablesTokenId = checkPossibleClaims(_tokenId, labor);
        if (consumablesTokenId != 0)
            consumables.mint(msg.sender, consumablesTokenId, 1);

        labor.supplyId = 0;
        labor.lockTime = uint32(block.timestamp);
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
        uint256 random = randomizer.getRandom(_amount);
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

    // still check this
    function updateDevelopmentGround(
        Lib.DevelopmentGround storage _devGround,
        uint256 _tokenId,
        uint256 _amount
    ) internal {
        unchecked {
            _devGround.bonesStaked += _amount;
            ++_devGround.amountPosition;
            trackToken[_tokenId][block.timestamp] = _amount;
            trackTime[_tokenId][_devGround.amountPosition] = block.timestamp;
        }
    }

    function checkPossibleClaims(
        uint256 _tokenId,
        Lib.LaborGround memory labor
    ) internal returns (uint256) {
        uint256 rnd = randomizer.getRandom(101);
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

    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes calldata
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
        returns (address, address, address, address, address, address, address)
    {
        return (
            address(pits),
            address(bones),
            address(animals),
            address(supplies),
            address(randomizer),
            address(consumables),
            address(neandersmol)
        );
    }

    event EnterCaves(
        address indexed owner,
        uint256 indexed tokenId,
        uint256 indexed stakeTime
    );

    event ClaimDevelopmentGroundBonesReward(
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
        uint256 entryTime,
        Lib.Grounds ground
    );

    event BringInAnimalsToLaborGround(
        address indexed owner,
        uint256 indexed tokenId,
        uint256 indexed animalsId
    );

    event EnterLaborGround(
        address indexed owner,
        uint256 indexed tokenId,
        uint256 indexed supplyId,
        Lib.Jobs job
    );

    event ClaimCaveReward(
        address indexed owner,
        uint256 indexed tokenId,
        uint256 indexed amount
    );
}
