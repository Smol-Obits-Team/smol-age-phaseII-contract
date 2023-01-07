//SPDX-License-Identifier: MIT
pragma solidity 0.8.17;
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IToken is IERC20 {
    function mint(uint256 _amount) external;
}
