// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Lib} from "./library/Lib.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

contract Consumables is ERC1155 {
    using Strings for uint256;

    uint256 private constant DIRT = 1;
    uint256 private constant HERB = 2;
    uint256 private constant STONES = 3;
    uint256 private constant FERTILE_SOIL = 4;
    uint256 private constant FUNGI = 5;
    uint256 private constant PRECIOUS_MATERIAL = 6;

    string private baseUri;

    mapping(address => bool) private allowedTo;

    constructor() ERC1155("") {
        baseUri = "";
    }

    function setAllowedAddress(address _addr, bool _state) external {
        allowedTo[_addr] = _state;
    }

    function mint(address _to, uint256 _tokenId, uint256 _amount) external {
        if (!allowedTo[msg.sender]) revert Lib.NotAuthorized();
        if (_tokenId > 6) revert Lib.InvalidTokenId();
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
