//SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {ERC1155BurnableUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155BurnableUpgradeable.sol";

contract mERC1155 is ERC1155BurnableUpgradeable {
    function initialize() external initializer {
        _mint(msg.sender, 1, 50, "");
    }

    function burn(address account, uint256 id, uint256 value) public override {
        super.burn(account, id, value);
    }
}
