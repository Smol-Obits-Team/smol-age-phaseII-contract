//SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {IERC721Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";

interface INeandersmol is IERC721Upgradeable {
    function getCommonSense(uint256 _tokenId) external view returns (uint256);

    function developMystics(uint256 _tokenId, uint256 _amount) external;

    function developFarmers(uint256 _tokenId, uint256 _amount) external;

    function developFighter(uint256 _tokenId, uint256 _amount) external;
}
