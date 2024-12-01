// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./AdRegistry.sol";
import "./DeviceRegistry.sol";

/**
 * @title PaymentDistribution
 * @dev Handles distribution of ad revenues from advertisers to publishers.
 */
contract PaymentDistribution {
    AdRegistry public adRegistry;
    DeviceRegistry public deviceRegistry;

    // Mapping from ad ID to total impressions
    mapping(uint256 => uint256) public adImpressions;

    // Mapping from device ID to total earnings
    mapping(uint256 => uint256) public deviceEarnings;

    // Event emitted when an ad display is recorded
    event AdDisplayRecorded(uint256 indexed adId, uint256 indexed deviceId);

    // Event emitted when payments are distributed
    event PaymentsDistributed(uint256 totalAmount);

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
     * @dev Record an ad display.
     * @param _adId ID of the ad displayed.
     * @param _deviceId ID of the device that displayed the ad.
     */
    function recordAdDisplay(uint256 _adId, uint256 _deviceId) external {
        // Validate ad and device
        require(adRegistry.getAdStatus(_adId), "Ad is not active");
        require(
            deviceRegistry.devices(_deviceId).isRegistered,
            "Device is not registered"
        );

        // Increment impressions and earnings
        adImpressions[_adId]++;
        deviceEarnings[_deviceId] += calculatePayout(_adId);

        // Update ad's amount spent
        adRegistry.updateAdAmountSpent(_adId, calculatePayout(_adId));

        emit AdDisplayRecorded(_adId, _deviceId);
    }

    /**
     * @dev Distribute payments to devices.
     */
    function distributePayments() external {
        uint256 totalAmountDistributed;

        // Iterate over all devices
        uint256 totalDevices = deviceRegistry.nextDeviceId();
        for (uint256 i = 0; i < totalDevices; i++) {
            DeviceRegistry.Device memory device = deviceRegistry.devices(i);
            if (device.isRegistered && deviceEarnings[device.id] > 0) {
                uint256 earnings = deviceEarnings[device.id];
                deviceEarnings[device.id] = 0;

                payable(device.publisher).transfer(earnings);
                totalAmountDistributed += earnings;
            }
        }

        emit PaymentsDistributed(totalAmountDistributed);
    }

    /**
     * @dev Calculate payout amount for an ad display.
     * @param _adId ID of the ad.
     * @return Payout amount in wei.
     */
    function calculatePayout(uint256 _adId) internal view returns (uint256) {
        // Placeholder for payout calculation logic
        // For example, a fixed amount per impression
        return 1e15; // 0.001 ETH per impression
    }
}
