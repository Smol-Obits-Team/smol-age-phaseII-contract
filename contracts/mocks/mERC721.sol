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

import { NotAContract, NotAuthorized } from "../library/Error.sol";

contract mERC721 is ERC721Upgradeable, Ownable {
    using StringsUpgradeable for uint256;
    uint256 public tokenId;

    string public uri;

    modifier isAllowed() {
        _isAllowed();
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

    mapping(address => bool) public allowedTo;

    mapping(uint256 => PrimarySkill) private tokenToSkill;

    mapping(uint256 => uint256) private commonSense;

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

    function setAuthorizedAddress(
        address _addr,
        bool _state
    ) external onlyOwner {
        if (_addr.code.length == 0) revert NotAContract();
        allowedTo[_addr] = _state;
    }

    function _isAllowed() internal view {
        if (!allowedTo[msg.sender]) revert NotAuthorized();
    }

    function stake() external {}

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 firstTokenId,
        uint256 batchSize
    ) internal virtual override {
        super._beforeTokenTransfer(from, to, firstTokenId, batchSize);
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
