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
    bytes32 public constant SMOLNEANDER_DEV_GROUND_ROLE =
        keccak256("SMOLNEANDER_DEV_GROUND_ROLE");
    bytes32 public constant SMOLNEANDER_CONTRACT_ROLE =
        keccak256("SMOLNEANDER_CONTRACT_ROLE");
    bytes32 public constant SMOLNEANDER_ADMIN_ROLE =
        keccak256("SMOLNEANDER_ADMIN_ROLE");

    modifier onlyDevGround() {
        if (!isDevGround(msg.sender)) revert NotAuthorized();
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
        _setRoleAdmin(SMOLNEANDER_DEV_GROUND_ROLE, SMOLNEANDER_OWNER_ROLE);

        _setRoleAdmin(SMOLNEANDER_ADMIN_ROLE, SMOLNEANDER_OWNER_ROLE);

        _setupRole(SMOLNEANDER_OWNER_ROLE, _msgSender());
        _setupRole(SMOLNEANDER_CONTRACT_ROLE, _msgSender());
        _setupRole(SMOLNEANDER_ADMIN_ROLE, _msgSender());
    }

    function grantStakingContracts(address[] calldata _contracts) external {
        for (uint256 i; i < _contracts.length; ++i) grantStaking(_contracts[i]);
    }

    function grantStaking(address _contract) public {
        grantRole(SMOLNEANDER_CONTRACT_ROLE, _contract);
    }

    function grantDevGround(address _devGround) external {
        grantRole(SMOLNEANDER_DEV_GROUND_ROLE, _devGround);
    }

    function isDevGround(address _devGround) public view returns (bool) {
        return hasRole(SMOLNEANDER_DEV_GROUND_ROLE, _devGround);
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

    function grantAdmin(address _admin) external {
        grantRole(SMOLNEANDER_ADMIN_ROLE, _admin);
    }

    function isAdmin(address _admin) public view returns (bool) {
        return hasRole(SMOLNEANDER_ADMIN_ROLE, _admin);
    }
}
