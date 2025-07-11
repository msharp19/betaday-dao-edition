// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IDaoAdapter.sol";

contract ENSDaoAdapter is IDaoAdapter
{

    function supportsInterface(bytes4 interfaceId) public view virtual returns (bool) 
    {
        /// @inheritdoc IDaoAdapter
        return interfaceId == type(IDaoAdapter).interfaceId;
    }

    function getDaoName() external view returns (string memory)
    {
        /// @inheritdoc IDaoAdapter
    }

    function getDaoAddress() external view returns (address)
    {
        /// @inheritdoc IDaoAdapter
    }

    function mapProposal(bytes[] memory nativeProposalId, uint256 mappedProposalId) external returns (bool)
    {
        /// @inheritdoc IDaoAdapter
    }

    function getOutcomeOfProposal(uint256 proposalId) external view returns (DaoOutcome)
    {
        /// @inheritdoc IDaoAdapter
    }

    function getProposalEndDate(uint256 proposalId) external view returns (uint256)
    {
        /// @inheritdoc IDaoAdapter
    }

    function proposalExists(uint256 proposalId) external view returns (bool)
    {
        /// @inheritdoc IDaoAdapter
    }

    function proposalExists(bytes[] memory nativeProposalId) external view returns (bool)
    {
        /// @inheritdoc IDaoAdapter
    }
}