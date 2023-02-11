//SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface IRandomizer {
    function getRandom(uint256 _num) external view returns (uint256);
}
