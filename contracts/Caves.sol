//SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { Remove } from "./library/Remove.sol";
import { IBones } from "./interfaces/IBones.sol";
import { Cave, CavesFeInfo } from "./library/StructsEnums.sol";
import { IPits } from "./interfaces/IPits.sol";
import { Ownable } from "solady/src/auth/Ownable.sol";

import { INeandersmol } from "./interfaces/INeandersmol.sol";

import {
    NotYourToken,
    NeandersmolsIsLocked,
    ZeroBalanceError,
    TokenIsStaked,
    GroundIsLocked,
    InvalidCall
} from "./library/Errors.sol";

import {
    Initializable
} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract Caves is Initializable, Ownable {
    IPits public pits;
    IBones public bones;
    INeandersmol public neandersmol;

    mapping(uint256 => Cave) private caves;

    mapping(address => uint256[]) private ownerToTokens;

    uint256 public lockTime;
    uint256 public multiplier;
    uint256 public receivingPercentage;
    uint256 public passBoost;

    function initialize(
        address _pits,
        address _bones,
        address _neandersmol
    ) external initializer {
        _initializeOwner(msg.sender);
        setAddress(_pits, _bones, _neandersmol);
    }

    function setAddress(
        address _pits,
        address _bones,
        address _neandersmol
    ) public onlyOwner {
        bones = IBones(_bones);
        pits = IPits(_pits);
        neandersmol = INeandersmol(_neandersmol);
    }

    /**
     * @dev Allows the owner to enter the caves. This will transfer the token to the contract and set the owner, staking time, and last reward timestamp for the caves.
     * @param _tokenId The token ID of the caves to enter.
     */

    function enterCaves(uint256[] calldata _tokenId) external {
        if (!pits.validation()) revert GroundIsLocked();
        uint256 i;
        for (; i < _tokenId.length; ++i) {
            uint256 tokenId = _tokenId[i];
            Cave storage cave = caves[tokenId];
            if (neandersmol.ownerOf(tokenId) != msg.sender)
                revert NotYourToken();
            if (neandersmol.staked(tokenId)) revert TokenIsStaked();
            neandersmol.stakingHandler(tokenId, true);
            cave.owner = msg.sender;
            cave.stakingTime = uint48(block.timestamp);
            cave.lastRewardTimestamp = uint48(block.timestamp);
            ownerToTokens[msg.sender].push(tokenId);
            emit EnterCaves(msg.sender, tokenId, block.timestamp);
        }
    }

    /**
     *  @dev Function to allow the owner of a Cave token to leave the cave and claim any rewards.
     * @param _tokenId An array of Cave token IDs to be claimed and left.
     */

    function leaveCave(uint256[] calldata _tokenId) external {
        uint256 i;
        for (; i < _tokenId.length; ++i) {
            uint256 tokenId = _tokenId[i];
            Cave memory cave = caves[tokenId];
            if (cave.owner != msg.sender) revert NotYourToken();
            if (lockTime + cave.stakingTime > block.timestamp)
                revert NeandersmolsIsLocked();
            if (getCavesReward(tokenId) != 0) claimCaveReward(tokenId);
            Remove.removeItem(ownerToTokens[msg.sender], tokenId);
            delete caves[tokenId];
            neandersmol.stakingHandler(tokenId, false);
            emit LeaveCave(msg.sender, tokenId);
        }
    }

    /**
     * @dev Internal function to claim the rewards for a Cave token.
     * @param _tokenId The ID of the Cave token to claim rewards for.
     */

    function claimCaveReward(uint256 _tokenId) internal {
        uint256 reward = getCavesReward(_tokenId);
        if (reward == 0) revert ZeroBalanceError();
        uint256 receiving = (reward * receivingPercentage) / 100;
        caves[_tokenId].lastRewardTimestamp = uint48(block.timestamp);
        bones.mint(address(this), reward);
        bones.transfer(msg.sender, receiving);
        bones.burn(address(this), reward - receiving);
        emit ClaimCaveReward(msg.sender, _tokenId, reward);
    }

    /**
     * @dev Function to allow the caller to claim rewards for multiple Cave tokens.
     * @param _tokenId An array of Cave token IDs to claim rewards for.
     */

    function claimCaveReward(uint256[] calldata _tokenId) external {
        uint256 passMultiplier = stakedCouncilPass(msg.sender);
        uint256 totalReward;

        for (uint256 i; i < _tokenId.length; ++i) {
            totalReward += getCavesReward(_tokenId[i]);
            emit ClaimCaveReward(msg.sender, _tokenId[i], totalReward);
            caves[_tokenId[i]].lastRewardTimestamp = uint48(block.timestamp);
        }
        totalReward = (totalReward * passMultiplier) / 100;
        if (totalReward == 0) revert ZeroBalanceError();
        uint256 reward = (totalReward * passMultiplier * receivingPercentage) /
            10000;
        bones.mint(address(this), totalReward);
        bones.transfer(msg.sender, reward);
        bones.burn(address(this), totalReward - reward);
    }

    /**
     * @dev Function to retrieve the rewards for a Cave token.
     * @param _tokenId The ID of the Cave token to retrieve rewards for.
     * @return The rewards for the stakedCouncilPass Cave token.
     */

    function getCavesReward(uint256 _tokenId) public view returns (uint256) {
        Cave memory cave = caves[_tokenId];
        uint256 boost = fetchBoost(cave.owner);
        if (cave.lastRewardTimestamp == 0) return 0;

        return
            ((multiplier == 0 ? 1 : multiplier) *
                (((block.timestamp - cave.lastRewardTimestamp) / 1 days) *
                    (10 ** 19 + boost)) *
                stakedCouncilPass(cave.owner)) / 100;
    }

    function stakedCouncilPass(address _owner) internal view returns (uint256) {
        (bool ok, bytes memory data) = address(pits).staticcall(
            abi.encodeWithSignature("getPassMultiplier(address)", _owner)
        );
        if (ok) return abi.decode(data, (uint256));

        revert InvalidCall();
    }

    function setReceivingPercentage(
        uint256 _receivingPercentage
    ) external onlyOwner {
        receivingPercentage = _receivingPercentage;
    }

    function fetchBoost(address _owner) internal view returns (uint256 b) {
        uint256 stakedBones = pits.getBonesStaked(_owner);
        if (stakedBones < 5000 ether) return 0;
        if (stakedBones < 10000 ether) {
            return 1 ether;
        } else if (stakedBones < 20000 ether) {
            return 1.5 ether;
        } else if (stakedBones < 30000 ether) {
            return 2 ether;
        } else if (stakedBones < 40000 ether) {
            return 2.5 ether;
        } else if (stakedBones < 50000 ether) {
            return 3 ether;
        } else if (stakedBones < 100000 ether) {
            return 3.5 ether;
        } else if (stakedBones < 250000 ether) {
            return 4 ether;
        } else if (stakedBones < 500000 ether) {
            return 4.5 ether;
        } else if (stakedBones > 499999 ether) {
            return 5 ether;
        }
    }

    /**
     * Retrieve information about a Cave token.
     * @dev This function returns a Caves struct containing information about a Cave token, specified by its ID, _tokenId.
     * @param _tokenId ID of the Cave token to retrieve information for
     * @return  The Caves struct containing information about the specified Cave token.
     */

    function getCavesInfo(uint256 _tokenId) public view returns (Cave memory) {
        return caves[_tokenId];
    }

    function setLockTime(uint256 _lockTime) external onlyOwner {
        lockTime = _lockTime;
    }

    function setMultiplierAmount(uint256 _multiplier) external onlyOwner {
        multiplier = _multiplier;
    }

    /**
     * @dev Returns an array of token IDs that are currently staked by the given owner.
     * @param _owner The address of the owner.
     * @return An array of staked token IDs.
     */

    function getStakedTokens(
        address _owner
    ) public view returns (uint256[] memory) {
        return ownerToTokens[_owner];
    }

    /**
    @dev Retrieves information about a user's staked tokens in the Caves farm.
    @param _user The address of the user whose information is being retrieved.
    @return An array of CavesFeInfo structs containing information about the user's staked tokens,
    including the amount of rewards earned, the token ID, and the time left for the staking period.
    */

    function getCavesFeInfo(
        address _user
    ) external view returns (CavesFeInfo[] memory) {
        uint256[] memory tokenIds = getStakedTokens(_user);
        CavesFeInfo[] memory userInfo = new CavesFeInfo[](tokenIds.length);
        for (uint256 i; i < tokenIds.length; ++i) {
            uint256 timeLeft = lockTime +
                getCavesInfo(tokenIds[i]).stakingTime >
                block.timestamp
                ? lockTime -
                    (block.timestamp - getCavesInfo(tokenIds[i]).stakingTime)
                : 0;
            userInfo[i] = CavesFeInfo(
                getCavesReward(tokenIds[i]),
                uint128(tokenIds[i]),
                uint128(timeLeft)
            );
        }

        return userInfo;
    }

    event EnterCaves(
        address indexed owner,
        uint256 indexed tokenId,
        uint256 indexed stakeTime
    );

    event LeaveCave(address indexed owner, uint256 indexed tokenId);

    event ClaimCaveReward(
        address indexed owner,
        uint256 indexed tokenId,
        uint256 indexed amount
    );
}
