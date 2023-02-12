// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

contract Randomizer {
    uint256 public n;

    function requestRandomNumber() external returns (uint256) {
        return n++;
    }

    function revealRandomNumber(
        uint256 _requestId
    ) external view returns (uint256) {}
}
