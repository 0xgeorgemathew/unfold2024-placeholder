// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./AdRegistry.sol";
import "./DeviceRegistry.sol";

/**
 * @title AdMatching
 * @dev Matches ads from AdRegistry with devices from DeviceRegistry based on targeting criteria.
 */
contract AdMatching {
    AdRegistry public adRegistry;
    DeviceRegistry public deviceRegistry;

    struct MatchedAd {
        uint256 adId;
        uint256 deviceId;
        uint256 timestamp;
    }

    // Mapping from device ID to list of matched ads
    mapping(uint256 => uint256[]) public deviceToAds;

    // Mapping from ad ID to list of devices
    mapping(uint256 => uint256[]) public adToDevices;

    // Event emitted when ads are matched to devices
    event AdsMatched(uint256 indexed adId, uint256 indexed deviceId);

    /**
     * @dev Constructor to initialize AdRegistry and DeviceRegistry addresses.
     * @param _adRegistry Address of the AdRegistry contract.
     * @param _deviceRegistry Address of the DeviceRegistry contract.
     */
    constructor(address _adRegistry, address _deviceRegistry) {
        adRegistry = AdRegistry(_adRegistry);
        deviceRegistry = DeviceRegistry(_deviceRegistry);
    }

    /**
     * @dev Match ads to devices based on targeting criteria.
     * Note: For simplicity, this function currently matches all active ads to all registered devices.
     * In a real implementation, you'd include logic to match based on targeting criteria.
     */
    function matchAdsToDevices() external {
        uint256[] memory activeAds = adRegistry.getActiveAds();
        uint256[] memory registeredDevices = deviceRegistry
            .getRegisteredDevices();

        for (uint256 i = 0; i < registeredDevices.length; i++) {
            uint256 deviceId = registeredDevices[i];

            for (uint256 j = 0; j < activeAds.length; j++) {
                uint256 adId = activeAds[j];

                // Placeholder for targeting criteria matching
                // bool isMatch = checkTargetingCriteria(adId, deviceId);
                // if (isMatch) { ... }

                deviceToAds[deviceId].push(adId);
                adToDevices[adId].push(deviceId);

                emit AdsMatched(adId, deviceId);
            }
        }
    }

    /**
     * @dev Get ads matched to a specific device.
     * @param _deviceId ID of the device.
     * @return List of ad IDs matched to the device.
     */
    function getAdsForDevice(
        uint256 _deviceId
    ) external view returns (uint256[] memory) {
        return deviceToAds[_deviceId];
    }

    /**
     * @dev Get devices matched to a specific ad.
     * @param _adId ID of the ad.
     * @return List of device IDs matched to the ad.
     */
    function getDevicesForAd(
        uint256 _adId
    ) external view returns (uint256[] memory) {
        return adToDevices[_adId];
    }

    // /**
    //  * @dev Placeholder function to check targeting criteria.
    //  * @param _adId ID of the ad.
    //  * @param _deviceId ID of the device.
    //  * @return True if the ad matches the device's targeting criteria.
    //  */
    // function checkTargetingCriteria(uint256 _adId, uint256 _deviceId) internal view returns (bool) {
    //     // Implement targeting criteria matching logic here.
    //     return true;
    // }
}
