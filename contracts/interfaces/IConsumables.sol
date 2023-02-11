//SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

interface IConsumables is IERC1155 {
    function mint(address _to, uint256 _tokenId, uint256 _amount) external;
}
