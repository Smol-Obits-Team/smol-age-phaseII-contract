// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

contract Supplies is ERC1155 {
    using Strings for uint256;

    uint256 private constant SHOVEL = 0;
    uint256 private constant SATCHEL = 1;
    uint256 private constant PICK_AXE = 2;


    string private baseUri;

    constructor() ERC1155("") {
        baseUri = "";
    }

    function mint(address _to, uint256 _tokenId, uint256 _amount) external {
        assembly {
            if iszero(or(lt(_tokenId, 8), eq(_tokenId, 8))) {
                revert(0x00, 0x00)
            }
        }
        // require(_tokenId < 9);
        _mint(_to, _tokenId, _amount, "");
    }

    function name() external pure returns (string memory) {
        return "";
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
