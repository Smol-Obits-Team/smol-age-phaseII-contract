// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Lib} from "./library/Lib.sol";
import {Ownable} from "solady/src/auth/Ownable.sol";
import {SafeTransferLib} from "solady/src/utils/SafeTransferLib.sol";
import {IBones} from "./interfaces/IBones.sol";
import {StringsUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";
import {ITreasure} from "./interfaces/ITreasure.sol";
import {ERC1155Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";

contract Supplies is ERC1155Upgradeable, Ownable {
    using StringsUpgradeable for uint256;

    address public phase2Address;
    address public treasure;
    address public bones;
    address public magic;

    uint256 constant MAGIC_PRICE = 10 ether; 
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

    function initialize(
        address _bones,
        address _magic,
        address _treasure,
        string memory _baseUri
    ) external initializer {
        _initializeOwner(msg.sender);
        bones = _bones;
        magic = _magic;
        treasure = _treasure;
        baseUri = _baseUri;
    }

    function setPhase2Addresss(address _phase2Address) external onlyOwner {
        phase2Address = _phase2Address;
    }

    /**
     * this token can no be sold on the secondary market
     * only mint it and used for job
     */

    function mint(
        uint256[] calldata _tokenId,
        uint256[] calldata _amount,
        Curr[] calldata _curr
    ) public {
        uint256 i;
        if (_tokenId.length != _amount.length || _amount.length != _curr.length)
            revert Lib.LengthsNotEqual();
        for (; i < _tokenId.length; ) {
            if (_tokenId[i] > 3 || _tokenId[i] < 1) revert Lib.InvalidTokenId();
            payForToken(_curr[i], _amount[i]);
            _mint(msg.sender, _tokenId[i], _amount[i], "");
            unchecked {
                ++i;
            }
        }
    }

    function payForToken(Curr _curr, uint256 _amount) internal {
        if (_curr == Curr.Magic)
            SafeTransferLib.safeTransferFrom(
                magic,
                msg.sender,
                address(this),
                MAGIC_PRICE * _amount
            );
        if (_curr == Curr.Bones)
            IBones(bones).burn(msg.sender, BONES_PRICE * _amount);
        if (_curr == Curr.Treasure)
            ITreasure(treasure).burn(
                msg.sender,
                1,
                TREASURE_MOONROCK_VALUE * _amount
            );
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
