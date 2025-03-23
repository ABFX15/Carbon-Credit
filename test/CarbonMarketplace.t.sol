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

        // Create and mint credits for testing
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

        // Fund the buyer
        vm.deal(buyer, cost);

        // List the credits
        vm.startPrank(owner);
        marketplace.listCredit(creditId, listingAmount, price);
        vm.stopPrank();

        // Record balances before purchase
        uint256 sellerBalanceBefore = owner.balance;
        uint256 buyerBalanceBefore = buyer.balance;

        // Make purchase
        vm.startPrank(buyer);
        vm.expectEmit(true, true, false, true);
        emit CarbonMarketplace.CreditPurchased(buyer, creditId, purchaseAmount, price, block.timestamp);
        marketplace.purchaseCredit{value: cost}(creditId, purchaseAmount);
        vm.stopPrank();

        // Verify token transfer
        assertEq(carbonCredits.balanceOf(buyer, creditId), purchaseAmount);
        console.log("carbonCredits.balanceOf(buyer, creditId)", carbonCredits.balanceOf(buyer, creditId));
        // Verify ETH transfer
        assertEq(owner.balance, sellerBalanceBefore + cost);
        console.log("owner.balance", owner.balance);
        assertEq(buyer.balance, buyerBalanceBefore - cost);
        console.log("buyer.balance", buyer.balance);

        // Verify purchase record
        (
            address purchaseBuyer,
            uint256 purchaseTokenId,
            uint256 purchasedAmount,
            uint256 purchasePrice,
            uint256 purchaseTimestamp
        ) = marketplace.purchases(creditId);

        assertEq(purchaseBuyer, buyer);
        console.log("purchaseBuyer", purchaseBuyer);
        assertEq(purchaseTokenId, creditId);
        console.log("purchaseTokenId", purchaseTokenId);
        assertEq(purchasedAmount, purchaseAmount);
        console.log("purchasedAmount", purchasedAmount);
        assertEq(purchasePrice, price);
        console.log("purchasePrice", purchasePrice);
        assertEq(purchaseTimestamp, block.timestamp);
        console.log("purchaseTimestamp", purchaseTimestamp);

        // Verify listing updated
        (,,,, uint256 totalPurchased,) = marketplace.listings(creditId);
        assertEq(totalPurchased, purchaseAmount);
        console.log("totalPurchased", totalPurchased);
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
