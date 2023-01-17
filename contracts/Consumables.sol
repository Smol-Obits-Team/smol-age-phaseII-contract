// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

contract Consumables is ERC1155 {
    using Strings for uint256;

    uint256 private constant DIRT = 0;
    uint256 private constant HERB = 1;
    uint256 private constant STONES = 2;
    uint256 private constant FERTILE_SOIL = 3;
    uint256 private constant FUNGI = 4;
    uint256 private constant PRECIOUS_MATERIAL = 5;

    string private baseUri;

    constructor() ERC1155("") {
        baseUri = "";
    }

    function mint(address _to, uint256 _tokenId, uint256 _amount) external {
        require(_tokenId < 6);
        _mint(_to, _tokenId, _amount, "");
    }

    function name() external pure returns (string memory) {
        return "Consumables";
    }

    function symbol() external pure returns (string memory) {
        return "";
    }

    function uri(
        uint256 _tokenId
    ) public view override returns (string memory) {
        return
            bytes(baseUri).length > 0
                ? string(abi.encode(baseUri, _tokenId))
                : "";
    }
}
