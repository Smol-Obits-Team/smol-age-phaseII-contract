// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Lib} from "./library/Lib.sol";
import {SafeTransferLib} from "solady/src/utils/SafeTransferLib.sol";
import {IBones, IERC20} from "./interfaces/IBones.sol";
import {StringsUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";
import {ITreasure} from "./interfaces/ITreasure.sol";
import {ERC1155Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";

contract Supplies is ERC1155Upgradeable {
    using StringsUpgradeable for uint256;

    address private owner;
    address phase2Address;
    address private treasure;
    address private bones;
    address private magic;

    uint256 constant MAGIC_PRICE = 10 ether; // dont forget
    uint256 constant BONES_PRICE = 1000 ether;
    uint256 constant TREASURE_MOONROCK_VALUE = 5;

    uint256 constant SHOVEL = 1;
    uint256 constant SATCHEL = 2;
    uint256 constant PICK_AXE = 3;

    string private baseUri;

    enum Curr {
        Magic,
        Bones,
        Treasure
    }

    function initialize(string memory _baseUri) external initializer {
        owner = msg.sender;
        baseUri = _baseUri;
    }

    function setPhase2Addresss(address _phase2Address) external {
        if (owner != msg.sender) revert Lib.NotAuthorized();
        phase2Address = _phase2Address;
    }

    /**
     * this token can no be sold on the secondary market
     * only mint it and used for job
     */

    function mint(
        address _to,
        uint256 _tokenId,
        uint256 _amount,
        Curr _curr
    ) public {
        if (_tokenId > 3) revert Lib.InvalidTokenId();
        payForToken(_curr);
        _mint(_to, _tokenId, _amount, "");
    }

    function payForToken(Curr _curr) internal {
        if (_curr == Curr.Magic)
            IERC20(magic).transferFrom(msg.sender, address(this), MAGIC_PRICE);
        if (_curr == Curr.Bones) IBones(bones).burn(msg.sender, BONES_PRICE);
        if (_curr == Curr.Treasure)
            ITreasure(treasure).burn(msg.sender, 1, TREASURE_MOONROCK_VALUE);
    }

    function setApprovalForAll(
        address operator,
        bool approved
    ) public virtual override {
        if (operator != phase2Address) revert Lib.NotAuthorized();
        super.setApprovalForAll(operator, approved);
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
        return string(abi.encodePacked(baseUri, _tokenId.toString()));
    }
}
