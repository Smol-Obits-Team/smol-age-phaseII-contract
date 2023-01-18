//SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface IPits {
    function validation() external view returns (bool);

    function getTimeBelowMinimum() external view returns (uint256);
}
