//SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface ITreasure {
    function burn(address account, uint256 id, uint256 value) external;
}
