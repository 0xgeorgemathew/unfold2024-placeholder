// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

interface IOperatorRegistry {
    function getCurrentRightsHolder(
        uint256 displayId
    ) external view returns (address);

    function displays(
        uint256 displayId
    )
        external
        view
        returns (
            string memory macId,
            address operator,
            uint256 tokenId,
            bool isActive,
            address currentRightsHolder,
            uint256 rightsExpiryTime
        );
}

contract AdvertisementSystem is Ownable {
    using Math for uint256;

    struct Advertisement {
        string imageUrl;
        address advertiser;
        uint256 paid;
        bool isActive;
        uint256 displayCount;
    }

    struct DisplayMetrics {
        uint256 totalAds;
        uint256 lastPrice;
        uint256 utilization;
    }

    IOperatorRegistry public operatorRegistry;

    // Base price in wei
    uint256 public constant BASE_PRICE = 0.001 ether;
    uint256 public constant UTILIZATION_THRESHOLD = 80;
    uint256 public constant PRICE_MULTIPLIER = 110;
    uint256 public constant PRICE_DIVIDER = 100;

    mapping(uint256 => Advertisement[]) public displayAds; // displayId => ads
    mapping(uint256 => DisplayMetrics) public metrics; // displayId => metrics
    mapping(uint256 => uint256) public currentAdIndex; // displayId => current ad index

    event AdPublished(
        uint256 indexed displayId,
        uint256 indexed adIndex,
        address indexed advertiser,
        string imageUrl
    );
    event AdDisplayed(uint256 indexed displayId, uint256 indexed adIndex);
    event PriceUpdated(uint256 indexed displayId, uint256 newPrice);

    constructor(address _operatorRegistry) Ownable(msg.sender) {
        operatorRegistry = IOperatorRegistry(_operatorRegistry);
    }

    function calculatePrice(uint256 displayId) public view returns (uint256) {
        DisplayMetrics memory metric = metrics[displayId];

        if (metric.utilization >= UTILIZATION_THRESHOLD) {
            return (metric.lastPrice * PRICE_MULTIPLIER) / PRICE_DIVIDER;
        }

        return metric.lastPrice > 0 ? metric.lastPrice : BASE_PRICE;
    }

    function publishAd(
        uint256 displayId,
        string memory imageUrl
    ) external payable {
        (, , , bool isActive, , ) = operatorRegistry.displays(displayId);
        require(isActive, "Display is not active");

        uint256 price = calculatePrice(displayId);
        require(msg.value >= price, "Insufficient payment");

        Advertisement memory newAd = Advertisement({
            imageUrl: imageUrl,
            advertiser: msg.sender,
            paid: msg.value,
            isActive: true,
            displayCount: 0
        });

        uint256 adIndex = displayAds[displayId].length;
        displayAds[displayId].push(newAd);

        // Update metrics
        DisplayMetrics storage metric = metrics[displayId];
        metric.totalAds++;
        metric.lastPrice = price;
        metric.utilization = (metric.totalAds * 100) / (metric.totalAds + 1);

        emit AdPublished(displayId, adIndex, msg.sender, imageUrl);
        emit PriceUpdated(displayId, price);
    }

    function getCurrentAd(
        uint256 displayId
    ) external view returns (string memory imageUrl, address advertiser) {
        require(displayAds[displayId].length > 0, "No ads available");

        uint256 currentIndex = currentAdIndex[displayId] %
            displayAds[displayId].length;
        Advertisement memory ad = displayAds[displayId][currentIndex];

        return (ad.imageUrl, ad.advertiser);
    }

    function rotateAd(uint256 displayId) external {
        address rightsHolder = operatorRegistry.getCurrentRightsHolder(
            displayId
        );
        require(msg.sender == rightsHolder, "Not authorized");
        require(displayAds[displayId].length > 0, "No ads to rotate");

        uint256 currentIndex = currentAdIndex[displayId] %
            displayAds[displayId].length;
        Advertisement storage ad = displayAds[displayId][currentIndex];
        ad.displayCount++;

        currentAdIndex[displayId]++;
        emit AdDisplayed(displayId, currentIndex);
    }

    function getAdStats(
        uint256 displayId,
        uint256 adIndex
    )
        external
        view
        returns (
            string memory imageUrl,
            address advertiser,
            uint256 paid,
            bool isActive,
            uint256 displayCount
        )
    {
        Advertisement memory ad = displayAds[displayId][adIndex];
        return (
            ad.imageUrl,
            ad.advertiser,
            ad.paid,
            ad.isActive,
            ad.displayCount
        );
    }

    function withdrawFees() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No fees to withdraw");

        (bool success, ) = owner().call{value: balance}("");
        require(success, "Transfer failed");
    }
}
