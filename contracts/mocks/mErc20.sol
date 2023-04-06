//SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {
    ERC20Upgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

contract mERC20 is ERC20Upgradeable {
    uint256 private constant TOTAL_SUPPLY = 10_000_000 * 10 ** 18;

    function initialize() external initializer {
        __ERC20_init("Mock Token", "MTKN");
        _mint(msg.sender, TOTAL_SUPPLY);
    }
}
