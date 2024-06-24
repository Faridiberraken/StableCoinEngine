// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Test, console} from "forge-std/Test.sol";
import {DeployDSC} from "../script/DeployDSC.s.sol";
import {HelperConfig} from "../script/HelperConfig.s.sol";
import {DecentralizedStableCoin} from "../src/DecentralizedStableCoin.sol";
import {DSCEngine} from "../src/DSCEngine.sol";
import {ERC20Mock, IERC20} from "../test/ERC20Mock.t.sol";

contract DSCEngineTest is Test {
    DSCEngine public dsce;
    DecentralizedStableCoin public dsc;
    HelperConfig public helperConfig;

    address public ethUsdPriceFeed;
    address public btcUsdPriceFeed;
    address public weth;
    address public wbtc;
    uint256 public deployerKey;

    uint256 public constant STARTING_USER_BALANCE = 100 ether;

    uint256 amountCollateral = 10 ether;
    address public user = address(1);

    function setUp() external {
        vm.deal(user, STARTING_USER_BALANCE);
        DeployDSC deployer = new DeployDSC();
        (dsc, dsce, helperConfig) = deployer.run();
        (ethUsdPriceFeed, btcUsdPriceFeed, weth, wbtc, deployerKey) = helperConfig.activeNetwork();
        ERC20Mock(weth).mint(user, STARTING_USER_BALANCE);
        ERC20Mock(wbtc).mint(user, STARTING_USER_BALANCE);
    }

    modifier depositedCollateral() {
        console.log("WETH ", ERC20Mock(weth).balanceOf(user));
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(dsce), amountCollateral);
        dsce.depositCollateral(weth, amountCollateral);
        vm.stopPrank();
        _;
    }

    function testRevertsIfCollateralZero() public {
        vm.startPrank(user);
        ERC20Mock(weth).approve(address(this), amountCollateral);
        vm.expectRevert(DSCEngine.DSCEngine__AmountMustBeMoreThanZero.selector);
        dsce.depositCollateral(weth, 0);
        vm.stopPrank();
    }

    function testRevertsWithUnapprovedCollateral() public {
        vm.startPrank(user);
        ERC20Mock randCollateral = new ERC20Mock("RND", "RND", user, 100);
        ERC20Mock(randCollateral).approve(address(this), amountCollateral);
        vm.expectRevert(
            abi.encodeWithSelector(DSCEngine.DSCEngine__CollateralTokenIsNotAllowed.selector, address(randCollateral))
        );
        dsce.depositCollateral(address(randCollateral), amountCollateral);
        vm.stopPrank();
    }

    function testCollateralDeposited() public depositedCollateral {
        //uint256 bal = IERC20(weth).balanceOf(user);
        uint256 bal = dsce.getCollateralBalanceOfUser(user, weth);
        vm.assertEq(bal, amountCollateral);
    }

    function testGetUsdValue() public {
        uint256 fx = uint256(helperConfig.ETH_USD()) / dsce.FEED_PRECISION();
        uint256 usdVal = dsce.getUSDValue(weth, amountCollateral);
        console.log("UsdVal : ", usdVal);
        console.log("ETH/USD : ", fx);
        vm.assertEq(usdVal, fx * amountCollateral / dsce.PRECISION());
    }

    function testMintDSC() public depositedCollateral {
        vm.startPrank(user);
        dsce.mintDSC(weth, amountCollateral);
        vm.stopPrank();
        uint256 bal = IERC20(dsc).balanceOf(user);
        vm.assertEq(bal, amountCollateral / 2);
    }
}
