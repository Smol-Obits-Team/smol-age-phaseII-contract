//SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { Lib } from "./library/Lib.sol";
import { IPits } from "./interfaces/IPits.sol";
import { IBones } from "./interfaces/IBones.sol";
import { IRandomizer } from "./interfaces/IRandomizer.sol";
import { INeandersmol } from "./interfaces/INeandersmol.sol";
import { SafeTransferLib } from "solady/src/utils/SafeTransferLib.sol";

import {
    Initializable
} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {
    DevelopmentGround,
    LaborGround,
    Jobs,
    Grounds,
    DevGroundFe
} from "./library/StructsEnums.sol";
import {
    LengthsNotEqual,
    ZeroBalanceError,
    NotYourToken,
    WrongMultiple,
    CsIsBellowHundred,
    BalanceIsInsufficient,
    InvalidLockTime,
    NeandersmolIsNotInDevelopmentGround,
    NeandersmolsIsLocked
} from "./library/Error.sol";

contract DevelopmentGrounds is Initializable {
    IBones public bones;
    IPits public pits;
    INeandersmol public neandersmol;

    function initialize(
        address _pits,
        address _neandersmol,
        address _bones
    ) external initializer {
        bones = IBones(_bones);
        pits = IPits(_pits);
        neandersmol = INeandersmol(_neandersmol);
    }

    // tokenId -> amount position -> staking time
    mapping(uint256 => mapping(uint256 => uint256)) private trackTime;
    // tokenId -> time -> amount
    mapping(uint256 => mapping(uint256 => uint256)) private trackToken;

    mapping(address => uint256[]) private ownerToTokens;

    mapping(uint256 => DevelopmentGround) private developmentGround;

    uint256 private constant MINIMUM_BONE_STAKE = 1000 * 10 ** 18;

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
        Grounds[] calldata _ground
    ) external {
        uint256 i;
        checkLength(_tokenId, _lockTime);
        if (_lockTime.length != _ground.length) revert LengthsNotEqual();
        Lib.pitsValidation(pits);
        for (; i < _tokenId.length; ++i) {
            (uint256 tokenId, uint256 lockTime) = (_tokenId[i], _lockTime[i]);
            DevelopmentGround storage devGround = developmentGround[tokenId];
            if (neandersmol.getCommonSense(tokenId) < 100)
                revert CsIsBellowHundred();
            if (neandersmol.ownerOf(tokenId) != msg.sender)
                revert NotYourToken();
            if (!lockTimeExists(lockTime)) revert InvalidLockTime();
            neandersmol.transferFrom(msg.sender, address(this), tokenId);
            devGround.owner = msg.sender;
            devGround.entryTime = uint64(block.timestamp);
            devGround.lockPeriod = uint64(lockTime);
            devGround.lastRewardTime = uint64(block.timestamp);
            devGround.ground = _ground[i];
            devGround.currentPitsLockPeriod = pits.getTimeOut();
            ownerToTokens[msg.sender].push(tokenId);
            emit EnterDevelopmentGround(
                msg.sender,
                tokenId,
                lockTime,
                block.timestamp,
                _ground[i]
            );
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
        for (; i < _amount.length; ++i) {
            (uint256 tokenId, uint256 amount) = (_tokenId[i], _amount[i]);
            DevelopmentGround storage devGround = developmentGround[tokenId];
            if (bones.balanceOf(msg.sender) < amount)
                revert BalanceIsInsufficient();
            if (devGround.owner != msg.sender)
                revert NeandersmolIsNotInDevelopmentGround();
            if (amount % MINIMUM_BONE_STAKE != 0) revert WrongMultiple();
            SafeTransferLib.safeTransferFrom(
                address(bones),
                msg.sender,
                address(this),
                amount
            );
            updateDevelopmentGround(devGround, tokenId, amount);
            emit StakeBonesInDevelopmentGround(msg.sender, amount, tokenId);
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
        if (_tokenId.length != _all.length) revert LengthsNotEqual();
        uint256 i;
        for (; i < _tokenId.length; ++i) {
            developPrimarySkill(_tokenId[i]);
            removeBones(_tokenId[i], _all[i]);
        }
    }

    /**
     * @dev Helper function to remove bones from a specific development ground
     * @param _tokenId The unique identifier for the development ground
     * @param _all Indicates whether to remove all bones if it will be taxed or not
     */
    function removeBones(uint256 _tokenId, bool _all) internal {
        DevelopmentGround memory devGround = developmentGround[_tokenId];
        if (devGround.bonesStaked == 0) revert ZeroBalanceError();
        uint256 bal;
        uint256 i = 1;
        uint256 amount;
        uint64 count;

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
        DevelopmentGround memory devGround = developmentGround[_tokenId];
        (uint256 amount, Grounds ground) = (
            getPrimarySkill(_tokenId),
            devGround.ground
        );
        if (ground == Grounds.Chambers) {
            neandersmol.developMystics(_tokenId, amount);
        } else if (ground == Grounds.Garden) {
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
        DevelopmentGround memory token = developmentGround[_tokenId];

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
        DevelopmentGround memory devGround = developmentGround[_tokenId];
        if (devGround.owner != msg.sender) revert NotYourToken();
        uint256 reward = getDevelopmentGroundBonesReward(_tokenId);
        if (reward == 0) revert ZeroBalanceError();
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
        if (_tokenId.length != _stake.length) revert LengthsNotEqual();
        for (uint256 i; i < _tokenId.length; ++i)
            claimDevelopmentGroundBonesReward(_tokenId[i], _stake[i]);
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
        if (remainder == _amount) revert WrongMultiple(); // if the amount is less than Minimum
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
        DevelopmentGround memory devGround = developmentGround[_tokenId];
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
        for (uint256 i; i < _tokenId.length; ++i)
            leaveDevelopmentGround(_tokenId[i]);
    }

    /**
     * @dev Internal function for the leaveDevelopmentGround function to remove the development ground and transfer the token back to the owner.
     * @param _tokenId The token ID of the development ground to leave.
     */

    function leaveDevelopmentGround(uint256 _tokenId) internal {
        DevelopmentGround memory devGround = developmentGround[_tokenId];
        if (devGround.owner != msg.sender) revert NotYourToken();
        if (block.timestamp < devGround.entryTime + devGround.lockPeriod)
            revert NeandersmolsIsLocked();
        if (getDevelopmentGroundBonesReward(_tokenId) > 0)
            claimDevelopmentGroundBonesReward(_tokenId, false);
        if (devGround.bonesStaked > 0) removeBones(_tokenId, true);
        Lib.removeItem(ownerToTokens[msg.sender], (_tokenId));
        delete developmentGround[_tokenId];
        neandersmol.transferFrom(address(this), msg.sender, _tokenId);
        emit LeaveDevelopmentGround(msg.sender, _tokenId);
    }

    /**
     * @dev This function updates the DevelopmentGround by adding `_amount` to `_devGround.bonesStaked` and increments `_devGround.amountPosition`.
     * @param _devGround The DevelopmentGround to be updated.
     * @param _tokenId The token ID associated with the DevelopmentGround.
     * @param _amount The amount to be added to `_devGround.bonesStaked`.
     */

    function updateDevelopmentGround(
        DevelopmentGround storage _devGround,
        uint256 _tokenId,
        uint256 _amount
    ) internal {
        _devGround.bonesStaked += _amount;
        ++_devGround.amountPosition;
        trackToken[_tokenId][block.timestamp] = _amount;
        trackTime[_tokenId][_devGround.amountPosition] = block.timestamp;
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
        if (_tokenId.length != _animalsId.length) revert LengthsNotEqual();
    }

    function lockTimeExists(uint256 _lockTime) internal pure returns (bool) {
        return
            _lockTime == 50 days ||
            _lockTime == 100 days ||
            _lockTime == 150 days;
    }

    /**
     * Retrieve information about a Development Ground token.
     * @dev This function returns a DevelopmentGround struct containing information about a Development Ground token, specified by its ID, _tokenId.
     * @param _tokenId ID of the Development Ground token to retrieve information for
     * @return The DevelopmentGround struct containing information about the specified Development Ground token.
     */

    function getDevelopmentGroundInfo(
        uint256 _tokenId
    ) public view returns (DevelopmentGround memory) {
        return developmentGround[_tokenId];
    }

    function getStakedTokens(
        address _owner
    ) external view returns (uint256[] memory res) {
        return ownerToTokens[_owner];
    }

    function getDevGroundFeInfo(
        address _owner
    ) external view returns (DevGroundFe[] memory) {
        uint256[] memory stakedTokens = ownerToTokens[_owner];
        DevGroundFe[] memory userInfo = new DevGroundFe[](stakedTokens.length);

        uint256 i;
        for (; i < userInfo.length; ++i) {
            uint256 stakedToken = stakedTokens[i];
            DevelopmentGround memory devGround = getDevelopmentGroundInfo(
                stakedToken
            );
            uint256 unlockTime = devGround.lockPeriod + devGround.entryTime;
            uint256 timeLeft = block.timestamp < unlockTime
                ? unlockTime - block.timestamp
                : 0;
            userInfo[i] = DevGroundFe(
                uint96(timeLeft),
                uint96(block.timestamp - devGround.entryTime),
                uint64(stakedToken),
                getPrimarySkill(stakedToken),
                getDevelopmentGroundBonesReward(stakedToken)
            );
        }

        return userInfo;
    }

    event EnterDevelopmentGround(
        address indexed owner,
        uint256 indexed tokenId,
        uint256 indexed lockTime,
        uint256 entryTime,
        Grounds ground
    );

    event ClaimDevelopmentGroundBonesReward(
        address indexed owner,
        uint256 indexed tokenId,
        bool indexed stake
    );

    event RemoveBones(
        address indexed owner,
        uint256 indexed tokenId,
        uint256 indexed amount
    );

    event LeaveDevelopmentGround(
        address indexed owner,
        uint256 indexed tokenId
    );

    event StakeBonesInDevelopmentGround(
        address indexed owner,
        uint256 indexed amount,
        uint256 indexed tokenId
    );
}
