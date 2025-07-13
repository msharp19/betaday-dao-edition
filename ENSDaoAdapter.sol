// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IDaoAdapter.sol";
import "./IENSDaoAdapter.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

contract ENSDaoAdapter is IDaoAdapter, IENSDaoAdapter, Initializable, OwnableUpgradeable, ReentrancyGuardUpgradeable, AccessControlUpgradeable, UUPSUpgradeable 
{   
    bytes32 private constant AppStorageSlot = 0x098b9a5a10e60aff8f55e9477cc53791735a7ce2b851408e1eb5a144966fb300;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        string memory daoName,
        address daoAddress
    ) public initializer {

        __ReentrancyGuard_init();
        __Ownable_init(_msgSender());
        __AccessControl_init();
        __UUPSUpgradeable_init();

        AppStorage storage $ = _appStorage();
        $.daoName = daoName;
        $.daoAddress = daoAddress;

        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(IDaoAdapter, IENSDaoAdapter, AccessControlUpgradeable) returns (bool) 
    {
        return
            interfaceId == type(IDaoAdapter).interfaceId ||
            interfaceId == type(IENSDaoAdapter).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    function getDaoName() external view returns (string memory)
    {
        AppStorage storage $ = _appStorage();
        return $.daoName;
    }

    function getDaoAddress() external view returns (address)
    {
        AppStorage storage $ = _appStorage();
        return $.daoAddress;
    }

    function mapProposal(bytes[] memory nativeProposalId, uint256 mappedProposalId) external returns (bool)
    {
        
    }

    function getOutcomeOfProposal(uint256 proposalId) external view returns (DaoOutcome)
    {
        
    }

    function getProposalEndDate(uint256 proposalId) external view returns (uint256)
    {
        
    }

    function proposalExists(uint256 proposalId) external view returns (bool)
    {
        
    }

    function proposalExists(bytes[] memory nativeProposalId) external view returns (bool)
    {

    }

    /**
     * @dev Diamond storage pattern accessor.
     * @return $ Reference to the AppStorage struct.
     */
    function _appStorage() private pure returns (AppStorage storage $) 
    {
        assembly { $.slot := AppStorageSlot }
    }
 
    /**
     * @dev UUPS upgrade authorization hook.
     * @notice Only owner can authorize upgrades.
     */
    function _authorizeUpgrade(address) internal override onlyOwner {}
}
