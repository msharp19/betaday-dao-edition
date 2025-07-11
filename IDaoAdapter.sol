// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IDaoAdapter
{
    enum DaoOutcome
    {
       Unresolved,
       Cancelled,
       Succeeded,
       Defeated
    }

    /**
     * @dev Returns true if this contract implements the interface defined by
     * {interfaceId}.
     * This function call must use less than 30 000 gas.
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);

    /**
     * @dev Gets the Daos name (what this is the adapter for).
     */
    function getDaoName() external view returns (string memory);

    /**
     * @dev Gets the Daos address.
     */
    function getDaoAddress() external view returns (address);

    /**
     * @dev Maps a native proposal to an integer ID {mappedProposalId}.
     * The {nativeProposalId} is the proposal ID on the Dao itself.
     * This returns true if the proposal exists on the Dao side and has been mapped successfully. 
     */
    function mapProposal(bytes[] memory nativeProposalId, uint256 mappedProposalId) external returns (bool);

    /**
     * @dev Gets the outcome of a proposal by its ID {proposalId}.
     */
    function getOutcomeOfProposal(uint256 proposalId) external view returns (DaoOutcome);

    /**
     * @dev Gets the proposal enddate by its ID {proposalId}.
     * If the proposal exists, an end date will be returned. 
     * The implementation should throw an error if doesn't exist.
     */
    function getProposalEndDate(uint256 proposalId) external view returns (uint256);

    /**
     * @dev Checks if a proposal exists by its mapped ID {proposalId}.
     * This returns true if it does and false if it doesn't.
     */
    function proposalExists(uint256 proposalId) external view returns (bool);

    /**
     * @dev Checks if a proposal exists by its native ID {proposalId}.
     * This returns true if it does and false if it doesn't.
     */
    function proposalExists(bytes[] memory nativeProposalId) external view returns (bool);
}