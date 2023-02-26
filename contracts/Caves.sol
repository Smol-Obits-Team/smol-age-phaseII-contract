//SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Lib} from "./library/Lib.sol";
import {INeandersmol} from "./interfaces/INeandersmol.sol";
import {IBones} from "./interfaces/IBones.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {EnumerableSetUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol";

contract Caves is Initializable {
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.UintSet;
    INeandersmol neandersmol;
    IBones bones;

    mapping(uint256 => Lib.Caves) public caves;

    mapping(address => mapping(uint256 => EnumerableSetUpgradeable.UintSet))
        private ownerToTokens;

    function initialize(
        address _bones,
        address _neandersmol
    ) external initializer {
        bones = IBones(_bones);
        neandersmol = INeandersmol(_neandersmol);
    }

    /**
     * @dev Allows the owner to enter the caves. This will transfer the token to the contract and set the owner, staking time, and last reward timestamp for the caves.
     * @param _tokenId The token ID of the caves to enter.
     */

    function enterCaves(uint256[] calldata _tokenId) external {
        uint256 i;
        for (; i < _tokenId.length; ) {
            uint256 tokenId = _tokenId[i];
            Lib.Caves storage cave = caves[tokenId];
            if (neandersmol.ownerOf(tokenId) != msg.sender)
                revert Lib.NotYourToken();
            neandersmol.transferFrom(msg.sender, address(this), tokenId);
            cave.owner = msg.sender;
            cave.stakingTime = uint48(block.timestamp);
            cave.lastRewardTimestamp = uint48(block.timestamp);
            ownerToTokens[msg.sender][2].add(tokenId);
            emit EnterCaves(msg.sender, tokenId, block.timestamp);
            unchecked {
                ++i;
            }
        }
    }

    /**
     *  @dev Function to allow the owner of a Cave token to leave the cave and claim any rewards.
     * @param _tokenId An array of Cave token IDs to be claimed and left.
     */

    function leaveCave(uint256[] calldata _tokenId) external {
        uint256 i;
        for (; i < _tokenId.length; ) {
            uint256 tokenId = _tokenId[i];
            Lib.Caves memory cave = caves[tokenId];
            if (cave.owner != msg.sender) revert Lib.NotYourToken();
            if (100 days + cave.stakingTime > block.timestamp)
                revert Lib.NeandersmolsIsLocked();
            if (getCavesReward(tokenId) != 0) claimCaveReward(tokenId);
            ownerToTokens[msg.sender][0].remove(tokenId);
            delete caves[tokenId];
            neandersmol.transferFrom(address(this), msg.sender, tokenId);
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @dev Internal function to claim the rewards for a Cave token.
     * @param _tokenId The ID of the Cave token to claim rewards for.
     */

    function claimCaveReward(uint256 _tokenId) internal {
        uint256 reward = getCavesReward(_tokenId);
        if (reward == 0) revert Lib.ZeroBalanceError();
        caves[_tokenId].lastRewardTimestamp = uint48(block.timestamp);
        bones.mint(msg.sender, reward);
        emit ClaimCaveReward(msg.sender, _tokenId, reward);
    }

    /**
     * @dev Function to allow the caller to claim rewards for multiple Cave tokens.
     * @param _tokenId An array of Cave token IDs to claim rewards for.
     */

    function claimCaveReward(uint256[] calldata _tokenId) external {
        uint256 i;
        for (; i < _tokenId.length; ) {
            claimCaveReward(_tokenId[i]);
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @dev Function to retrieve the rewards for a Cave token.
     * @param _tokenId The ID of the Cave token to retrieve rewards for.
     * @return The rewards for the specified Cave token.
     */

    function getCavesReward(uint256 _tokenId) public view returns (uint256) {
        Lib.Caves memory cave = caves[_tokenId];
        if (cave.lastRewardTimestamp == 0) return 0;
        return
            ((block.timestamp - cave.lastRewardTimestamp) / 1 days) *
            10 *
            10 ** 18;
    }

    event EnterCaves(
        address indexed owner,
        uint256 indexed tokenId,
        uint256 indexed stakeTime
    );

    event ClaimCaveReward(
        address indexed owner,
        uint256 indexed tokenId,
        uint256 indexed amount
    );
}
