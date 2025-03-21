// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {IERC1155Receiver} from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import {CarbonCredits} from "./CarbonCredits.sol";

contract CarbonMarketplace is Ownable, ReentrancyGuard, IERC1155Receiver {
    error CarbonMarketplace__CreditAlreadyListed();
    error CarbonMarketplace__InvalidAmount();
    error CarbonMarketplace__ListingDoesNotExist();
    error CarbonMarketplace__InsufficientBalance();

    struct Listing {
        address seller;
        uint256 tokenId;
        uint256 price;
        uint256 amountOfCreditsForSale;
        uint256 totalAmountPurchased;
        uint256 createdAt;
    }

    struct Purchase {
        address buyer;
        uint256 tokenId;
        uint256 amountOfCreditsPurchased;
        uint256 price;
        uint256 purchasedAt;
    }

    enum ListingStatus {
        Active,
        Cancelled,
        Completed
    }

    IERC1155 public carbonCredits;

    mapping(uint256 => Listing) public listings;
    mapping(uint256 => Purchase) public purchases;
    mapping(uint256 => ListingStatus) public listingStatus;

    event CreditListed(address indexed seller, uint256 indexed creditId, uint256 amount, uint256 price, uint256 timestamp);
    event CreditPurchased(address indexed buyer, uint256 indexed creditId, uint256 amount, uint256 price, uint256 timestamp);
    
    constructor(address _carbonCreditsContract) Ownable(msg.sender) {
        carbonCredits = IERC1155(_carbonCreditsContract);
    }

    function listCredit(uint256 creditId, uint256 amount, uint256 price) external {
        if(listings[creditId].seller != address(0)) revert CarbonMarketplace__CreditAlreadyListed();
        if(amount == 0) revert CarbonMarketplace__InvalidAmount();

        carbonCredits.safeTransferFrom(msg.sender, address(this), creditId, amount, "");
        
        listings[creditId] = Listing({
            seller: msg.sender,
            tokenId: creditId,
            price: price,
            amountOfCreditsForSale: amount,
            totalAmountPurchased: 0,
            createdAt: block.timestamp
        });
        listingStatus[creditId] = ListingStatus.Active;

        emit CreditListed(msg.sender, creditId, amount, price, block.timestamp);

    }   

    function purchaseCredit(uint256 creditId, uint256 amount) external payable {
        if(listings[creditId].seller == address(0) || listingStatus[creditId] != ListingStatus.Active) 
            revert CarbonMarketplace__ListingDoesNotExist();

        Listing storage listing = listings[creditId];
        if(amount > listing.amountOfCreditsForSale - listing.totalAmountPurchased) 
            revert CarbonMarketplace__InsufficientBalance();
        if(msg.value < listing.price * amount) 
            revert CarbonMarketplace__InsufficientBalance();
        
        listing.totalAmountPurchased += amount;
        payable(listing.seller).transfer(msg.value);
        
        carbonCredits.safeTransferFrom(
            address(this),
            msg.sender,
            creditId,
            amount,
            ""
        );

        purchases[creditId] = Purchase({
            buyer: msg.sender,
            tokenId: creditId,
            amountOfCreditsPurchased: amount,
            price: listing.price,
            purchasedAt: block.timestamp
        });

        if(listing.totalAmountPurchased == listing.amountOfCreditsForSale) {
            listingStatus[creditId] = ListingStatus.Completed;
        }
        emit CreditPurchased(msg.sender, creditId, amount, listing.price, block.timestamp);
    }

    function cancelListing() external {}

    function updatePrice() external {}

    function getListing() external view returns (uint256) {}

    function getListingDetails() external view returns (uint256, uint256, uint256) {}

    function withdrawFunds() external {}

    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes memory
    ) external pure returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] calldata,
        uint256[] calldata,
        bytes calldata
    ) external pure returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }

    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return type(IERC1155Receiver).interfaceId == interfaceId;
    }

}
