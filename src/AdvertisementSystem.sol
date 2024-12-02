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
    // uint256 public constant BASE_PRICE = 0.001 ether;
    uint256 public constant basePrice = 0.001 ether;
    uint256 public constant UTILIZATION_THRESHOLD = 80;
    uint256 public constant PRICE_MULTIPLIER = 110;
    uint256 public constant PRICE_DIVIDER = 100;

     // Constants
    uint256 private constant PEAK_FACTOR = 130;
    uint256 private constant SHOULDER_FACTOR = 110;
    uint256 private constant OFF_PEAK_FACTOR = 80;
    
    // Position factor constants
    uint256 private constant MAX_POSITION_FACTOR = 140;
    uint256 private constant MIN_POSITION_FACTOR = 80;
    uint256 private constant POSITION_RANGE = MAX_POSITION_FACTOR - MIN_POSITION_FACTOR;

    uint256  constant SCALING_FACTOR = 1e18;
    uint256  constant BASE_PRICE = 100 * SCALING_FACTOR;  // Base price of 100 tokens
    uint256  constant K = 1e36;  // Constant product K = x * y (using high precision)
    uint256  constant MAX_PRICE_MULTIPLIER = 500 * SCALING_FACTOR;  // 500x max increase


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

    // function calculatePrice(uint256 displayId) public view returns (uint256) {
    //     DisplayMetrics memory metric = metrics[displayId];

    //     if (metric.utilization >= UTILIZATION_THRESHOLD) {
    //         return (metric.lastPrice * PRICE_MULTIPLIER) / PRICE_DIVIDER;
    //     }

    //     return metric.lastPrice > 0 ? metric.lastPrice : BASE_PRICE;
    // }

     function calculatePrice(uint256 operatorId) public view returns (uint256) {
        // require(operatorRegistry.isValidOperator(operatorId), "Invalid operator ID");
        
        // Get operator details from registry
        // (, uint256 basePrice, uint256 totalSlots, bool isActive) = operatorRegistry.getOperatorDetails(operatorId);
        // require(isActive, "Operator not active");
        // require(totalSlots > 0, "Invalid total slots");

        uint8 hour = 11;
        uint8 position = 2;
        uint256 demandFactor = calculateDemandFactor(operatorId);
        uint256 timeFactor = getFactorForSlotHour(hour);
        uint256 positionFactor = getPositionFactor(operatorId, position);
        
        uint256 price = basePrice;
        price = price * demandFactor / SCALING_FACTOR;
        price = price * timeFactor / 100;
        price = price * positionFactor / 100;
        
        return price;
    }

    function calculateDemandFactor(uint256 operatorId) public view returns (uint256) {
        // Get operator details from registry
        // (, , uint256 totalSlots, bool isActive) = operatorRegistry.getOperatorDetails(operatorId);
        //  require(isActive, "Operator not active");
        // require(totalSlots > 0, "Invalid slots");
        uint256 totalSlots = 10;
        
        uint256 currentRequests = 4;
        
        // Calculate remaining slots
        uint256 remainingSlots = totalSlots - currentRequests;
        
        // Revert if no slots remaining
        require(remainingSlots > 0, "No slots remaining");
            
        // Using constant product formula: x * y = K
        // where x is remaining slots and y is the price
        // therefore y = K/x
        uint256 price = K / (remainingSlots * SCALING_FACTOR);
        
        // Calculate price multiplier relative to base price
        uint256 priceMultiplier = (price * SCALING_FACTOR) / BASE_PRICE;
        
        // Cap the maximum multiplier
        if (priceMultiplier > MAX_PRICE_MULTIPLIER) {
            priceMultiplier = MAX_PRICE_MULTIPLIER;
        }
        
        return priceMultiplier;
    }
    
    
    function getFactorForSlotHour(uint8 hour) public pure returns (uint256) {
        require(hour < 24, "Invalid hour");
        
        if (hour >= 9 && hour < 17) {
            return PEAK_FACTOR;
        }
        else if (hour >= 17 && hour < 21) {
            return SHOULDER_FACTOR;
        }
        else {
            return OFF_PEAK_FACTOR;
        }
    }
    
    function getPositionFactor(uint256 operatorId, uint8 position) public view returns (uint256) { // To Do : Position should be dynamic or requested from publishers. 
        //  (, , uint256 totalSlots, ) = operatorRegistry.getOperatorDetails(operatorId);
         uint256 totalSlots = 10;

        require(position >= 1 && position <= totalSlots, "Invalid position");
         if (totalSlots == 1) {
            return MAX_POSITION_FACTOR;
        }
         // Calculate the step size between positions based on total slots
        uint256 stepSize = POSITION_RANGE / (totalSlots - 1);
        
        // Calculate factor: starts from MAX_POSITION_FACTOR and decreases by stepSize
        // for each position after the first
        uint256 factor = MAX_POSITION_FACTOR - (stepSize * (position - 1));
        
        // Ensure we don't go below MIN_POSITION_FACTOR
        return factor < MIN_POSITION_FACTOR ? MIN_POSITION_FACTOR : factor;
     
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
