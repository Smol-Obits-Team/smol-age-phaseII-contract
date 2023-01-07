//SPDX-License-Identifier: MIT
pragma solidity 0.8.17;
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface INeandersmol is IERC721 {
    function getCommonSense(uint256 _tokenId) external view returns (uint256);

    function developMystics(uint256 _tokenId, uint256 _amount) external;

    function developFarmers(uint256 _tokenId, uint256 _amount) external;

    function developFighter(uint256 _tokenId, uint256 _amount) external;
}
