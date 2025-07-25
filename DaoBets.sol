// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IDaoBets.sol";
import "./IDaoAdapter.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "https://github.com/Uniswap/uniswap-v2-periphery/blob/master/contracts/interfaces/IUniswapV2Router02.sol";
import "https://github.com/Uniswap/v2-core/blob/master/contracts/interfaces/IUniswapV2Factory.sol";
import "https://github.com/Uniswap/v2-core/blob/master/contracts/interfaces/IUniswapV2Pair.sol";

contract DaoBets is IDaoBets, Initializable, OwnableUpgradeable, ReentrancyGuardUpgradeable, AccessControlUpgradeable, UUPSUpgradeable 
{   
    bytes32 private constant AppStorageSlot = 0x13c87d6460611943c091ab2be6aa0b7b528392dfe308260572dded42cbdb0b73;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _uniswapRouterAddress,
        uint256 _houseRakePercent,
        address _houseRakeReceiver,
        uint256 _resolverPercent
    ) public initializer {
        require(_houseRakeReceiver != address(0), "Invalid receiver");
        require(_uniswapRouterAddress != address(0), "Invalid Uniswap router address");
        require(_houseRakePercent <= 1000, "House rake too high"); // Max 10%
        require(_resolverPercent <= 1000, "Resolver cut too high"); // Max 10%

        __ReentrancyGuard_init();
        __Ownable_init(_msgSender());
        __AccessControl_init();
        __UUPSUpgradeable_init();

        AppStorage storage $ = _appStorage();
        $.houseRakePercent = _houseRakePercent;
        $.houseRakeReceiver = _houseRakeReceiver;
        $.resolverPercent = _resolverPercent;
        $.uniswapRouterAddress = _uniswapRouterAddress;

        _grantRole(DEFAULT_ADMIN_ROLE, _msgSender());
    }

    /**
     * @inheritdoc IDaoBets
     */
    function addDao(
        address daoAdapterAddress, 
        address payoutTokenAddress
    ) public onlyOwner 
    {
        require(daoAdapterAddress != address(0), "Invalid Dao adapter address");
        require(payoutTokenAddress != address(0), "Invalid payout token address");
        require(IDaoAdapter(daoAdapterAddress).supportsInterface(type(IDaoAdapter).interfaceId), "Dao adapter address provided does not implement IDaoAdapter interface");

        AppStorage storage $ = _appStorage();
        $.supportedDaos[daoAdapterAddress] = SupportedDao(true, daoAdapterAddress, payoutTokenAddress);
    }

    /**
     * @inheritdoc IDaoBets
     */
    function addPaymentAsset(address assetAddress) public onlyOwner 
    {
        require(assetAddress != address(0), "Invalid asset token address");

        AppStorage storage $ = _appStorage();
        $.supportedPaymentAssets[assetAddress] = SupportedPaymentAsset(true, assetAddress);
    }

    /**
     * @inheritdoc IDaoBets
     * @dev Creates a new betting proposal after verifying the DAO proposal exists.
     */
    function addProposal(
        address daoAdapterAddress, 
        bytes memory nativeProposalId
    ) external nonReentrant returns(uint256 newProposalId) 
    {
        AppStorage storage $ = _appStorage();
        SupportedDao memory supportedDao = getDao(daoAdapterAddress);

        require(supportedDao.isSupported, "Dao adapter address is not currently supported.");

        IDaoAdapter daoAdapter = IDaoAdapter(daoAdapterAddress);
        require(daoAdapter.externalActiveProposalExists(nativeProposalId), "Proposal doesn't exist on Dao or is not active.");
        
        newProposalId = $.nextProposalId++;

        Proposal storage proposal = $.proposals[newProposalId];
        proposal.id = newProposalId;
        proposal.createdAt = block.timestamp;
        proposal.daoAdapterAddress = daoAdapterAddress;
        proposal.payoutAddress = supportedDao.daoTokenAddress;

        // Map our ID to the native one in the adapter
        daoAdapter.mapProposal(nativeProposalId, newProposalId);

        emit ProposalAdded(newProposalId, block.timestamp);
        return newProposalId;
    }

    /**
     * @inheritdoc IDaoBets
     * @dev Resolves a proposal and calculates payouts based on the outcome.
     * @notice Can only be called after the proposal's voting period has ended.
     */
    function resolveProposal(uint256 proposalId) external nonReentrant 
    {
        AppStorage storage $ = _appStorage();
        Proposal storage proposal = $.proposals[proposalId];
        IDaoAdapter daoAdapter = IDaoAdapter(proposal.daoAdapterAddress);

        require(daoAdapter.proposalIsRegistered(proposalId), "Proposal doesn't exist");
        require(proposal.daoOutcome == DaoOutcome.Unresolved, "Already resolved");
        require(block.timestamp >= daoAdapter.getProposalEndDate(proposalId), "Too early to resolve");

        DaoOutcome outcome = DaoOutcome(uint(daoAdapter.getOutcomeOfProposal(proposalId)));

        if(outcome == DaoOutcome.Succeeded || outcome == DaoOutcome.Defeated)
        {
            uint256 totalLosingBets = (outcome == DaoOutcome.Succeeded) ? proposal.defeatTotalBets : proposal.succeedTotalBets;     
            uint256 totalWinningBets = (outcome == DaoOutcome.Succeeded) ? proposal.succeedTotalBets : proposal.defeatTotalBets;

            proposal.resolverPayout = _payoutResolver(
                totalLosingBets, 
                $.resolverPercent, 
                proposal.payoutAddress
            );
            
            proposal.housePayout = _payoutHouse(
                totalWinningBets, 
                totalLosingBets, 
                proposal.resolverPayout, 
                $.houseRakeReceiver, 
                $.houseRakePercent, 
                proposal.payoutAddress
            );   
        }
        else
        {
            // Otherwise has been cancelled - no payout
            emit NoPayout(proposalId, _msgSender(), block.timestamp);
        }

        proposal.daoOutcome = outcome;
        proposal.resolvedAt = block.timestamp;

        emit ProposalResolved(proposalId, _msgSender(), block.timestamp);
    }

    /**
     * @inheritdoc IDaoBets
     * @dev Places a bet on a proposal, converting assets if necessary.
     * @notice Betting closes 24 hours before the proposal's end date.
     */
    function placeBet(
        address asset,
        uint256 proposalId,
        bool succeed,
        uint256 amount
    ) external nonReentrant returns(uint256 convertedAmount) 
    {
        AppStorage storage $ = _appStorage();
        Proposal storage proposal = $.proposals[proposalId];
        SupportedPaymentAsset memory paymentAsset = getPaymentAsset(asset);
        IDaoAdapter daoAdapter = IDaoAdapter(proposal.daoAdapterAddress);

        require(daoAdapter.proposalIsRegistered(proposalId), "Proposal doesn't exist");
        require(block.timestamp < daoAdapter.getProposalEndDate(proposalId) - 24 hours, "Betting closed");
        require(amount > 0, "Invalid bet amount");
        require(proposal.daoOutcome == DaoOutcome.Unresolved, "Proposal already resolved");
        require(paymentAsset.isSupported, "Payment asset is not supported");

        DaoOutcome outcome = DaoOutcome(uint(daoAdapter.getOutcomeOfProposal(proposalId)));
        require(outcome == DaoOutcome.Unresolved, "Proposal is waiting to be resolved");

        // Transfer the asset to the contract & then convert to the payment asset in uniswap
        convertedAmount = (asset == proposal.payoutAddress) ? amount : _convertAssets(
            $.uniswapRouterAddress,
            asset,
            proposal.payoutAddress,
            amount
        );

        if (succeed) 
        {
            proposal.succeedTotalBets += convertedAmount;
            proposal.userBets[_msgSender()].succeedBets += convertedAmount;
        } else 
        {
            proposal.defeatTotalBets += convertedAmount;
            proposal.userBets[_msgSender()].defeatBets += convertedAmount;
        }

        emit BetPlaced(proposalId, _msgSender(), succeed, convertedAmount, block.timestamp);
    }

    /**
     * @inheritdoc IDaoBets
     * @dev Collects winnings for a resolved proposal.
     * @return amount The amount of winnings collected.
     */
    function collectWinnings(uint256 proposalId) external nonReentrant returns(uint256) 
    {
        AppStorage storage $ = _appStorage();
        Proposal storage proposal = $.proposals[proposalId];
        IDaoAdapter daoAdapter = IDaoAdapter(proposal.daoAdapterAddress);
        
        require(daoAdapter.proposalIsRegistered(proposalId), "Proposal doesn't exist");
        require(proposal.daoOutcome != DaoOutcome.Unresolved, "Proposal not resolved yet");
        require(proposal.userBets[_msgSender()].succeedBets != 0 || proposal.userBets[_msgSender()].defeatBets != 0, "No bets placed");
        
        if (proposal.daoOutcome == DaoOutcome.Cancelled) 
        {
            // Return all funds
            uint256 userBetToReturn = proposal.userBets[_msgSender()].succeedBets + proposal.userBets[_msgSender()].defeatBets;
            proposal.userBets[_msgSender()].succeedBets = 0;
            proposal.userBets[_msgSender()].defeatBets = 0;
            IERC20(proposal.payoutAddress).transfer(_msgSender(), userBetToReturn);
            emit BetReturned(proposalId, _msgSender(), userBetToReturn);

            return userBetToReturn;
        }
        
        uint256 totalWinnerBets = proposal.daoOutcome == DaoOutcome.Succeeded ? proposal.succeedTotalBets : proposal.defeatTotalBets;
        uint256 totalLoserBets = proposal.daoOutcome == DaoOutcome.Succeeded ? proposal.defeatTotalBets : proposal.succeedTotalBets;
        uint256 userWinningBet = proposal.daoOutcome == DaoOutcome.Succeeded ? proposal.userBets[_msgSender()].succeedBets : proposal.userBets[_msgSender()].defeatBets;
        
        require(userWinningBet > 0, "No winning bet to collect");
        
        // The winnings to take from
        uint256 netLosingPot = totalLoserBets - proposal.resolverPayout - proposal.housePayout;
        
        uint256 winnings;
        if (totalWinnerBets == 0) 
        {
            // Edge case whereby there are no winners, this shouldn't happen if user has winning bet
            // House wins here
            revert("No winners exist");
        } else 
        {
            // Normal case whereby the user gets their bet back + proportional share of losing pot
            winnings = userWinningBet + ((userWinningBet * netLosingPot) / totalWinnerBets);
        }

        require(IERC20(proposal.payoutAddress).balanceOf(address(this)) >= winnings, "Insufficient contract balance");
                
        proposal.userBets[_msgSender()].succeedBets = 0;
        proposal.userBets[_msgSender()].defeatBets = 0;

        IERC20(proposal.payoutAddress).transfer(_msgSender(), winnings);

        emit WinningsCollected(proposalId, _msgSender(), winnings);
        
        return winnings;
    }

    /**
     * @inheritdoc IDaoBets
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
    )
    {
        // Has to be storage access because it has nested mapping
        Proposal storage proposal = _appStorage().proposals[proposalId];
        IDaoAdapter daoAdapter = IDaoAdapter(proposal.daoAdapterAddress);
        require(daoAdapter.proposalIsRegistered(proposalId), "Proposal doesn't exist");

        return (
            proposal.id, 
            proposal.createdAt, 
            proposal.daoAdapterAddress, 
            proposal.succeedTotalBets, 
            proposal.defeatTotalBets,
            proposal.resolverPayout,
            proposal.housePayout,
            proposal.daoOutcome ,
            proposal.resolvedAt
        );
    }

    /**
     * @inheritdoc IDaoBets
     */
    function getUsersProposalBet(uint256 proposalId, address user) external view returns(uint256 succeedBets, uint256 defeatBets)
    {
        // Has to be storage access because it has nested mapping
        Proposal storage proposal = _appStorage().proposals[proposalId];
        IDaoAdapter daoAdapter = IDaoAdapter(proposal.daoAdapterAddress);
                
        require(daoAdapter.proposalIsRegistered(proposalId), "Proposal doesn't exist");

        succeedBets = proposal.userBets[user].succeedBets;
        defeatBets = proposal.userBets[user].defeatBets;
    }

    /**
     * @inheritdoc IDaoBets
     */
    function getDao(address daoAdapterAddress) public view returns(SupportedDao memory supportedDao) 
    {
        supportedDao = _appStorage().supportedDaos[daoAdapterAddress];
    }

    /**
     * @inheritdoc IDaoBets
     */
    function getPaymentAsset(address paymentAssetAddress) public view returns(SupportedPaymentAsset memory supportedPaymentAsset) 
    {
        supportedPaymentAsset = _appStorage().supportedPaymentAssets[paymentAssetAddress];
    }

    /**
     * @inheritdoc IDaoBets
     */
    function setHouseRakePercent(uint256 newRate) external onlyOwner 
    {
       _appStorage().houseRakePercent = newRate;
    }

    /**
     * @inheritdoc IDaoBets
     * @dev Calculates the expected output from a Uniswap swap.
     * @notice Reverts if no liquidity pool exists for the token pair.
     */
    function getUniswapSwapOutput(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) public view returns (uint256) 
    {
        AppStorage storage $ = _appStorage();
        IUniswapV2Router02 uniswapRouter = IUniswapV2Router02($.uniswapRouterAddress);

        address pair = IUniswapV2Factory(uniswapRouter.factory()).getPair(tokenIn, tokenOut);
        require(pair != address(0), "No liquidity pool exists for pair provided");
        
        (uint112 reserve0, uint112 reserve1,) = IUniswapV2Pair(pair).getReserves();
        require(reserve0 > 0 && reserve1 > 0, "Insufficient liquidity in pool");

        (uint112 reserveIn, uint112 reserveOut) = IUniswapV2Pair(pair).token0() == tokenIn 
            ? (reserve0, reserve1) 
            : (reserve1, reserve0);
        
        // Calculate output with 0.3% fee accounted for by Uniswap
        uint256 amountInWithFee = amountIn * 997;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = (reserveIn * 1000) + amountInWithFee;
        
        return numerator / denominator;
    }

    /**
     * @dev Internal function to payout resolver commission.
     * @param totalLoserBets Total amount of losing bets.
     * @param percent Commission percentage in basis points.
     * @param tokenAddress Token address for payout.
     * @return payout The amount paid to the resolver.
     */
    function _payoutResolver(
        uint256 totalLoserBets, 
        uint256 percent,
        address tokenAddress
    ) internal returns(uint256) 
    {
        uint256 payout = (totalLoserBets * percent) / 10000;
        if (payout > 0) 
        {
            IERC20(tokenAddress).transfer(_msgSender(), payout);
        }
        return payout;
    }

    /**
     * @dev Internal function to payout house commission.
     * @param totalWinnerBets Total amount of winning bets.
     * @param totalLoserBets Total amount of losing bets.
     * @param resolverAmount Amount already paid to resolver.
     * @param receiver Address to receive house commission.
     * @param percent Commission percentage in basis points.
     * @param tokenAddress Token address for payout.
     * @return payout The amount paid to the house.
     */
    function _payoutHouse(
        uint256 totalWinnerBets, 
        uint256 totalLoserBets, 
        uint256 resolverAmount,
        address receiver, 
        uint256 percent,
        address tokenAddress
    ) internal returns(uint256) 
    {
        uint256 totalLoserBetsMinusResolverAmount = totalLoserBets - resolverAmount;
        uint256 payout = (totalWinnerBets == 0) ? totalLoserBetsMinusResolverAmount : ((totalLoserBetsMinusResolverAmount * percent) / 10000);
        if (payout > 0) 
        {
            IERC20(tokenAddress).transfer(receiver, payout);
        }
        return payout;
    }

    /**
     * @dev Internal function to convert assets via Uniswap.
     * @param uniswapRouterAddress Address of Uniswap router.
     * @param assetFromAddress Token to swap from.
     * @param assetToAddress Token to swap to.
     * @param amountIn Amount to swap.
     * @return convertedAssetAmount Amount received after swap.
     */
    function _convertAssets(
        address uniswapRouterAddress, 
        address assetFromAddress, 
        address assetToAddress, 
        uint256 amountIn
    ) internal returns(uint256 convertedAssetAmount) 
    {
        IERC20(assetFromAddress).transferFrom(_msgSender(), address(this), amountIn);
        IERC20(address(this)).approve(uniswapRouterAddress, amountIn);
        
        address[] memory path = new address[](2);
        path[0] = assetFromAddress;
        path[1] = assetToAddress;

        uint expectedOutValue = getUniswapSwapOutput(
            assetFromAddress, 
            assetToAddress, 
            amountIn
        );
        uint minOut = (expectedOutValue * 98) / 100; // 2% slippage

        uint[] memory amounts = IUniswapV2Router02(uniswapRouterAddress).swapExactTokensForTokens(
            amountIn,
            minOut,
            path,
            address(this),
            block.timestamp + 5 minutes // The deadline before this will fail is now plus 5 mins (protection)
        );

        convertedAssetAmount = amounts[1];
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
