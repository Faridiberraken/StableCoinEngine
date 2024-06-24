// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {DecentralizedStableCoin} from "./DecentralizedStableCoin.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract DSCEngine {
    //////////////
    //  Errors  //
    //////////////
    error DSCEngine__TokenAddressesAndPriceFeedAddressesAmountsDontMatch();
    error DSCEngine__CollateralTokenIsNotAllowed(address collateralToken);
    error DSCEngine__AmountMustBeMoreThanZero();
    error DSCEngine__TransferFailed();

    event DSCEngine__CollateralDeposited(address token, uint256 amount, address user);

    uint256 public constant PRECISION = 1e18;
    uint256 public constant FEED_PRECISION = 1e8;
    uint256 public constant ADDITIONAL_PRECISION = 1e10;

    DecentralizedStableCoin private immutable i_dsc;

    mapping(address collateralToken => address priceFeed) private s_priceFeeds;

    address[] private s_collateralTokens;

    mapping(address user => mapping(address collateralToken => uint256 amount)) private s_collateralDeposited;

    constructor(address[] memory tokenAddresses, address[] memory priceFeedAddresses, address dscAddress) {
        if (tokenAddresses.length != priceFeedAddresses.length) {
            revert DSCEngine__TokenAddressesAndPriceFeedAddressesAmountsDontMatch();
        }
        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            s_priceFeeds[tokenAddresses[i]] = priceFeedAddresses[i];
            s_collateralTokens.push(tokenAddresses[i]);
        }
        i_dsc = DecentralizedStableCoin(dscAddress);
    }

    function depositCollateralAndMintDsc(address collateralToken, uint256 collateralAmount) external {
        depositCollateral(collateralToken, collateralAmount);
        mintDSC(collateralToken, collateralAmount);
    }

    function depositCollateral(address collateralToken, uint256 collateralAmount) public {
        //Check that the collateral token is allowed
        address priceFeedAddress = s_priceFeeds[collateralToken];
        if (priceFeedAddress == address(0)) {
            revert DSCEngine__CollateralTokenIsNotAllowed(collateralToken);
        }
        //Check than amount is not zero
        if (collateralAmount <= 0) {
            revert DSCEngine__AmountMustBeMoreThanZero();
        }
        //Update the ledger of the sender
        s_collateralDeposited[msg.sender][collateralToken] += collateralAmount;
        // Transfer Collateral amount to this contract
        bool success = IERC20(collateralToken).transferFrom(msg.sender, address(this), collateralAmount);
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
        emit DSCEngine__CollateralDeposited(collateralToken, collateralAmount, msg.sender);
    }

    function getUSDValue(address collateralToken, uint256 collateralAmount) public returns (uint256) {
        //Get price feed
        address priceFeedAddress = s_priceFeeds[collateralToken];
        //Get USD value;
        (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) =
            AggregatorV3Interface(priceFeedAddress).latestRoundData();
        return (uint256(answer) / FEED_PRECISION) * (collateralAmount / PRECISION);
    }

    function mintDSC(address collateralToken, uint256 collateralAmount) public {
        uint256 USDValue = getUSDValue(collateralToken, collateralAmount);
        i_dsc.mint(msg.sender, USDValue / 2);
    }

    ///////////////////////////////////////////
    //external & public view & pure functions//
    ///////////////////////////////////////////

    function getCollateralBalanceOfUser(address user, address token) external view returns (uint256) {
        return s_collateralDeposited[user][token];
    }
}
