// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {CarbonMarketplace} from "../src/CarbonMarketplace.sol";
import {CarbonCredits} from "../src/CarbonCredits.sol";

contract CarbonMarketplaceTest is Test {
    CarbonMarketplace public marketplace;
    CarbonCredits public carbonCredits;
    address public owner;

    CarbonMarketplace.ListingStatus constant ACTIVE = CarbonMarketplace.ListingStatus.Active;

    function setUp() public {
        owner = makeAddr("owner");
        vm.startPrank(owner);
        carbonCredits = new CarbonCredits();
        marketplace = new CarbonMarketplace(address(carbonCredits));

        uint256 creditId = carbonCredits.createCreditType(2023, "Solar", "US", "Gold");
        carbonCredits.mint(owner, creditId, 1000, "");
        carbonCredits.setApprovalForAll(address(marketplace), true);
        vm.stopPrank();
    }

    function testConstructor() public view {
        assertEq(address(marketplace.carbonCredits()), address(carbonCredits));
        assertEq(marketplace.owner(), owner);
    }

    function testUserCanListCredit() public {
        uint256 creditId = 1;
        uint256 amount = 100;
        uint256 price = 5 ether;

        vm.startPrank(owner);
        marketplace.listCredit(creditId, amount, price);
        vm.stopPrank();

        (
            address seller,
            /*uint256 tokenId*/
            ,
            uint256 listingPrice,
            uint256 amountOfCreditsForSale,
            uint256 totalAmountPurchased,
            /*uint256 createdAt*/
        ) = marketplace.listings(creditId);

        vm.assertEq(seller, owner);
        vm.assertEq(amountOfCreditsForSale, amount);
        vm.assertEq(listingPrice, price);
        vm.assertEq(totalAmountPurchased, 0);
        vm.assertEq(uint256(marketplace.listingStatus(creditId)), uint256(ACTIVE));
    }

    function testUserCanPurchaseCredit() public {
        address buyer = makeAddr("buyer");
        uint256 creditId = 1;
        uint256 listingAmount = 100;
        uint256 price = 5 ether;
        uint256 purchaseAmount = 10;
        uint256 cost = price * purchaseAmount;

        vm.deal(buyer, cost);

        vm.startPrank(owner);
        marketplace.listCredit(creditId, listingAmount, price);
        vm.stopPrank();

        uint256 buyerBalanceBefore = buyer.balance;

        vm.startPrank(buyer);
        vm.expectEmit(true, true, false, true);
        emit CarbonMarketplace.CreditPurchased(buyer, creditId, purchaseAmount, price, block.timestamp);
        marketplace.purchaseCredit{value: cost}(creditId, purchaseAmount);
        vm.stopPrank();

        assertEq(carbonCredits.balanceOf(buyer, creditId), purchaseAmount);

        assertEq(buyer.balance, buyerBalanceBefore - cost);
        assertEq(marketplace.getPendingPayments(owner), cost); // Funds in pending payments

        (
            address purchaseBuyer,
            uint256 purchaseTokenId,
            uint256 purchasedAmount,
            uint256 purchasePrice,
            uint256 purchaseTimestamp
        ) = marketplace.purchases(creditId);

        assertEq(purchaseBuyer, buyer);
        assertEq(purchaseTokenId, creditId);
        assertEq(purchasedAmount, purchaseAmount);
        assertEq(purchasePrice, price);
        assertEq(purchaseTimestamp, block.timestamp);

        (,,,, uint256 totalPurchased,) = marketplace.listings(creditId);
        assertEq(totalPurchased, purchaseAmount);
    }

    function testSellerCanWithdrawFunds() public {
        testUserCanPurchaseCredit();

        uint256 balanceBefore = owner.balance;
        uint256 expectedWithdrawal = marketplace.getPendingPayments(owner);

        vm.startPrank(owner);
        vm.expectEmit(true, false, false, true);
        emit CarbonMarketplace.PaymentWithdrawn(owner, expectedWithdrawal);
        marketplace.withdrawFunds();
        vm.stopPrank();

        assertEq(owner.balance, balanceBefore + expectedWithdrawal);
        assertEq(marketplace.getPendingPayments(owner), 0);
    }

    function testCanGetListingDetails() public {
        uint256 creditId = 1;
        uint256 amount = 100;
        uint256 price = 5 ether;

        vm.startPrank(owner);
        marketplace.listCredit(creditId, amount, price);
        vm.stopPrank();
    }
}
