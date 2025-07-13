// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title IDaoBets Interface
 * @notice Interface for a DAO betting system where users can bet on the outcomes of DAO proposals.
 */
interface IDaoBets 
{   
    /**
     * @dev Enum representing possible outcomes of a DAO proposal.
     */
    enum DaoOutcome
    {
       Unresolved,   // Proposal hasn't been resolved yet
       Cancelled,    // Proposal was cancelled
       Succeeded,    // Proposal succeeded
       Defeated      // Proposal was defeated
    }

    /**
     * @dev Struct representing a betting proposal.
     * @param id Unique identifier for the proposal.
     * @param createdAt Timestamp when proposal was created.
     * @param succeedTotalBets Total bets placed on success outcome.
     * @param defeatTotalBets Total bets placed on defeat outcome.
     * @param resolverPayout Amount to be paid to the resolver.
     * @param housePayout Amount to be paid to the house.
     * @param resolvedAt Timestamp when proposal was resolved.
     * @param daoAdapterAddress Address of the DAO adapter.
     * @param payoutAddress Address for payouts.
     * @param daoOutcome Current outcome of the proposal.
     * @param userBets Mapping of user addresses to their bets.
     */
    struct Proposal 
    {
        uint256 id;
        uint256 createdAt;
        uint256 succeedTotalBets;
        uint256 defeatTotalBets;
        uint256 resolverPayout;
        uint256 housePayout;
        uint256 resolvedAt;   
        address daoAdapterAddress;
        address payoutAddress;
        DaoOutcome daoOutcome;
        mapping(address => Bet) userBets;
    }

    /**
     * @dev Struct representing a user's bet on a proposal.
     * @param succeedBets Amount bet on success outcome.
     * @param defeatBets Amount bet on defeat outcome.
     * @param beenPaidAt Timestamp when winnings were paid out (0 if not paid).
     */
    struct Bet 
    {
        uint256 succeedBets;
        uint256 defeatBets;
        uint256 beenPaidAt;
    }

    /**
     * @dev Struct representing a supported DAO.
     * @param isSupported Whether this DAO is supported.
     * @param daoAdapter Address of the DAO adapter contract.
     * @param daoTokenAddress Address of the DAO's governance token.
     */
    struct SupportedDao 
    {
        bool isSupported;
        address daoAdapter;
        address daoTokenAddress;
    }

    /**
     * @dev Struct representing a supported payment asset.
     * @param isSupported Whether this asset is supported for bets.
     * @param assetAddress Address of the ERC20 token.
     */
    struct SupportedPaymentAsset 
    {
        bool isSupported;
        address assetAddress;
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
        uint256 nextProposalId;
        uint256 houseRakePercent; // Basis points (100 = 1%)
        address houseRakeReceiver;
        uint256 resolverPercent; // Basis points (100 = 1%)

        address uniswapRouterAddress;

        mapping(uint256 => Proposal) proposals;
        mapping(address => SupportedDao) supportedDaos;
        mapping(address => SupportedPaymentAsset) supportedPaymentAssets;

        uint256[50] __gap;
    }

    event ProposalAdded(uint256 indexed id, uint256 timestamp);
    event ProposalResolved(uint256 indexed id, address indexed whoBy, uint256 timestamp);
    event NoPayout(uint256 indexed id, address indexed whoBy, uint256 timestamp); 
    event BetPlaced(uint256 indexed proposalId, address indexed whoBy, bool succeeded, uint256 amount, uint256 timestamp);
    event WinningsCollected(uint256 indexed proposalId, address indexed whoTo, uint256 amount);
    event BetReturned(uint256 indexed proposalId, address indexed whoTo, uint256 amount);

    /**
     * @dev Adds a new supported DAO.
     * @param daoAdapterAddress Address of the DAO adapter contract.
     * @param payoutTokenAddress Address of the DAO's governance token.
     */
    function addDao(address daoAdapterAddress, address payoutTokenAddress) external;
    
    /**
     * @dev Adds a new supported payment asset.
     * @param assetAddress Address of the ERC20 token to support.
     */
    function addPaymentAsset(address assetAddress) external;

    /**
     * @dev Creates a new betting proposal.
     * @param daoAdapterAddress Address of the DAO adapter.
     * @param nativeProposalId Array of bytes representing the native proposal ID.
     * @return newProposalId ID of the newly created proposal.
     */
    function addProposal(address daoAdapterAddress, bytes[] memory nativeProposalId) external returns(uint256 newProposalId);
    
    /**
     * @dev Resolves a proposal and calculates payouts.
     * @param proposalId ID of the proposal to resolve.
     */
    function resolveProposal(uint256 proposalId) external;

    /**
     * @dev Places a bet on a proposal.
     * @param asset Address of the token being used to bet.
     * @param proposalId ID of the proposal to bet on.
     * @param succeed Whether the bet is for success (true) or defeat (false).
     * @param amount Amount to bet.
     * @return convertedAmount Amount after any token conversion (if bet in the same asset as payout - this will be the same as amount in).
     */
    function placeBet(address asset, uint256 proposalId, bool succeed, uint256 amount) external returns(uint256 convertedAmount);
    
    /**
     * @dev Collects winnings from a resolved proposal (winning better).
     * @param proposalId ID of the proposal to collect from.
     * @return amount Amount of winnings collected.
     */
    function collectWinnings(uint256 proposalId) external returns(uint256);

    /**
     * @dev Gets proposal details.
     * @param proposalId ID of the proposal to query.
     * @return id Proposal ID.
     * @return createdAt Creation timestamp.
     * @return daoAdapterAddress DAO adapter address.
     * @return succeedTotalBets Total success bets.
     * @return defeatTotalBets Total defeat bets.
     * @return resolverPayout Resolver payout amount (0 until resolved).
     * @return housePayout House payout amount (0 until resolved).
     * @return daoOutcome Current outcome.
     * @return resolvedAt Resolution timestamp (0 if unresolved).
     * This is a view function
     */
    function getProposal(uint256 proposalId) external view returns(
        uint256 id, 
        uint256 createdAt, 
        address daoAdapterAddress, 
        uint256 succeedTotalBets, 
        uint256 defeatTotalBets, 
        uint256 resolverPayout, 
        uint256 housePayout, 
        DaoOutcome daoOutcome, 
        uint256 resolvedAt
    );
    
    /**
     * @dev Gets a user's bets on a specific proposal.
     * @param proposalId ID of the proposal.
     * @param user Address of the user.
     * @return succeedBets Amount bet on success.
     * @return defeatBets Amount bet on defeat.
     * This is a view function
     */
    function getUsersProposalBet(uint256 proposalId, address user) external view returns(uint256 succeedBets, uint256 defeatBets);
    
    /**
     * @dev Gets information about a supported DAO.
     * @param daoAdapterAddress Address of the DAO adapter.
     * @return supportedDao SupportedDao struct with DAO information.
     * This is a view function
     */
    function getDao(address daoAdapterAddress) external view returns(SupportedDao memory supportedDao);
    
    /**
     * @dev Checks if a payment asset is supported.
     * @param paymentAssetAddress Address of the token to check.
     * @return supportedPaymentAsset SupportedPaymentAsset struct with asset information.
     * This is a view function.
     */
    function getPaymentAsset(address paymentAssetAddress) external view returns(SupportedPaymentAsset memory supportedPaymentAsset);
    
    /**
     * @dev Sets the house commission percentage.
     * @param newRate New rate in basis points (1% = 100).
     * This is an admin function only.
     */
    function setHouseRakePercent(uint256 newRate) external;
    
    /**
     * @dev Gets Uniswap swap output amount for token conversion.
     * @param tokenIn Input token address.
     * @param tokenOut Output token address.
     * @param amountIn Input amount.
     * @return amountOut Estimated output amount.
     */
    function getUniswapSwapOutput(address tokenIn, address tokenOut, uint256 amountIn) external view returns (uint256);
}
