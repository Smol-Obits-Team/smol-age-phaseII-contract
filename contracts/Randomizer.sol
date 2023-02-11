// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

contract Randomizer {
    function getRandom(uint256 _num) external view returns (uint256) {
        return
            uint256(
                keccak256(
                    abi.encode(
                        msg.sender,
                        block.number,
                        block.timestamp,
                        block.coinbase
                    )
                )
            ) % _num;
    }
}
