//SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

struct DevelopmentGround {
    address owner;
    uint64 lockPeriod;
    uint64 amountPosition;
    uint64 entryTime;
    uint64 lastRewardTime;
    uint256 bonesStaked;
    uint256 currentPitsLockPeriod;
    Grounds ground;
}

struct LaborGround {
    address owner;
    uint32 lockTime;
    uint32 supplyId;
    uint32 animalId;
    uint256 requestId;
    Jobs job;
}

struct Caves {
    address owner;
    uint48 stakingTime;
    uint48 lastRewardTimestamp;
}
enum Jobs {
    Digging,
    Foraging,
    Mining
}

enum Grounds {
    Chambers,
    Garden,
    Battlefield
}
