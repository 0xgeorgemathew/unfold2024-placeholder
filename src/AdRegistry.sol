// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/**
 * @title AdRegistry
 * @dev This contract allows advertisers to submit, update, and withdraw ads.
 */
contract AdRegistry {
    struct Ad {
        uint256 id;
        address payable advertiser;
        string adData; // IPFS hash or URL of the ad content
        string targetingCriteria; // Metadata for ad targeting
        uint256 budget; // Total budget allocated for the ad campaign (in wei)
        uint256 duration; // Duration of the ad campaign in seconds
        uint256 startTime; // Timestamp when the ad was submitted
        uint256 amountSpent; // Total amount spent so far
        bool isActive; // Status of the ad
    }

    uint256 public nextAdId;
    mapping(uint256 => Ad) public ads; // Mapping from ad ID to Ad struct
    mapping(address => uint256[]) public advertiserAds; // Ads submitted by an advertiser

    event AdSubmitted(uint256 indexed adId, address indexed advertiser);
    event AdUpdated(uint256 indexed adId);
    event AdWithdrawn(uint256 indexed adId, uint256 refundAmount);

    /**
     * @dev Submit a new ad to the registry.
     * @param _adData IPFS hash or URL pointing to the ad content.
     * @param _targetingCriteria Metadata for ad targeting.
     * @param _duration Duration of the ad campaign in seconds.
     */
    function submitAd(
        string memory _adData,
        string memory _targetingCriteria,
        uint256 _duration
    ) external payable returns (uint256) {
        require(msg.value > 0, "Budget must be greater than zero");
        require(_duration > 0, "Duration must be greater than zero");

        Ad memory newAd = Ad({
            id: nextAdId,
            advertiser: payable(msg.sender),
            adData: _adData,
            targetingCriteria: _targetingCriteria,
            budget: msg.value,
            duration: _duration,
            startTime: block.timestamp,
            amountSpent: 0,
            isActive: true
        });

        ads[nextAdId] = newAd;
        advertiserAds[msg.sender].push(nextAdId);

        emit AdSubmitted(nextAdId, msg.sender);

        nextAdId++;

        return newAd.id;
    }

    /**
     * @dev Update an existing ad's data and targeting criteria.
     * @param _adId ID of the ad to update.
     * @param _adData New ad content data.
     * @param _targetingCriteria New targeting criteria.
     */
    function updateAd(
        uint256 _adId,
        string memory _adData,
        string memory _targetingCriteria
    ) external {
        Ad storage ad = ads[_adId];
        require(
            msg.sender == ad.advertiser,
            "Only advertiser can update the ad"
        );
        require(ad.isActive, "Ad is not active");

        ad.adData = _adData;
        ad.targetingCriteria = _targetingCriteria;

        emit AdUpdated(_adId);
    }

    /**
     * @dev Withdraw an ad and refund the remaining budget.
     * @param _adId ID of the ad to withdraw.
     */
    function withdrawAd(uint256 _adId) external {
        Ad storage ad = ads[_adId];
        require(
            msg.sender == ad.advertiser,
            "Only advertiser can withdraw the ad"
        );
        require(ad.isActive, "Ad is already inactive");

        ad.isActive = false;

        uint256 refundAmount = ad.budget - ad.amountSpent;
        if (refundAmount > 0) {
            ad.advertiser.transfer(refundAmount);
        }

        emit AdWithdrawn(_adId, refundAmount);
    }

    /**
     * @dev Retrieve active ads.
     * @return activeAds List of active ad IDs.
     */
    function getActiveAds() external view returns (uint256[] memory activeAds) {
        uint256 count;
        for (uint256 i = 0; i < nextAdId; i++) {
            if (ads[i].isActive) {
                count++;
            }
        }

        activeAds = new uint256[](count);
        uint256 index;
        for (uint256 i = 0; i < nextAdId; i++) {
            if (ads[i].isActive) {
                activeAds[index] = ads[i].id;
                index++;
            }
        }
    }
}
