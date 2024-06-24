// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import {Script, console} from "forge-std/Script.sol";
import {DecentralizedStableCoin} from "../src/DecentralizedStableCoin.sol";
import {DSCEngine} from "../src/DSCEngine.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeployDSC is Script {
    address[] public tokenAddresses;
    address[] public feedAddresses;

    function run() external returns (DecentralizedStableCoin, DSCEngine, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();

        (address wethUsdPriceFeed, address wbtcUsdPriceFeed, address weth, address wbtc, uint256 deployerKey) =
            helperConfig.activeNetwork();

        tokenAddresses = [weth, wbtc];
        feedAddresses = [wethUsdPriceFeed, wbtcUsdPriceFeed];
        vm.startBroadcast(deployerKey);
        DecentralizedStableCoin dsc = new DecentralizedStableCoin();
        DSCEngine dsce = new DSCEngine(tokenAddresses, feedAddresses, address(dsc));
        dsc.transferOwnership(address(dsce));
        vm.stopBroadcast();
        console.log("DSC ", address(dsc));
        console.log("DSCE ", address(dsce));
        console.log("weth feed ", wethUsdPriceFeed);
        console.log("wbtc feed ", wbtcUsdPriceFeed);
        console.log("weth ", weth);
        console.log("wbtc ", wbtc);
        return (dsc, dsce, helperConfig);
    }
}
