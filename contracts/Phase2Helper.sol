// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IConsumables, IERC1155} from "./interfaces/IConsumables.sol";
import {IError} from "./interfaces/IError.sol";
import {Lib} from "./library/Lib.sol";
import {Iphase2} from "./interfaces/IPhase2.sol";

/**
 * on halting the reward
 * set the time of when the reward will stop counting after validation
 * when it is no longer valid, update and get the days it was off
 * when calcualating the reward you could check if it is off or not to know the correct formular to use
 * and if updating again? check how long it took in the previous time and add it
 * for a staker check it timestamp if it is greater than the current daysOff timestamp
 * the calculate from the time after the timestamp
 */

contract Phase2Helper is IError {

}
