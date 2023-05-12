//SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {
    ERC1155Upgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";

/**
 * @title SmolAgeAnimals
 */

contract SmolAgeAnimals is ERC1155Upgradeable {
    function initialize() external initializer {
        for (uint256 i; i < 7; ++i) _mint(msg.sender, i, 1, "");
    }

    function mint() external {
        for (uint256 i; i < 7; ++i) _mint(msg.sender, i, 1, "");
    }
}
