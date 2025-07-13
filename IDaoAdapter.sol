// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title IDaoAdapter Interface
 * @notice Standard interface for DAO adapter contracts that provide a unified interface
 *         to interact with different DAO governance systems
 * @dev Adapters implement this interface to allow the DaoBets system to work with multiple
 *      DAO implementations while maintaining a consistent interface
 */
interface IDaoAdapter
{
    /**
     * @dev Enum representing possible outcomes of a DAO proposal
     * @param Unresolved Proposal hasn't been resolved yet
     * @param Cancelled Proposal was cancelled before execution
     * @param Succeeded Proposal succeeded and will be/was executed
     * @param Defeated Proposal was defeated in voting
     */
    enum DaoOutcome
    {
       Unresolved,
       Cancelled,
       Succeeded,
       Defeated
    }

    /**
     * @dev ERC-165 interface support check
     * @param interfaceId The interface identifier, as specified in ERC-165
     * @return bool True if the contract implements `interfaceId` and
     * `interfaceId` is not 0xffffffff, false otherwise
     * @notice This function call must use less than 30,000 gas
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);

    /**
     * @dev Returns the name of the DAO this adapter interfaces with
     * @return string The human-readable name of the DAO (e.g., "Compound", "Aave")
     */
    function getDaoName() external view returns (string memory);

    /**
     * @dev Returns the address of the DAO this adapter interfaces with
     * @return address The contract address of the DAO
     */
    function getDaoAddress() external view returns (address);

    /**
     * @dev Maps a native proposal ID to an internal integer ID
     * @param nativeProposalId The proposal ID in the native DAO format (may be bytes array for some DAOs)
     * @param mappedProposalId The internal integer ID to map to
     * @return bool True if the proposal exists on the DAO side and was mapped successfully
     * @notice This function should verify the proposal exists on the DAO before mapping
     */
    function mapProposal(bytes[] memory nativeProposalId, uint256 mappedProposalId) external returns (bool);

    /**
     * @dev Gets the current outcome of a proposal
     * @param proposalId The internal mapped proposal ID
     * @return DaoOutcome The current state of the proposal (Unresolved, Cancelled, Succeeded, Defeated)
     * @notice Should revert if proposal doesn't exist
     */
    function getOutcomeOfProposal(uint256 proposalId) external view returns (DaoOutcome);

    /**
     * @dev Gets the end date/timestamp of a proposal's voting period
     * @param proposalId The internal mapped proposal ID
     * @return uint256 The UNIX timestamp when voting ends
     * @notice Should revert if proposal doesn't exist
     */
    function getProposalEndDate(uint256 proposalId) external view returns (uint256);

    /**
     * @dev Checks if a proposal exists by its internal ID
     * @param proposalId The internal mapped proposal ID
     * @return bool True if the proposal exists, false otherwise
     */
    function proposalExists(uint256 proposalId) external view returns (bool);

    /**
     * @dev Checks if a proposal exists by its native DAO ID
     * @param nativeProposalId The proposal ID in the native DAO format
     * @return bool True if the proposal exists, false otherwise
     */
    function proposalExists(bytes[] memory nativeProposalId) external view returns (bool);
}
