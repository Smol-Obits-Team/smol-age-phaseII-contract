//SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;


import {ERC721Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";

contract mERC721 is ERC721Upgradeable {
    uint256 tokenId;

    function initialize() external initializer {
        mint(15);
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

    mapping(uint256 => PrimarySkill) private tokenToSkill;

    mapping(uint256 => uint256) private commonSense;

    function mint(uint256 _amount) public {
        for (uint256 i = 0; i < _amount; ++i) _mint(msg.sender, ++tokenId);
    }

    function developMystics(uint256 _tokenId, uint256 _amount) external {
        tokenToSkill[_tokenId].mystics += _amount;
    }

    function developFarmers(uint256 _tokenId, uint256 _amount) external {
        tokenToSkill[_tokenId].farmers += _amount;
    }

    function developFighter(uint256 _tokenId, uint256 _amount) external {
        tokenToSkill[_tokenId].fighters += _amount;
    }

    function getCommonSense(uint256 _tokenId) external view returns (uint256) {
        return commonSense[_tokenId];
    }

    function getPrimarySkill(
        uint256 _tokenId
    ) external view returns (PrimarySkill memory) {
        return tokenToSkill[_tokenId];
    }
}
