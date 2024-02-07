// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/Address.sol";

contract NFTMarketplace {
    using Address for address payable;

    // Structure to hold the details of a listing
    struct Listing {
        uint256 price;
        address owner;
        bool isActive;
    }

    // Mapping to track the listings for each NFT
    mapping(address => mapping(uint256 => Listing)) private listings;

    // Mapping to track the ownership of an NFT
    mapping(address => mapping(uint256 => address)) private nftOwners;

    uint256 public feePercentage;

    event ListingCreated(address indexed nftAddress, uint256 indexed tokenId, uint256 price);
    event ListingUpdated(address indexed nftAddress, uint256 indexed tokenId, uint256 price);
    event ListingRemoved(address indexed nftAddress, uint256 indexed tokenId);
    event NFTSold(address indexed buyer, address indexed seller, address indexed nftAddress, uint256 tokenId, uint256 price);

    constructor() {
        feePercentage = 2; // 2% fee by default
    }

    // Function to list an NFT for sale
    function listNFT(address nftAddress, uint256 tokenId, uint256 price) external {
        require(price > 0, "Price must be greater than zero");
        require(!_isNFTOnMarketplace(nftAddress, tokenId), "NFT is already listed");

        IERC721 nftContract = IERC721(nftAddress);
        address nftOwner = nftContract.ownerOf(tokenId);
        require(nftOwner == msg.sender, "Caller is not the NFT owner");

        nftContract.safeTransferFrom(nftOwner, address(this), tokenId);
        listings[nftAddress][tokenId] = Listing(price, nftOwner, true);
        nftOwners[nftAddress][tokenId] = nftOwner;

        emit ListingCreated(nftAddress, tokenId, price);
    }

    // Function to update the price of an existing listing
    function updateListingPrice(address nftAddress, uint256 tokenId, uint256 newPrice) external {
        require(newPrice > 0, "New price must be greater than zero");
        require(_isNFTOnMarketplace(nftAddress, tokenId), "NFT is not listed");
        require(msg.sender == listings[nftAddress][tokenId].owner, "Caller is not the owner of the listing");

        listings[nftAddress][tokenId].price = newPrice;
        emit ListingUpdated(nftAddress, tokenId, newPrice);
    }

    // Function to remove an existing listing
    function removeListing(address nftAddress, uint256 tokenId) external {
        require(_isNFTOnMarketplace(nftAddress, tokenId), "NFT is not listed");
        require(msg.sender == listings[nftAddress][tokenId].owner, "Caller is not the owner of the listing");

        delete listings[nftAddress][tokenId];
        delete nftOwners[nftAddress][tokenId];

        IERC721 nftContract = IERC721(nftAddress);
        address nftOwner = nftOwners[nftAddress][tokenId];
        nftContract.safeTransferFrom(address(this), nftOwner, tokenId);

        emit ListingRemoved(nftAddress, tokenId);
    }

    // Function to buy an NFT from the marketplace
    function buyNFT(address nftAddress, uint256 tokenId) external payable {
        require(_isNFTOnMarketplace(nftAddress, tokenId), "NFT is not listed");

        Listing storage listing = listings[nftAddress][tokenId];
        require(msg.value >= listing.price, "Insufficient payment");

        address seller = listing.owner;
        address buyer = msg.sender;
        uint256 salePrice = listing.price;
        uint256 feeAmount = (salePrice * feePercentage) / 100;

        delete listings[nftAddress][tokenId];
        delete nftOwners[nftAddress][tokenId];

        IERC721 nftContract = IERC721(nftAddress);
        nftContract.safeTransferFrom(address(this), buyer, tokenId);

        payable(seller).sendValue(salePrice - feeAmount);
        payable(owner()).sendValue(feeAmount);

        emit NFTSold(buyer, seller, nftAddress, tokenId, salePrice);
    }

    // Function to get the listing details for an NFT
    function getListing(address nftAddress, uint256 tokenId) external view returns (Listing memory) {
        require(_isNFTOnMarketplace(nftAddress, tokenId), "NFT is not listed");

        return listings[nftAddress][tokenId];
    }

    // Function to check if an NFT is listed on the marketplace
    function _isNFTOnMarketplace(address nftAddress, uint256 tokenId) private view returns (bool) {
        return listings[nftAddress][tokenId].isActive;
    }

    // Function to get the address of the contract owner
    function owner() public view returns (address) {
        return address(this);
    }

    // Function to update the fee percentage
    function updateFeePercentage(uint256 newFeePercentage) external {
        require(msg.sender == owner(), "Caller is not the contract owner");
        require(newFeePercentage <= 100, "Fee percentage can not exceed 100");

        feePercentage = newFeePercentage;
    }
}