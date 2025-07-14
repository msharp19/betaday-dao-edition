// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IDaoAdapter.sol";
import "./IENSDaoAdapter.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts/governance/IGovernor.sol";

contract ENSDaoAdapter is IDaoAdapter, IENSDaoAdapter, Initializable, OwnableUpgradeable, ReentrancyGuardUpgradeable, AccessControlUpgradeable, UUPSUpgradeable 
{   
    bytes32 private constant AppStorageSlot = 0x6472301cf87d8ab18c1c1936ba5f42c31924c9ff43985065fd1cca087b1fc578;

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

    /**
     * @dev See {IDaoAdapter-IENSDaoAdapter-AccessControlUpgradeable-supportsInterface}.
     * @notice Checks interface support for both IDaoAdapter and IENSDaoAdapter.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(IDaoAdapter, IENSDaoAdapter, AccessControlUpgradeable) returns (bool) 
    {
        return interfaceId == type(IDaoAdapter).interfaceId ||
            interfaceId == type(IENSDaoAdapter).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /**
     * @dev Returns the name of the DAO this adapter interfaces with.
     * @return string The human-readable name of the DAO.
     */
    function getDaoName() external view returns (string memory)
    {
        AppStorage storage $ = _appStorage();
        return $.daoName;
    }

    /**
     * @dev Returns the address of the DAO this adapter interfaces with.
     * @return address The contract address of the DAO.
     */
    function getDaoAddress() external view returns (address)
    {
        AppStorage storage $ = _appStorage();
        return $.daoAddress;
    }

    /**
     * @dev Maps a native proposal ID to an internal integer ID.
     * @param nativeProposalId The proposal ID in the native DAO format (bytes).
     * @param mappedProposalId The internal integer ID to map to.
     * @return bool True if mapping was successful.
     */
    function mapProposal(bytes memory nativeProposalId, uint256 mappedProposalId) external returns (bool)
    {
        AppStorage storage $ = _appStorage();

        uint256 daoProposalId = _bytesToUint256(nativeProposalId);

        $.nativeProposalMappings[mappedProposalId] = ProposalMapping(true, daoProposalId);

        return true;
    }

    /**
     * @dev Gets the current outcome of a proposal.
     * @param proposalId The internal mapped proposal ID.
     * @return DaoOutcome The current state of the proposal.
     */
    function getOutcomeOfProposal(uint256 proposalId) external view returns (DaoOutcome)
    {
        AppStorage storage $ = _appStorage();

        ProposalMapping memory mappedProposal = $.nativeProposalMappings[proposalId];

        IGovernor.ProposalState state = IGovernor($.daoAddress).state(mappedProposal.externalProposalId);

        if(state == IGovernor.ProposalState.Active || state == IGovernor.ProposalState.Pending) 
        {
            return DaoOutcome.Unresolved;
        }

        if(state == IGovernor.ProposalState.Executed || 
           state == IGovernor.ProposalState.Queued || 
           state == IGovernor.ProposalState.Succeeded) 
        {
           return DaoOutcome.Succeeded;
        }

        if(state == IGovernor.ProposalState.Defeated) 
        {
           return DaoOutcome.Defeated;
        }

        if(state == IGovernor.ProposalState.Canceled) 
        {
           return DaoOutcome.Cancelled;
        }

        revert("Proposal outcome could not be mapped.");
    }

    /**
     * @dev Gets the end date/timestamp of a proposal's voting period.
     * @param proposalId The internal mapped proposal ID.
     * @return deadline The UNIX timestamp when voting ends.
     */
    function getProposalEndDate(uint256 proposalId) external view returns (uint256 deadline)
    {
        AppStorage storage $ = _appStorage();

        ProposalMapping memory mappedProposal = $.nativeProposalMappings[proposalId];

        require(mappedProposal.exists, "There is no mapped proposal for the ID specified");

        deadline = IGovernor($.daoAddress).proposalDeadline(mappedProposal.externalProposalId);
    }

    /**
     * @dev Checks if a proposal has been mapped already by its internal ID.
     * @param proposalId The external mapped proposal ID.
     * @return bool True if the proposal exists, false otherwise.
     */
    function proposalIsRegistered(uint256 proposalId) external view returns (bool)
    {
        AppStorage storage $ = _appStorage();

        ProposalMapping memory mappedProposal = $.nativeProposalMappings[proposalId];

        return mappedProposal.exists;
    }

    /**
     * @dev Checks if a proposal exists by its native DAO ID externally
     * @param nativeProposalId The proposal ID in the native DAO format
     * @return bool True if the proposal exists and is active/pending, false otherwise
     */
    function externalActiveProposalExists(bytes memory nativeProposalId) external view returns (bool)
    {
        AppStorage storage $ = _appStorage();

        uint256 daoProposalId = _bytesToUint256(nativeProposalId);

        // Reverts if there is no proposal registered ENS side for the provided ID
        IGovernor.ProposalState state = IGovernor($.daoAddress).state(daoProposalId);

        if(state == IGovernor.ProposalState.Active || state == IGovernor.ProposalState.Pending)
        {
            return true;
        }

        return false;
    }

    /**
     * @dev Internal function to convert bytes to uint256
     * @param data Bytes input to convert
     * @return num The converted uint256 value
     */
    function _bytesToUint256(bytes memory data) internal pure returns (uint256) 
    {
        require(data.length == 32, "Invalid bytes length for uint256 conversion");
        uint256 num;
        assembly {
            num := mload(add(data, 0x20))
        }
        return num;
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
