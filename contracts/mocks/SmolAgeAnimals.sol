// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

// error
error InvalidTokenId();
error LengthsNotEqual();
error AboveTheMaxSupply();

/**
 * @title SmolAgeAnimals
 */

contract SmolAgeAnimals is ERC1155 {
    constructor() ERC1155("") {
        for (uint256 i; i < 7; ++i) _mint(msg.sender, i, 1, "");
    }
}
