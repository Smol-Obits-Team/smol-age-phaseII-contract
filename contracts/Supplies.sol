// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

contract Supplies is ERC1155 {
    using Strings for uint256;

    uint256 private constant SHOVEL = 1;
    uint256 private constant SATCHEL = 2;
    uint256 private constant PICK_AXE = 3;

    string private baseUri;

    constructor() ERC1155("") {
        baseUri = "";
        mint(msg.sender, 1, 5);
        mint(msg.sender, 2, 5);
        mint(msg.sender, 3, 5);
    }

    function mint(address _to, uint256 _tokenId, uint256 _amount) public {
        require(_tokenId < 4);
        _mint(_to, _tokenId, _amount, "");
    }

    function name() external pure returns (string memory) {
        return "Supplies";
    }

    function symbol() external pure returns (string memory) {
        return "supplies";
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
