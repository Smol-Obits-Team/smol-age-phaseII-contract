//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.13;

import "./ContractControl.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/MathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/MerkleProofUpgradeable.sol";

error TokenIsStaked();
error InvalidSkillLevel();

contract NeanderSmol is ContractControl, ERC721EnumerableUpgradeable {
    using StringsUpgradeable for uint256;
    using CountersUpgradeable for CountersUpgradeable.Counter;

    uint256 constant TOTAL_SUPPLY = 5678;

    CountersUpgradeable.Counter public _tokenIdTracker;

    string public baseURI;

    uint256 public decimals;
    uint256 public commonSenseMaxLevel;

    bool public publicActive;
    uint256 public publicPrice;

    bool private revealed;

    IERC20 private magic;

    address public devGround;

    struct PrimarySkill {
        uint256 mystics;
        uint256 farmers;
        uint256 fighters;
    }

    struct Addons {
        uint256 hand;
        uint256 hat;
        uint256 mask;
        uint256 special;
    }

    mapping(uint256 => PrimarySkill) private tokenToSkill;
    mapping(uint256 => bool) public staked;
    mapping(uint256 => uint256) public commonSense;

    mapping(uint256 => Addons) public addonsEnabled;


    mapping(address => bool) private minted;
    mapping(address => uint256) private publicMinted;

    event SmolNeanderMint(address to, uint256 tokenId);

    event uriUpdate(string newURI);

    event commonSenseUpdated(uint256 tokenId, uint256 commonSense);

    function initialize() public initializer {
        __ERC721_init("Neander Smol", "NeanderSmol");
        ContractControl.initializeAccess();
        decimals = 9;
        commonSenseMaxLevel = 100 * (10 ** decimals);
        publicActive = false;
        publicPrice = 0.02 ether;
        revealed = true;
    }

    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        override(ERC721EnumerableUpgradeable, AccessControlUpgradeable)
        returns (bool)
    {
        return
            ERC721EnumerableUpgradeable.supportsInterface(interfaceId) ||
            AccessControlUpgradeable.supportsInterface(interfaceId);
    }

    function publicMint(uint256 amount) external payable {
        require(msg.value >= publicPrice * amount, "Incorrect Price");
        require(publicActive, "Public not active");
        require(_tokenIdTracker.current() < TOTAL_SUPPLY, "5678 Max Supply");
        require(publicMinted[msg.sender] + amount <= 30, "Mints exceeded");
        publicMinted[msg.sender] += amount;

        for (uint256 i = 0; i < amount; i++) {
            _mint(msg.sender);
        }
    }

    function _mint(address _to) internal {
        uint256 _tokenId = _tokenIdTracker.current();
        _tokenIdTracker.increment();
        require(_tokenId <= TOTAL_SUPPLY, "Exceeded supply");

        emit SmolNeanderMint(_to, _tokenId);
        _safeMint(_to, _tokenId);
    }

    function updateCommonSense(
        uint256 _tokenId,
        uint256 amount
    ) external onlyOwner {
        if (commonSense[_tokenId] + amount >= commonSenseMaxLevel) {
            commonSense[_tokenId] = commonSenseMaxLevel;
        } else {
            commonSense[_tokenId] += amount;
        }

        emit commonSenseUpdated(_tokenId, commonSense[_tokenId]);
    }

    function developMystics(
        uint256 _tokenId,
        uint256 _amount
    ) external onlyDevGround {
        tokenToSkill[_tokenId].mystics += _amount;
        emit MysticsSkillUpdated(_tokenId, _amount);
    }

    function developFarmers(
        uint256 _tokenId,
        uint256 _amount
    ) external onlyDevGround {
        tokenToSkill[_tokenId].farmers += _amount;
        emit FarmerSkillUpdated(_tokenId, _amount);
    }

    function developFighter(
        uint256 _tokenId,
        uint256 _amount
    ) external onlyDevGround {
        tokenToSkill[_tokenId].fighters += _amount;
        emit FightersSkillUpdated(_tokenId, _amount);
    }

    function stakingHandler(
        uint256 _tokenId,
        bool _state
    ) external onlyStakingContract {
        staked[_tokenId] = _state;
        emit StakeState(_tokenId, _state);
    }

    function _beforeTokenTransfer(
        address _from,
        address _to,
        uint256 _firstTokenId,
        uint256 _batchSize
    ) internal virtual override {
        if (staked[_firstTokenId]) revert TokenIsStaked();
        super._beforeTokenTransfer(_from, _to, _firstTokenId, _batchSize);
    }

    function getCommonSense(uint256 _tokenId) external view returns (uint256) {
        return commonSense[_tokenId] / (10 ** decimals);
    }

    function getPrimarySkill(
        uint256 _tokenId
    ) external view returns (PrimarySkill memory) {
        return tokenToSkill[_tokenId];
    }

    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }

    function setBaseURI(string memory newBaseURI) external onlyAdmin {
        baseURI = newBaseURI;
        emit uriUpdate(newBaseURI);
    }

    function flipPublicState() external onlyAdmin {
        publicActive = !publicActive;
    }

    function setPublicPrice(uint256 amount) external onlyAdmin {
        publicPrice = amount;
    }

    function tokenURI(
        uint256 /*tokenId*/
    ) public view virtual override returns (string memory) {
        return "ipfs://QmUZvuiDzeKvKCeizPVKoWesrpGTfy4Ysf3rzgSAps7N9K";
    }

    function withdrawAll() external onlyOwner {
        require(payable(msg.sender).send(address(this).balance));
        require(magic.transfer(msg.sender, magic.balanceOf(address(this))));
    }

    function setEnabledAddons(uint256 tokenId, uint32[] addons) external {
        // require that the setter is the owner of the tokenId
        require(ownerOf(tokenId) == msg.sender, "Only the owner can set addons");

        // Addons is an array of 4 uint32 (hand, hat, mask, special)
        // Addons from 0 to 99 are for mystic
        // Addons from 100 to 199 are for farmer
        // Addons from 200 to 300 are for fighter

        // Get the level of the skills
        uint256 mystics = tokenToSkill[tokenId].mystics;
        uint256 farmers = tokenToSkill[tokenId].farmers;
        uint256 fighters = tokenToSkill[tokenId].fighters;

        // Check if they have level 100 of the skill that is required for the addon
        for (uint256 i = 0; i < addonIds.length; i++) {
            uint256 addonId = addonIds[i];
            if (addonId < 100 && mystics < 100) {
                revert InvalidSkillLevel();
            } else if (addonId >= 100 && addonId < 200 && farmers < 100) {
                revert InvalidSkillLevel();
            } else if (addonId >= 200 && addonId < 300 && fighters < 100) {
                revert InvalidSkillLevel();
            }
        }

        addonsEnabled[tokenId].hand = addons[0];
        addonsEnabled[tokenId].hat = addons[1];
        addonsEnabled[tokenId].mask = addons[2];
        addonsEnabled[tokenId].special = addons[3];
        
        emit SetEnabledAddon(tokenId, addonIds);
    }

    event StakeState(uint256 indexed tokenId, bool state);
    event MysticsSkillUpdated(uint256 indexed tokenId, uint256 indexed amount);
    event FarmerSkillUpdated(uint256 indexed tokenId, uint256 indexed amount);
    event FightersSkillUpdated(uint256 indexed tokenId, uint256 indexed amount);
    event SetEnabledAddons(uint256 indexed tokenId, uint32[] indexed addonIds);
}

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);

    function transfer(
        address recipient,
        uint256 amount
    ) external returns (bool);

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);
}
