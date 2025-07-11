// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IDaoBets 
{   
    enum DaoOutcome
    {
       Unresolved,
       Cancelled,
       Succeeded,
       Defeated
    }

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

    struct Bet 
    {
        uint256 succeedBets;
        uint256 defeatBets;
        uint256 beenPaidAt;
    }

    struct SupportedDao 
    {
        bool isSupported;
        address daoAdapter;
        address daoTokenAddress;
    }

    struct SupportedPaymentAsset 
    {
        bool isSupported;
        address assetAddress;
    }

    struct AppStorage 
    {
        uint256 nextProposalId;
        uint256 houseRakePercent; // Basis points (100 = 1%)
        address houseRakeReceiver;
        uint256 resolverPercent; // Basis points (100 = 1%)

        address uniswapRouterAddress;
        address priceFeedRouterAddress;

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

    function addDao(address daoAdapterAddress, address payoutTokenAddress) external;
    function addPaymentAsset(address assetAddress) external;
    function addProposal(address daoAdapterAddress, bytes[] memory nativeProposalId) external returns(uint256 newProposalId);
    function resolveProposal(uint256 proposalId) external;
    function placeBet(address asset, uint256 proposalId, bool succeed, uint256 amount) external returns(uint256 convertedAmount);
    function collectWinnings(uint256 proposalId) external returns(uint256);
    function getProposal(uint256 proposalId) external view returns(uint256 id, uint256 createdAt, address daoAdapterAddress, uint256 succeedTotalBets, uint256 defeatTotalBets, uint256 resolverPayout, uint256 housePayout, DaoOutcome daoOutcome, uint256 resolvedAt   );
    function getUsersProposalBet(uint256 proposalId, address user) external view returns(uint256 succeedBets, uint256 defeatBets);
    function getDao(address daoAdapterAddress) external view returns(SupportedDao memory supportedDao);
    function getPaymentAsset(address paymentAssetAddress) external view returns(SupportedPaymentAsset memory supportedPaymentAsset);
    function setHouseRakePercent(uint256 newRate) external;
}