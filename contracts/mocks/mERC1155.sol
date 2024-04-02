//SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {
    ERC1155BurnableUpgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155BurnableUpgradeable.sol";

contract mERC1155 is ERC1155BurnableUpgradeable {
    string public tokenuUri;

    function initialize() external initializer {
        _mint(msg.sender, 1, 50, "");
    }

    function mint(uint256 _amount) external {
        _mint(msg.sender, 1, _amount, "");
    }

       function mintPass(uint256 _amount) external {
        _mint(msg.sender, 0, _amount, "");
    }

    function burn(address account, uint256 id, uint256 value) public override {
        super.burn(account, id, value);
    }

    function uri(uint256) public pure override returns (string memory) {
        return "ipfs://QmUk5ip5dKSf1ixUKCwky3eTJTgUJuF2StTbYQZ8FHnpop";
    }
}
