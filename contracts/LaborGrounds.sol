//SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { Lib } from "./library/Lib.sol";
import { IPits } from "./interfaces/IPits.sol";
import { IRandomizer } from "./interfaces/IRandomizer.sol";
import { INeandersmol } from "./interfaces/INeandersmol.sol";
import { SafeTransferLib } from "solady/src/utils/SafeTransferLib.sol";
import {
    IConsumables,
    IERC1155Upgradeable
} from "./interfaces/IConsumables.sol";
import {
    Initializable
} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {
    EnumerableSetUpgradeable
} from "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol";

import {
    LengthsNotEqual,
    ZeroBalanceError,
    NotYourToken,
    WrongMultiple,
    CannotClaimNow
} from "./library/Error.sol";

import {
    DevelopmentGround,
    LaborGround,
    Jobs,
    Grounds
} from "./library/StructsEnums.sol";

contract LaborGrounds is Initializable {
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.UintSet;
    IPits public pits;
    IRandomizer public randomizer;
    IConsumables public consumables;
    INeandersmol public neandersmol;
    IERC1155Upgradeable public animals;
    IERC1155Upgradeable public supplies;

    mapping(uint256 => LaborGround) private laborGround;

    mapping(address => EnumerableSetUpgradeable.UintSet) private ownerToTokens;

    function initialize(
        address _pits,
        address _animals,
        address _supplies,
        address _consumables,
        address _neandersmol,
        address _randomizer
    ) external initializer {
        animals = IERC1155Upgradeable(_animals);
        pits = IPits(_pits);
        supplies = IERC1155Upgradeable(_supplies);
        randomizer = IRandomizer(_randomizer);
        consumables = IConsumables(_consumables);
        neandersmol = INeandersmol(_neandersmol);
    }

    /**
     * @notice Enters the labor ground with specified token ID and supply ID,
     * and assigns the job to it. Transfers the token and supply ownership to the contract.
     * Emits the "EnterLaborGround" event.
     * @param _tokenId Array of token IDs of the labor grounds.
     * @param _supplyId Array of supply IDs associated with the labor grounds.
     * @param _job Array of jobs assigned to the labor grounds.
     */

    function enterLaborGround(
        uint256[] calldata _tokenId,
        uint256[] calldata _supplyId,
        Jobs[] calldata _job
    ) external {
        Lib.pitsValidation(pits);
        checkLength(_tokenId, _supplyId);
        if (_supplyId.length != _job.length) revert LengthsNotEqual();
        uint256 i;
        for (; i < _tokenId.length; ) {
            (uint256 tokenId, uint256 supplyId) = (_tokenId[i], _supplyId[i]);
            LaborGround storage labor = laborGround[tokenId];
            Lib.enterLaborGround(neandersmol, tokenId, supplyId, _job[i]);
            supplies.safeTransferFrom(
                msg.sender,
                address(this),
                supplyId,
                1,
                ""
            );
            neandersmol.transferFrom(msg.sender, address(this), tokenId);
            labor.owner = msg.sender;
            labor.lockTime = uint32(block.timestamp);
            labor.supplyId = uint32(supplyId);
            labor.job = _job[i];
            labor.requestId = randomizer.requestRandomNumber();
            ownerToTokens[msg.sender].add(tokenId);
            emit EnterLaborGround(msg.sender, tokenId, supplyId, _job[i]);

            unchecked {
                ++i;
            }
        }
    }

    /**
     *  Brings in animals to the labor ground by calling the bringInAnimalsToLaborGround function in the Lib library and transferring the ownership of the animal token from the sender to the contract.
     * @param _tokenId An array of token IDs representing the labor grounds.
     * @param _animalsId An array of token IDs representing the animals.
     */

    function bringInAnimalsToLaborGround(
        uint256[] calldata _tokenId,
        uint256[] calldata _animalsId
    ) external {
        checkLength(_tokenId, _animalsId);
        uint256 i;
        for (; i < _tokenId.length; ) {
            uint256 animalsId = _animalsId[i];
            LaborGround storage labor = laborGround[_tokenId[i]];
            Lib.bringInAnimalsToLaborGround(labor);
            animals.safeTransferFrom(
                msg.sender,
                address(this),
                animalsId,
                1,
                ""
            );
            unchecked {
                labor.animalId = uint32(animalsId) + 1; // added one since animals token id starts from 0
            }

            emit BringInAnimalsToLaborGround(
                msg.sender,
                _tokenId[i],
                animalsId
            );
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Removes the animals from the specified labor ground.
     * Transfers the ownership of the animals back to the sender.
     * @param _tokenId Array of token IDs of the labor grounds.
     * @param _animalsId Array of animals IDs associated with the labor grounds.
     */
    function removeAnimalsFromLaborGround(
        uint256[] calldata _tokenId,
        uint256[] calldata _animalsId
    ) external {
        checkLength(_tokenId, _animalsId);
        uint256 i;
        for (; i < _tokenId.length; ) {
            uint256 animalsId = _animalsId[i];
            LaborGround storage labor = laborGround[_tokenId[i]];
            Lib.removeAnimalsFromLaborGround(labor, animalsId);

            animals.safeTransferFrom(
                address(this),
                msg.sender,
                animalsId,
                1,
                ""
            );
            labor.animalId = 0;
            emit RemoveAnimalsFromLaborGround(
                msg.sender,
                _tokenId[i],
                animalsId
            );
            unchecked {
                ++i;
            }
        }
    }

    /**
     * This function allows the token owner to claim a collectable. If the token owner is not the same as the
     * stored owner or the lock time has not yet passed, the function will revert. If there are possible claims,
     * a consumables token will be minted for the token owner. The lock time for the labor ground is then updated.
     * @param _tokenId The id of the labor ground token being claimed.
     */

    function claimCollectable(uint256 _tokenId) internal {
        LaborGround storage labor = laborGround[_tokenId];
        if (msg.sender != labor.owner) revert NotYourToken();
        if (block.timestamp < labor.lockTime + 3 days) revert CannotClaimNow();
        uint256 consumablesTokenId = checkPossibleClaims(_tokenId, labor);
        if (consumablesTokenId != 0)
            consumables.mint(msg.sender, consumablesTokenId, 1);

        labor.lockTime = uint32(block.timestamp);
        emit ClaimCollectable(msg.sender, _tokenId);
    }

    /** 
    *@dev This function allows a user to claim multiple collectables at once by providing an array of token IDs.
     @param _tokenId An array of token IDs that the user wants to claim.
*/
    function claimCollectables(uint256[] calldata _tokenId) external {
        uint256 i;
        for (; i < _tokenId.length; ) {
            claimCollectable(_tokenId[i]);
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @dev This function decides whether the supply will break or fail when the random number generated is smaller than `_min`.
     * @param _tokenId ID of the token that the supply is associated with.
     * @param _supplyId ID of the supply.
     * @param _amount Total amount of possible outcomes.
     * @param _min The minimum value of the random number that will cause the supply to break or fail.
     * @param _requestId Request ID for accessing the random number.
     */
    function breakOrFailed(
        uint256 _tokenId,
        uint256 _supplyId,
        uint256 _amount,
        uint256 _min,
        uint256 _requestId
    ) internal {
        uint256 random = randomizer.revealRandomNumber(_requestId) % _amount;
        if (random < _min) {
            supplies.safeTransferFrom(
                address(this),
                msg.sender,
                _supplyId,
                1,
                ""
            );
            laborGround[_tokenId].supplyId = 0;
        }
    }

    /**
     * @dev This function allows a user to leave the LaborGround and receive their animal, supply, and collectable.
     * @param _tokenId An array of token IDs that the user wants to leave.
     */

    function leaveLaborGround(uint256[] calldata _tokenId) external {
        uint256 i;

        for (; i < _tokenId.length; ) {
            uint256 tokenId = _tokenId[i];
            claimCollectable(tokenId);
            LaborGround memory labor = laborGround[tokenId];
            delete laborGround[tokenId];
            ownerToTokens[msg.sender].remove(tokenId);
            if (labor.animalId != 0)
                animals.safeTransferFrom(
                    address(this),
                    msg.sender,
                    labor.animalId - 1,
                    1,
                    ""
                );

            if (labor.supplyId != 0)
                supplies.safeTransferFrom(
                    address(this),
                    msg.sender,
                    labor.supplyId,
                    1,
                    ""
                );
            neandersmol.transferFrom(address(this), msg.sender, tokenId);
            emit LeaveLaborGround(msg.sender, tokenId);
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @dev Function to check the possible claims of an animal job
     * @param _tokenId ID of the token
     * @param labor LaborGround struct with the information of the job
     * @return consumablesTokenId The token ID of the consumables to be claimed
     */

    function checkPossibleClaims(
        uint256 _tokenId,
        LaborGround memory labor
    ) internal returns (uint256) {
        uint256 rnd = randomizer.revealRandomNumber(labor.requestId) % 101;
        uint256 animalId = labor.animalId;
        uint256 consumablesTokenId;
        (uint256 tokenOne, uint256 tokenTwo) = getConsumablesTokenId(labor.job);
        uint256 max;
        uint256 min;
        if (animalId == 0) {
            if (rnd < 61) {
                consumablesTokenId = tokenOne;
            } else if (rnd > 60 && rnd < 81) {
                consumablesTokenId = tokenTwo;
            } else {
                max = 3;
                min = 2;
            }
        }
        if (animalId == 1) {
            if (rnd < 66) {
                consumablesTokenId = tokenOne;
            } else if (rnd > 66 && rnd < 86) {
                consumablesTokenId = tokenTwo;
            } else {
                max = 16;
                min = 5;
            }
        }
        if (animalId == 2) {
            if (rnd < 66) {
                consumablesTokenId = tokenOne;
            } else if (rnd > 65 && rnd < 96) {
                consumablesTokenId = tokenTwo;
            } else {
                max = 11;
                min = 6;
            }
        }
        if (animalId == 3) {
            if (rnd < 71) {
                consumablesTokenId = tokenOne;
            } else if (rnd > 70 && rnd < 96) {
                consumablesTokenId = tokenTwo;
            } else {
                max = 6;
                min = 1;
            }
        }

        if (max != 0 && min != 0)
            breakOrFailed(_tokenId, labor.supplyId, max, min, labor.requestId);

        if (animalId == 4) consumablesTokenId = rnd < 71 ? tokenOne : tokenTwo;

        if (animalId == 5) consumablesTokenId = rnd < 66 ? tokenOne : tokenTwo;

        if (animalId == 6) consumablesTokenId = rnd < 61 ? tokenOne : tokenTwo;

        return consumablesTokenId;
    }

    /**
     * @dev Function to get the consumables token IDs based on the job type
     * @param _job Job type
     * @return tokenIdOne and tokenIdTwo The token IDs of the consumables for the job
     */

    function getConsumablesTokenId(
        Jobs _job
    ) internal pure returns (uint256 tokenIdOne, uint256 tokenIdTwo) {
        if (_job == Jobs.Digging) (tokenIdOne, tokenIdTwo) = (1, 4);
        if (_job == Jobs.Foraging) (tokenIdOne, tokenIdTwo) = (2, 5);
        if (_job == Jobs.Mining) (tokenIdOne, tokenIdTwo) = (3, 6);
    }

    /**
     *Check the length of two input arrays, _tokenId and _animalsId, for equality.
     *If the lengths are not equal, the function will revert with the error "LengthsNotEqual".
     *@dev Internal function called by other functions within the contract.
     *@param _tokenId Array of token IDs
     */

    function checkLength(
        uint256[] calldata _tokenId,
        uint256[] calldata _animalsId
    ) internal pure {
        if (_tokenId.length != _animalsId.length) revert LengthsNotEqual();
    }

    /**
     * Handle incoming ERC1155 token transfers.
     * @dev This function is the onERC1155Received fallback function for the contract, which is triggered when the contract receives an ERC1155 token transfer.
     * @return The selector for this function, "0x20f90a7e".
     */

    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes calldata
    ) external pure returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    /**
     * Retrieve information about a Labor Ground token.
     * @dev This function returns a LaborGround struct containing information about a Labor Ground token, specified by its ID, _tokenId.
     * @param _tokenId ID of the Labor Ground token to retrieve information for
     * @return The LaborGround struct containing information about the specified Labor Ground token.
     */

    function getLaborGroundInfo(
        uint256 _tokenId
    ) external view returns (LaborGround memory) {
        return laborGround[_tokenId];
    }

    function getStakedTokens(
        address _owner
    ) external view returns (uint256[] memory res) {
        return ownerToTokens[_owner].values();
    }

    event ClaimCollectable(address indexed owner, uint256 indexed tokenId);

    event LeaveLaborGround(address indexed owner, uint256 indexed tokenId);

    event RemoveAnimalsFromLaborGround(
        address indexed owner,
        uint256 indexed tokenId,
        uint256 indexed animalsId
    );

    event BringInAnimalsToLaborGround(
        address indexed owner,
        uint256 indexed tokenId,
        uint256 indexed animalsId
    );

    event EnterLaborGround(
        address indexed owner,
        uint256 indexed tokenId,
        uint256 indexed supplyId,
        Jobs job
    );
}
