// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

error NotAnAdmin();
error NotTheOwner();
error NotAuthorized();
error NotTheStakingContract();

abstract contract ContractControl is AccessControlUpgradeable {
    bytes32 public constant SMOLNEANDER_OWNER_ROLE =
        keccak256("SMOLNEANDER_OWNER_ROLE");
    bytes32 public constant SMOLNEANDER_CONTRACT_ROLE =
        keccak256("SMOLNEANDER_CONTRACT_ROLE");
    bytes32 public constant SMOLNEANDER_MINTER_ROLE =
        keccak256("SMOLNEANDER_MINTER_ROLE");
    bytes32 public constant SMOLNEANDER_ADMIN_ROLE =
        keccak256("SMOLNEANDER_ADMIN_ROLE");

    modifier onlyDevGround(address _devGround) {
        if (msg.sender != _devGround) revert NotAuthorized();
        _;
    }

    modifier onlyOwner() {
        if (!isOwner(_msgSender())) revert NotTheOwner();
        _;
    }

    modifier onlyStakingContract() {
        if (!isStakingContract(_msgSender())) revert NotTheStakingContract();
        _;
    }

    modifier onlyAdmin() {
        if (!isAdmin(_msgSender())) revert NotAnAdmin();
        _;
    }

    function initializeAccess() public onlyInitializing {
        __AccessControl_init();
        _setRoleAdmin(SMOLNEANDER_OWNER_ROLE, SMOLNEANDER_OWNER_ROLE);
        _setRoleAdmin(SMOLNEANDER_CONTRACT_ROLE, SMOLNEANDER_OWNER_ROLE);
        _setRoleAdmin(SMOLNEANDER_MINTER_ROLE, SMOLNEANDER_OWNER_ROLE);
        _setRoleAdmin(SMOLNEANDER_ADMIN_ROLE, SMOLNEANDER_OWNER_ROLE);

        _setupRole(SMOLNEANDER_OWNER_ROLE, _msgSender());
        _setupRole(SMOLNEANDER_CONTRACT_ROLE, _msgSender());
        _setupRole(SMOLNEANDER_MINTER_ROLE, _msgSender());
        _setupRole(SMOLNEANDER_ADMIN_ROLE, _msgSender());
    }

    function grantStaking(address _contract) external {
        grantRole(SMOLNEANDER_CONTRACT_ROLE, _contract);
    }

    function isStakingContract(address _contract) public view returns (bool) {
        return hasRole(SMOLNEANDER_CONTRACT_ROLE, _contract);
    }

    function grantOwner(address _owner) external {
        grantRole(SMOLNEANDER_OWNER_ROLE, _owner);
    }

    function isOwner(address _owner) public view returns (bool) {
        return hasRole(SMOLNEANDER_OWNER_ROLE, _owner);
    }

    function grantMinter(address _minter) external {
        grantRole(SMOLNEANDER_MINTER_ROLE, _minter);
    }

    function isMinter(address _minter) public view returns (bool) {
        return hasRole(SMOLNEANDER_MINTER_ROLE, _minter);
    }

    function grantAdmin(address _admin) external {
        grantRole(SMOLNEANDER_ADMIN_ROLE, _admin);
    }

    function isAdmin(address _admin) public view returns (bool) {
        return hasRole(SMOLNEANDER_ADMIN_ROLE, _admin);
    }
}
