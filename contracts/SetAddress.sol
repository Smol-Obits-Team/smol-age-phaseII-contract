//SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

contract SetAddress {
    IPits public pits;
    IRandomizer private randomizer;
    IConsumables public consumables;
    INeandersmol public neandersmol;
    IERC1155Upgradeable public animals;
    IERC1155Upgradeable public supplies;
}
