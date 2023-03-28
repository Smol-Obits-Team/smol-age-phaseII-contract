//SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { Lib } from "../library/Lib.sol";
import { Ownable } from "solady/src/auth/Ownable.sol";
import {
    StringsUpgradeable
} from "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";
import {
    ERC721Upgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";

import {
    NotAContract,
    NotAuthorized,
    TokenIsStaked
} from "../library/Error.sol";

/**
 * only dev ground is allowed to upgrade the primary skills
 * dev ground, labor ground and caves are allowed to call the staking
 * contracts
 */

contract mERC721 is ERC721Upgradeable, Ownable {
    using StringsUpgradeable for uint256;

    string public uri;
    uint256 public tokenId;

    mapping(address => bool) public allowedToUpdateSkill;
    mapping(address => bool) public allowedToHandleStaking;

    mapping(uint256 => bool) private staked;
    mapping(uint256 => uint256) private commonSense;
    mapping(uint256 => PrimarySkill) private tokenToSkill;

    modifier isAllowed() {
        if (!allowedToUpdateSkill[msg.sender]) revert NotAuthorized();
        _;
    }

    function initialize() external initializer {
        mint(15);
        _initializeOwner(msg.sender);
        commonSense[1] = 101;
        commonSense[2] = 98;
        commonSense[3] = 100;
        commonSense[10] = 100;
        commonSense[16] = 100;
    }

    struct PrimarySkill {
        uint256 mystics;
        uint256 farmers;
        uint256 fighters;
    }

    function mint(uint256 _amount) public {
        for (uint256 i = 0; i < _amount; ++i) _mint(msg.sender, ++tokenId);
    }

    function developMystics(
        uint256 _tokenId,
        uint256 _amount
    ) external isAllowed {
        tokenToSkill[_tokenId].mystics += _amount;
    }

    function developFarmers(
        uint256 _tokenId,
        uint256 _amount
    ) external isAllowed {
        tokenToSkill[_tokenId].farmers += _amount;
    }

    function developFighter(
        uint256 _tokenId,
        uint256 _amount
    ) external isAllowed {
        tokenToSkill[_tokenId].fighters += _amount;
    }

    function getCommonSense(uint256 _tokenId) external view returns (uint256) {
        return commonSense[_tokenId];
    }

    function setPrimarySkillUpdater(
        address _addr,
        bool _state
    ) external onlyOwner {
        allowedToUpdateSkill[_addr] = _state;
    }

    function setStakingHandlers(
        address[] calldata _addr,
        bool _state
    ) external onlyOwner {
        for (uint256 i; i < _addr.length; ++i)
            allowedToHandleStaking[_addr[i]] = _state;
    }

    function stakingHandler(uint256 _tokenId, bool _state) external {
        if (!allowedToHandleStaking[msg.sender]) revert NotAuthorized();
        staked[_tokenId] = _state;
    }

    function _beforeTokenTransfer(
        address _from,
        address _to,
        uint256 _firstTokenId,
        uint256 _batchSize
    ) internal virtual override {
        if (staked[_firstTokenId]) revert TokenIsStaked();
        super._beforeTokenTransfer(_from, _to, _firstTokenId, _batchSize);
    }

    function getPrimarySkill(
        uint256 _tokenId
    ) external view returns (PrimarySkill memory) {
        return tokenToSkill[_tokenId];
    }

    function setURI(string memory _uri) external onlyOwner {
        uri = _uri;
    }

    function tokenURI(
        uint256 _tokenId
    ) public view override returns (string memory) {
        return string(abi.encodePacked(uri, _tokenId.toString()));
    }
}
