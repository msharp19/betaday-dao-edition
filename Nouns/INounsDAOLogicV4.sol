// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { NounsDAOTypes } from "https://raw.githubusercontent.com/nounsDAO/nouns-monorepo/refs/heads/master/packages/nouns-contracts/contracts/governance/NounsDAOInterfaces.sol";

/**
 * @title INounsDAOLogicV4 Interface
 * @notice Derived from NounsDAO with GPL-3.0 License
 * @dev This interface is adapted from NounsDAO's governance contracts
 *      Original source: https://github.com/nounsDAO/nouns-monorepo/blob/master/packages/nouns-contracts/contracts/governance/NounsDAOLogicV4.sol
 *      NounsDAO License: License-Identifier: GPL-3.0
 */
interface INounsDAOLogicV4
{
    /**
     * @notice Gets the state of a proposal
     * @param proposalId The id of the proposal
     * @return Proposal state
     */
    function state(uint256 proposalId) external view returns (NounsDAOTypes.ProposalState);

     /**
     * @notice Returns the proposal details given a proposal id.
     *     The `quorumVotes` member holds the *current* quorum, given the current votes.
     * @param proposalId the proposal id to get the data for
     * @return A `ProposalCondensed` struct with the proposal data, not backwards compatible as it contains additional values
     * like `objectionPeriodEndBlock` and `signers`
     */
    function proposalsV3(uint256 proposalId) external view returns (NounsDAOTypes.ProposalCondensedV3 memory);
}
