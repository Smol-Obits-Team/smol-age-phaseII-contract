// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Lib} from "../library/Lib.sol";

interface Iphase2 {
    function getLaborGroundInfo(
        uint256 _tokenId
    ) external view returns (Lib.LaborGround memory);
}
