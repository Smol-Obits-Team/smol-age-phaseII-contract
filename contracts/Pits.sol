// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Pits {
    IERC20 public bones;
    uint256 private bonesStaked;

    uint256 private constant TO_WEI = 10 ** 18;

    mapping(address => uint256) private balance;

    constructor(address _bones) {
        bones = IERC20(_bones);
    }

    function stakeBonesInYard(uint256 _amount) external {
        require(bones.balanceOf(msg.sender) >= _amount);
        bones.transferFrom(msg.sender, address(this), _amount * TO_WEI);
        balance[msg.sender] += _amount;
        bonesStaked += _amount;
    }

    function removeBonesFromYard(uint256 _amount) external {
        require(_amount >= balance[msg.sender]);
        balance[msg.sender] -= _amount;
        bonesStaked -= _amount;
        require(bones.transfer(msg.sender, _amount * TO_WEI));
    }

    function getStakedBones() external view returns (uint256) {
        return bonesStaked;
    }

    function validation() external view returns (bool) {
        return bonesStaked * TO_WEI >= (bones.totalSupply() * 3) / 10;
    }
}
