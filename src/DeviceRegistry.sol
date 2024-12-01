// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/**
 * @title DeviceRegistry
 * @dev This contract allows publishers to register, update, and unregister their devices.
 */
contract DeviceRegistry {
    struct Device {
        uint256 id;
        address publisher;
        string deviceMetadata; // Information like location, screen size, etc.
        bool isRegistered; // Status of the device
    }

    uint256 public nextDeviceId;
    mapping(uint256 => Device) public devices; // Mapping from device ID to Device struct
    mapping(address => uint256[]) public publisherDevices; // Devices registered by a publisher

    event DeviceRegistered(uint256 indexed deviceId, address indexed publisher);
    event DeviceUpdated(uint256 indexed deviceId);
    event DeviceUnregistered(uint256 indexed deviceId);

    /**
     * @dev Register a new device.
     * @param _deviceMetadata Metadata of the device.
     */
    function registerDevice(
        string memory _deviceMetadata
    ) external returns (uint256) {
        Device memory newDevice = Device({
            id: nextDeviceId,
            publisher: msg.sender,
            deviceMetadata: _deviceMetadata,
            isRegistered: true
        });

        devices[nextDeviceId] = newDevice;
        publisherDevices[msg.sender].push(nextDeviceId);

        emit DeviceRegistered(nextDeviceId, msg.sender);

        nextDeviceId++;

        return newDevice.id;
    }

    /**
     * @dev Update an existing device's metadata.
     * @param _deviceId ID of the device to update.
     * @param _deviceMetadata New metadata for the device.
     */
    function updateDevice(
        uint256 _deviceId,
        string memory _deviceMetadata
    ) external {
        Device storage device = devices[_deviceId];
        require(
            msg.sender == device.publisher,
            "Only publisher can update the device"
        );
        require(device.isRegistered, "Device is not registered");

        device.deviceMetadata = _deviceMetadata;

        emit DeviceUpdated(_deviceId);
    }

    /**
     * @dev Unregister a device.
     * @param _deviceId ID of the device to unregister.
     */
    function unregisterDevice(uint256 _deviceId) external {
        Device storage device = devices[_deviceId];
        require(
            msg.sender == device.publisher,
            "Only publisher can unregister the device"
        );
        require(device.isRegistered, "Device is already unregistered");

        device.isRegistered = false;

        emit DeviceUnregistered(_deviceId);
    }

    /**
     * @dev Retrieve registered devices.
     * @return registeredDevices List of registered device IDs.
     */
    function getRegisteredDevices()
        external
        view
        returns (uint256[] memory registeredDevices)
    {
        uint256 count;
        for (uint256 i = 0; i < nextDeviceId; i++) {
            if (devices[i].isRegistered) {
                count++;
            }
        }

        registeredDevices = new uint256[](count);
        uint256 index;
        for (uint256 i = 0; i < nextDeviceId; i++) {
            if (devices[i].isRegistered) {
                registeredDevices[index] = devices[i].id;
                index++;
            }
        }
    }
}
