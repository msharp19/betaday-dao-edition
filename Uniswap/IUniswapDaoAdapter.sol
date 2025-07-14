// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title IUniswapDaoAdapter Interface
 * @notice Standard interface for Uniswap DAO adapter contracts that provide a unified interface
 *         to interact with different Uniswap DAO governance systems
 * @dev Uniswap Adapters implement this interface to allow the DaoBets system to work with multiple
 *      DAO implementations while maintaining a consistent interface
 */
interface IUniswapDaoAdapter
{
    /**
     * @dev Struct representing a an externally mapped proposal
     * @param exists If the mapping exists.
     * @param externalProposalId The externally mapped proposal ID.
     */
    struct ProposalMapping
    {
        bool exists;
        uint externalProposalId;
    }

    /**
     * @dev Main storage struct for the contract.
     * @param nextProposalId ID for the next proposal to be created.
     * @param houseRakePercent House commission percentage in basis points (1% = 100).
     * @param houseRakeReceiver Address that receives house commissions.
     * @param resolverPercent Resolver commission percentage in basis points (1% = 100).
     * @param uniswapRouterAddress Address of Uniswap router for token swaps.
     * @param proposals Mapping of proposal IDs to Proposal structs.
     * @param supportedDaos Mapping of DAO addresses to SupportedDao structs.
     * @param supportedPaymentAssets Mapping of token addresses to SupportedPaymentAsset structs.
     * @param __gap Reserved storage space for future upgrades.
     */
    struct AppStorage 
    {
        string daoName;
        address daoAddress;
        mapping(uint256 => ProposalMapping) nativeProposalMappings;

        uint256[50] __gap;
    }

    /**
     * @dev IUniswapDaoAdapter interface support check
     * @param interfaceId The interface identifier, as specified in IUniswapDaoAdapter
     * @return bool True if the contract implements `interfaceId` and
     * `interfaceId` is not 0xffffffff, false otherwise
     * @notice This function call must use less than 30,000 gas
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}
