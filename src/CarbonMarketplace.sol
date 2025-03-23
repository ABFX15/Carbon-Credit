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
    error CarbonMarketplace__NotSeller();
    error CarbonMarketplace__NoFundsToWithdraw();
    error CarbonMarketplace__WithdrawFailed();

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
    mapping(address => uint256) private pendingPayments;

    event CreditListed(
        address indexed seller, uint256 indexed creditId, uint256 amount, uint256 price, uint256 timestamp
    );
    event CreditPurchased(
        address indexed buyer, uint256 indexed creditId, uint256 amount, uint256 price, uint256 timestamp
    );
    event ListingCancelled(address indexed seller, uint256 indexed creditId, uint256 timestamp);
    event PaymentWithdrawn(address indexed seller, uint256 amount);

    modifier isActiveListing(uint256 creditId) {
        if (listings[creditId].seller == address(0) || listingStatus[creditId] != ListingStatus.Active) {
            revert CarbonMarketplace__ListingDoesNotExist();
        }
        _;
    }

    constructor(address _carbonCreditsContract) Ownable(msg.sender) {
        carbonCredits = IERC1155(_carbonCreditsContract);
    }

    function listCredit(uint256 creditId, uint256 amount, uint256 price) external {
        if (listings[creditId].seller != address(0)) revert CarbonMarketplace__CreditAlreadyListed();
        if (amount == 0) revert CarbonMarketplace__InvalidAmount();

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

    function purchaseCredit(uint256 creditId, uint256 amount) external payable isActiveListing(creditId) nonReentrant {
        Listing storage listing = listings[creditId];

        if (amount > listing.amountOfCreditsForSale - listing.totalAmountPurchased) {
            revert CarbonMarketplace__InsufficientBalance();
        }
        if (msg.value < listing.price * amount) {
            revert CarbonMarketplace__InsufficientBalance();
        }

        listing.totalAmountPurchased += amount;
        pendingPayments[listing.seller] += msg.value;

        carbonCredits.safeTransferFrom(address(this), msg.sender, creditId, amount, "");

        purchases[creditId] = Purchase({
            buyer: msg.sender,
            tokenId: creditId,
            amountOfCreditsPurchased: amount,
            price: listing.price,
            purchasedAt: block.timestamp
        });

        if (listing.totalAmountPurchased == listing.amountOfCreditsForSale) {
            listingStatus[creditId] = ListingStatus.Completed;
        }
        emit CreditPurchased(msg.sender, creditId, amount, listing.price, block.timestamp);
    }

    function cancelListing(uint256 creditId) external isActiveListing(creditId) {
        if (listings[creditId].seller != msg.sender) revert CarbonMarketplace__NotSeller();
        listingStatus[creditId] = ListingStatus.Cancelled;
        emit ListingCancelled(msg.sender, creditId, block.timestamp);
    }

    function updatePrice() external {}

    function getListing(uint256 creditId) external view returns (Listing memory) {
        return listings[creditId];
    }

    function getListingDetails(uint256 creditId) external view returns (address, uint256, uint256, uint256, uint256, uint256) {
        Listing memory listing = listings[creditId];
        return (listing.seller, listing.tokenId, listing.price, listing.amountOfCreditsForSale, listing.totalAmountPurchased, listing.createdAt);
    }

    function withdrawFunds() external nonReentrant {
        uint256 amount = pendingPayments[msg.sender];
        if (amount == 0) revert CarbonMarketplace__NoFundsToWithdraw();
        
        pendingPayments[msg.sender] = 0;

        (bool success,) = payable(msg.sender).call{value: amount}("");
        if (!success) revert CarbonMarketplace__WithdrawFailed();

        emit PaymentWithdrawn(msg.sender, amount);
    }

    function getPendingPayments(address seller) external view returns (uint256 amount) {
        assembly {
            mstore(0x00, seller)
            mstore(0x20, pendingPayments.slot)
            amount := sload(keccak256(0x00, 0x40))
        }
    }

    function onERC1155Received(address, address, uint256, uint256, bytes memory) external pure returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(address, address, uint256[] calldata, uint256[] calldata, bytes calldata)
        external
        pure
        returns (bytes4)
    {
        return this.onERC1155BatchReceived.selector;
    }

    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return type(IERC1155Receiver).interfaceId == interfaceId;
    }
}
