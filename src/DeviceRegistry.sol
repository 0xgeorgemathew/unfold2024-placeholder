// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

// Interface for the Display NFT contract
interface IDisplayNFT {
    function mint(
        address to,
        string memory tokenURI
    ) external returns (uint256);

    function ownerOf(uint256 tokenId) external view returns (address);
}

// OperatorRegistry Contract
contract OperatorRegistry is Ownable {
    using Counters for Counters.Counter;

    struct Display {
        string macId;
        address operator;
        uint256 tokenId;
        bool isActive;
        address currentRightsHolder;
        uint256 rightsExpiryTime;
    }

    Counters.Counter private _displayIds;
    IDisplayNFT public displayNFTContract;

    mapping(uint256 => Display) public displays;
    mapping(string => bool) public registeredMacIds;
    mapping(address => uint256[]) public operatorDisplays;

    event DisplayRegistered(
        uint256 indexed displayId,
        address indexed operator,
        string macId
    );
    event RightsTransferred(
        uint256 indexed displayId,
        address indexed from,
        address indexed to,
        uint256 expiryTime
    );

    constructor(address _displayNFTAddress) {
        displayNFTContract = IDisplayNFT(_displayNFTAddress);
    }

    function registerDisplay(string memory macId) external returns (uint256) {
        require(!registeredMacIds[macId], "MAC ID already registered");

        _displayIds.increment();
        uint256 displayId = _displayIds.current();

        // Mint NFT for the operator
        string memory tokenURI = generateTokenURI(displayId, macId); // You'll implement this off-chain
        uint256 tokenId = displayNFTContract.mint(msg.sender, tokenURI);

        displays[displayId] = Display({
            macId: macId,
            operator: msg.sender,
            tokenId: tokenId,
            isActive: true,
            currentRightsHolder: msg.sender,
            rightsExpiryTime: 0
        });

        registeredMacIds[macId] = true;
        operatorDisplays[msg.sender].push(displayId);

        emit DisplayRegistered(displayId, msg.sender, macId);
        return displayId;
    }

    function transferDisplayRights(
        uint256 displayId,
        address newRightsHolder,
        uint256 duration
    ) external {
        Display storage display = displays[displayId];
        require(msg.sender == display.operator, "Not the operator");
        require(display.isActive, "Display not active");
        require(
            display.rightsExpiryTime < block.timestamp,
            "Existing rights not expired"
        );

        display.currentRightsHolder = newRightsHolder;
        display.rightsExpiryTime = block.timestamp + duration;

        emit RightsTransferred(
            displayId,
            msg.sender,
            newRightsHolder,
            display.rightsExpiryTime
        );
    }

    function getCurrentRightsHolder(
        uint256 displayId
    ) external view returns (address) {
        Display storage display = displays[displayId];
        if (display.rightsExpiryTime < block.timestamp) {
            return display.operator;
        }
        return display.currentRightsHolder;
    }

    function getOperatorDisplays(
        address operator
    ) external view returns (uint256[] memory) {
        return operatorDisplays[operator];
    }

    function deactivateDisplay(uint256 displayId) external {
        Display storage display = displays[displayId];
        require(msg.sender == display.operator, "Not the operator");
        display.isActive = false;
    }
}

// DisplayNFT Contract
contract DisplayNFT is ERC721, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    address public operatorRegistry;

    constructor() ERC721("Display NFT", "DISP") {}

    function setOperatorRegistry(address _operatorRegistry) external onlyOwner {
        operatorRegistry = _operatorRegistry;
    }

    function mint(
        address to,
        string memory tokenURI
    ) external returns (uint256) {
        require(msg.sender == operatorRegistry, "Only registry can mint");

        _tokenIds.increment();
        uint256 tokenId = _tokenIds.current();

        _mint(to, tokenId);
        _setTokenURI(tokenId, tokenURI);

        return tokenId;
    }
}
