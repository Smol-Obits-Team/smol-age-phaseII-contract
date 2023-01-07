// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract mERC721 is ERC721 {
    constructor() ERC721("", "") {
        mint(15);
    }

    struct PrimarySkill {
        uint256 mystics;
        uint256 farmers;
        uint256 fighters;
    }

    mapping(uint256 => PrimarySkill) private tokenToSkill;

    function mint(uint256 _amount) public {
        for (uint256 i; i <= _amount; ++i) _mint(msg.sender, i);
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

    function getPrimarySkill(
        uint256 _tokenId
    ) external view returns (PrimarySkill memory) {
        return tokenToSkill[_tokenId];
    }
}
