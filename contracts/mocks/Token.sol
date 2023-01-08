// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Token is ERC20 {
    uint256 private constant TOTAL_SUPPLY = 10_000_000 * 10 ** 18;

    constructor() ERC20("", "") {
        _mint(msg.sender, TOTAL_SUPPLY);
    }

    function mint(address _to, uint256 _amount) external {
        _mint(_to, _amount);
    }
}
