// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {Wallet} from "../src/Wallet.sol";

contract WalletScript is Script {
    Wallet public wallet;
    address[] public owners;

    function setUp() public {
        owners.push(vm.envAddress("ACCOUNT_1"));
        owners.push(vm.envAddress("ACCOUNT_2"));
        owners.push(vm.envAddress("ACCOUNT_3"));
        wallet = new Wallet(owners, 2);
    }

    function run() public {
        vm.startBroadcast();

        wallet = new Wallet(owners, 2);

        vm.stopBroadcast();
    }
}
