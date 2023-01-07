// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

library Lib {
    function removeEleement(
        uint256[] storage _arr,
        uint256 _removeElement
    ) external {
        uint256 i;
        for (; i < _arr.length; ++i) {
            if (_arr[i] == _removeElement) {
                _arr[i] == _arr[_arr.length - 1];
                _arr.pop();
                break;
            }
        }
    }

    function sumArray(
        uint256[] calldata _amount
    ) external pure returns (uint256 total) {
        for (uint256 i; i < _amount.length; ++i) total += _amount[i];
    }
}
