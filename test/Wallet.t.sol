// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Test, console } from "forge-std/Test.sol";
import { Wallet } from "../src/Wallet.sol";

contract WalletTest is Test {
 Wallet public wallet;
 address[] public owners;
 address walletAddress;

 function setUp() public {
  owners.push(vm.envAddress("ACCOUNT_1"));
  owners.push(vm.envAddress("ACCOUNT_2"));
  owners.push(vm.envAddress("ACCOUNT_3"));
  wallet = new Wallet(owners, 2);
  walletAddress = address(wallet);
  vm.deal(walletAddress, 100 ether);
 }

 function test_submitTransaction() public {
  // Owner of account 1 submits a transaction
  vm.prank(owners[0]);
  address recipient =
   vm.envAddress("LUCKY_RECIPIENT_ADDRESS");
  uint256 txId =
   wallet.submitTransaction(recipient, 1 ether, "");
  console.log("Transaction ID submitted: ", txId);

  // Recipient of money tries to confirm, but it fails
  vm.prank(recipient);
  vm.expectRevert("not owner");
  wallet.confirmTransaction(txId);

  // Owner of account 3 confirms agreement
  vm.prank(owners[2]);
  wallet.confirmTransaction(txId);

  // Any of the owners (including the one who did not propose or confirm) can order execution now
  vm.prank(owners[0]);
  wallet.executeTransaction(txId);
  console.log(
   "Balance of lucky recipient after: ",
   recipient.balance / 1 ether
  );
 }
}
