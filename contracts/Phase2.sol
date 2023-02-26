//SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Lib} from "./library/Lib.sol";
import {IPits} from "./interfaces/IPits.sol";
import {IBones} from "./interfaces/IBones.sol";
import {IRandomizer} from "./interfaces/IRandomizer.sol";
import {INeandersmol} from "./interfaces/INeandersmol.sol";
import {SafeTransferLib} from "solady/src/utils/SafeTransferLib.sol";
import {IConsumables, IERC1155Upgradeable} from "./interfaces/IConsumables.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {EnumerableSetUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol";

contract Phase2 is Initializable {
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.UintSet;
    IPits private pits;
    IBones private bones;
    IRandomizer private randomizer;
    IConsumables private consumables;
    INeandersmol private neandersmol;
    IERC1155Upgradeable private animals;
    IERC1155Upgradeable private supplies;

    uint256 private constant MINIMUM_BONE_STAKE = 1000 * 10 ** 18;

    mapping(uint256 => Lib.LaborGround) public laborGround;
    mapping(uint256 => Lib.DevelopmentGround) public developmentGround;

    // tokenId -> amount position -> staking time
    mapping(uint256 => mapping(uint256 => uint256)) private trackTime;
    // tokenId -> time -> amount
    mapping(uint256 => mapping(uint256 => uint256)) private trackToken;

    mapping(address => mapping(uint256 => EnumerableSetUpgradeable.UintSet))
        private ownerToTokens;

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
        animals = IERC1155Upgradeable(_animals);
        pits = IPits(_pits);
        supplies = IERC1155Upgradeable(_supplies);
        randomizer = IRandomizer(_randomizer);
        consumables = IConsumables(_consumables);
        neandersmol = INeandersmol(_neandersmol);
    }

    /**
     * @dev Enters the DevelopmentGround by transferring the tokens from the sender to the contract
     * and setting the development ground data such as owner, entry time, lock period, etc.
     * @param _tokenId Array of token IDs to be transferred
     * @param _lockTime Array of lock times for each corresponding token
     * @param _ground Array of grounds for each corresponding token
     */

    function enterDevelopmentGround(
        uint256[] calldata _tokenId,
        uint256[] calldata _lockTime,
        Lib.Grounds[] calldata _ground
    ) external {
        uint256 i;
        checkLength(_tokenId, _lockTime);
        if (_lockTime.length != _ground.length) revert Lib.LengthsNotEqual();
        Lib.pitsValidation(pits);
        for (; i < _tokenId.length; ) {
            (uint256 tokenId, uint256 lockTime) = (_tokenId[i], _lockTime[i]);
            Lib.DevelopmentGround storage devGround = developmentGround[
                tokenId
            ];
            Lib.enterDevelopmentGround(neandersmol, tokenId, lockTime);
            neandersmol.transferFrom(msg.sender, address(this), tokenId);
            devGround.owner = msg.sender;
            devGround.entryTime = uint64(block.timestamp);
            devGround.lockPeriod = uint64(lockTime);
            devGround.lastRewardTime = uint64(block.timestamp);
            devGround.ground = _ground[i];
            devGround.currentPitsLockPeriod = pits.getTimeOut();
            ownerToTokens[msg.sender][0].add(tokenId);
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

    /**
     * @dev Stakes the bones in the DevelopmentGround by transferring the bones from the sender to the contract
     * and updating the development ground data.
     * @param _amount Array of amounts of bones to be transferred
     * @param _tokenId Array of token IDs for the corresponding amounts of bones
     */

    function stakeBonesInDevelopmentGround(
        uint256[] calldata _amount,
        uint256[] calldata _tokenId
    ) external {
        Lib.pitsValidation(pits);
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

    /**
     * @dev Removes bones from a specific development ground.
     * @param _tokenId The unique identifier for the development ground
     * @param _all Indicates whether to remove all bones or just a portion of them
     */

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

    /**
     * @dev Helper function to remove bones from a specific development ground
     * @param _tokenId The unique identifier for the development ground
     * @param _all Indicates whether to remove all bones if it will be taxed or not
     */
    function removeBones(uint256 _tokenId, bool _all) internal {
        Lib.DevelopmentGround memory devGround = developmentGround[_tokenId];
        if (devGround.bonesStaked == 0) revert Lib.ZeroBalanceError();
        uint256 bal;
        uint256 i = 1;
        uint256 amount;
        uint64 count;
        unchecked {
            for (; i <= devGround.amountPosition; ++i) {
                (uint256 time, uint256 prev) = (
                    trackTime[_tokenId][i],
                    trackTime[_tokenId][i + 1]
                );
                if (block.timestamp < time + 30 days && !_all) continue;

                block.timestamp < time + 30 days && _all
                    ? amount += trackToken[_tokenId][time] / 2
                    : amount += trackToken[_tokenId][time];

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

    /**
     *  This function develops the primary skill of the `_tokenId` development ground.
     * @param _tokenId ID of the development ground
     */

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

    /**
     * This function retrieves the primary skill of the `_tokenId` development ground.
     * @param _tokenId ID of the development ground
     * @return The primary skill level
     */

    function getPrimarySkill(uint256 _tokenId) public view returns (uint256) {
        Lib.DevelopmentGround memory token = developmentGround[_tokenId];

        return
            Lib.calculatePrimarySkill(
                token.bonesStaked,
                token.amountPosition,
                token.currentPitsLockPeriod,
                _tokenId,
                pits,
                trackTime,
                trackToken
            );
    }

    /**
     * This function allows the owner of the development ground to claim the rewards earned by the development ground.
     * @param _tokenId ID of the development ground
     * @param _stake Whether to stake the reward bones in the development ground
     */

    function claimDevelopmentGroundBonesReward(
        uint256 _tokenId,
        bool _stake
    ) internal {
        Lib.DevelopmentGround memory devGround = developmentGround[_tokenId];
        if (devGround.owner != msg.sender) revert Lib.NotYourToken();
        uint256 reward = getDevelopmentGroundBonesReward(_tokenId);
        if (reward == 0) revert Lib.ZeroBalanceError();
        developmentGround[_tokenId].lastRewardTime = uint64(block.timestamp);
        _stake
            ? stakeBonesInDevelopmentGround(_tokenId, reward)
            : bones.mint(msg.sender, reward);

        emit ClaimDevelopmentGroundBonesReward(msg.sender, _tokenId, _stake);
    }

    /**
     * This function allows the owner of multiple development grounds to claim rewards earned by them.
     * @param _tokenId ID of the development ground
     * @param _stake Whether to stake the reward bones in the development ground
     */

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

    /**
     * @dev Stakes the specified amount of Bones in the Development Ground of the specified token ID.
     * @param _tokenId The ID of the Neandersmol token that represents the Development Ground.
     * @param _amount The amount of Bones to be staked.
     */
    function stakeBonesInDevelopmentGround(
        uint256 _tokenId,
        uint256 _amount
    ) internal {
        uint256 remainder = _amount % MINIMUM_BONE_STAKE;
        if (remainder == _amount) revert Lib.WrongMultiple(); // if the amount is less than Minimum
        if (remainder != 0) bones.mint(msg.sender, remainder); // if the amount is greater than minimum but wrong multiple
        uint256 newAmount = _amount - remainder;
        updateDevelopmentGround(
            developmentGround[_tokenId],
            _tokenId,
            newAmount
        );
        bones.mint(address(this), newAmount);
        emit StakeBonesInDevelopmentGround(msg.sender, newAmount, _tokenId);
    }

    /**
     * @dev Returns the reward for the bones staked in the development ground.
     * @param _tokenId The token ID for the development ground.
     * @return The reward for the bones staked in the development ground.
     */

    function getDevelopmentGroundBonesReward(
        uint256 _tokenId
    ) public view returns (uint256) {
        Lib.DevelopmentGround memory devGround = developmentGround[_tokenId];
        return
            Lib.getDevelopmentGroundBonesReward(
                devGround.currentPitsLockPeriod,
                devGround.lockPeriod,
                devGround.lastRewardTime,
                pits
            );
    }

    /**
     * @dev Allows the owner to leave the development ground. This will transfer the token back to the owner and remove any bones staked in the development ground.
     * @param _tokenId The token ID of the development ground to leave.
     */

    function leaveDevelopmentGround(uint256[] calldata _tokenId) external {
        uint256 i;
        for (; i < _tokenId.length; ) {
            leaveDevelopmentGround(_tokenId[i]);
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @dev Internal function for the leaveDevelopmentGround function to remove the development ground and transfer the token back to the owner.
     * @param _tokenId The token ID of the development ground to leave.
     */

    function leaveDevelopmentGround(uint256 _tokenId) internal {
        Lib.DevelopmentGround storage devGround = developmentGround[_tokenId];
        Lib.leaveDevelopmentGround(devGround);
        if (getDevelopmentGroundBonesReward(_tokenId) > 0)
            claimDevelopmentGroundBonesReward(_tokenId, false);
        if (devGround.bonesStaked > 0) removeBones(_tokenId, true);
        ownerToTokens[msg.sender][2].remove(_tokenId);
        delete developmentGround[_tokenId];
        neandersmol.transferFrom(address(this), msg.sender, _tokenId);
        emit LeaveDevelopmentGround(msg.sender, _tokenId);
    }

    /**
     * @notice Enters the labor ground with specified token ID and supply ID,
     * and assigns the job to it. Transfers the token and supply ownership to the contract.
     * Emits the "EnterLaborGround" event.
     * @param _tokenId Array of token IDs of the labor grounds.
     * @param _supplyId Array of supply IDs associated with the labor grounds.
     * @param _job Array of jobs assigned to the labor grounds.
     */

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
            labor.requestId = randomizer.requestRandomNumber();
            ownerToTokens[msg.sender][1].add(tokenId);
            emit EnterLaborGround(msg.sender, tokenId, supplyId, _job[i]);

            unchecked {
                ++i;
            }
        }
    }

    /**
     *  Brings in animals to the labor ground by calling the bringInAnimalsToLaborGround function in the Lib library and transferring the ownership of the animal token from the sender to the contract.
     * @param _tokenId An array of token IDs representing the labor grounds.
     * @param _animalsId An array of token IDs representing the animals.
     */

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

    /**
     * @notice Removes the animals from the specified labor ground.
     * Transfers the ownership of the animals back to the sender.
     * @param _tokenId Array of token IDs of the labor grounds.
     * @param _animalsId Array of animals IDs associated with the labor grounds.
     */
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
            labor.animalId = 0;
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

    /**
     * This function allows the token owner to claim a collectable. If the token owner is not the same as the
     * stored owner or the lock time has not yet passed, the function will revert. If there are possible claims,
     * a consumables token will be minted for the token owner. The lock time for the labor ground is then updated.
     * @param _tokenId The id of the labor ground token being claimed.
     */

    function claimCollectable(uint256 _tokenId) internal {
        Lib.LaborGround storage labor = laborGround[_tokenId];
        if (msg.sender != labor.owner) revert Lib.NotYourToken();
        if (block.timestamp < labor.lockTime + 3 days)
            revert Lib.CannotClaimNow();
        uint256 consumablesTokenId = checkPossibleClaims(_tokenId, labor);
        if (consumablesTokenId != 0)
            consumables.mint(msg.sender, consumablesTokenId, 1);

        labor.lockTime = uint32(block.timestamp);
        emit ClaimCollectable(msg.sender, _tokenId);
    }

    /** 
    *@dev This function allows a user to claim multiple collectables at once by providing an array of token IDs.
     @param _tokenId An array of token IDs that the user wants to claim.
*/
    function claimCollectables(uint256[] calldata _tokenId) external {
        uint256 i;
        for (; i < _tokenId.length; ) {
            claimCollectable(_tokenId[i]);
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @dev This function decides whether the supply will break or fail when the random number generated is smaller than `_min`.
     * @param _tokenId ID of the token that the supply is associated with.
     * @param _supplyId ID of the supply.
     * @param _amount Total amount of possible outcomes.
     * @param _min The minimum value of the random number that will cause the supply to break or fail.
     * @param _requestId Request ID for accessing the random number.
     */
    function breakOrFailed(
        uint256 _tokenId,
        uint256 _supplyId,
        uint256 _amount,
        uint256 _min,
        uint256 _requestId
    ) internal {
        uint256 random = randomizer.revealRandomNumber(_requestId) % _amount;
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

    /**
     * @dev This function allows a user to leave the LaborGround and receive their animal, supply, and collectable.
     * @param _tokenId An array of token IDs that the user wants to leave.
     */

    function leaveLaborGround(uint256[] calldata _tokenId) external {
        uint256 i;

        for (; i < _tokenId.length; ) {
            uint256 tokenId = _tokenId[i];
            claimCollectable(tokenId);
            Lib.LaborGround memory labor = laborGround[tokenId];
            delete laborGround[tokenId];
            ownerToTokens[msg.sender][1].remove(tokenId);
            if (labor.animalId != 0)
                animals.safeTransferFrom(
                    address(this),
                    msg.sender,
                    labor.animalId - 1,
                    1,
                    ""
                );

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

    /**
     * @dev This function updates the DevelopmentGround by adding `_amount` to `_devGround.bonesStaked` and increments `_devGround.amountPosition`.
     * @param _devGround The DevelopmentGround to be updated.
     * @param _tokenId The token ID associated with the DevelopmentGround.
     * @param _amount The amount to be added to `_devGround.bonesStaked`.
     */

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

    /**
     * @dev Function to check the possible claims of an animal job
     * @param _tokenId ID of the token
     * @param labor LaborGround struct with the information of the job
     * @return consumablesTokenId The token ID of the consumables to be claimed
     */

    function checkPossibleClaims(
        uint256 _tokenId,
        Lib.LaborGround memory labor
    ) internal returns (uint256) {
        uint256 rnd = randomizer.revealRandomNumber(labor.requestId) % 101;
        uint256 animalId = labor.animalId;
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
            breakOrFailed(_tokenId, labor.supplyId, max, min, labor.requestId);

        if (animalId == 4) consumablesTokenId = rnd < 71 ? tokenOne : tokenTwo;

        if (animalId == 5) consumablesTokenId = rnd < 66 ? tokenOne : tokenTwo;

        if (animalId == 6) consumablesTokenId = rnd < 61 ? tokenOne : tokenTwo;

        return consumablesTokenId;
    }

    /**
     * @dev Function to get the consumables token IDs based on the job type
     * @param _job Job type
     * @return tokenIdOne and tokenIdTwo The token IDs of the consumables for the job
     */

    function getConsumablesTokenId(
        Lib.Jobs _job
    ) internal pure returns (uint256 tokenIdOne, uint256 tokenIdTwo) {
        if (_job == Lib.Jobs.Digging) (tokenIdOne, tokenIdTwo) = (1, 4);
        if (_job == Lib.Jobs.Foraging) (tokenIdOne, tokenIdTwo) = (2, 5);
        if (_job == Lib.Jobs.Mining) (tokenIdOne, tokenIdTwo) = (3, 6);
    }

    /**
     *Check the length of two input arrays, _tokenId and _animalsId, for equality.
     *If the lengths are not equal, the function will revert with the error "LengthsNotEqual".
     *@dev Internal function called by other functions within the contract.
     *@param _tokenId Array of token IDs
     */

    function checkLength(
        uint256[] calldata _tokenId,
        uint256[] calldata _animalsId
    ) internal pure {
        if (_tokenId.length != _animalsId.length) revert Lib.LengthsNotEqual();
    }

    /**
     * Handle incoming ERC1155 token transfers.
     * @dev This function is the onERC1155Received fallback function for the contract, which is triggered when the contract receives an ERC1155 token transfer.
     * @return The selector for this function, "0x20f90a7e".
     */

    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes calldata
    ) external pure returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    function getStakedTokens(
        address _owner,
        uint256 _pos
    ) external view returns (uint256[] memory res) {
        return ownerToTokens[_owner][_pos].values();
    }

    /**
     * @notice Returns the addresses of various contract instances that are used in this contract.
     */
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
}
