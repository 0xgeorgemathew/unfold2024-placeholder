// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

interface IDisplayNFT {
    function mint(
        address to,
        string memory tokenURI
    ) external returns (uint256);

    function ownerOf(uint256 tokenId) external view returns (address);
}

contract OperatorRegistry is Ownable {
    struct Display {
        string macId;
        address operator;
        uint256 tokenId;
        bool isActive;
        address currentRightsHolder;
        uint256 rightsExpiryTime;
    }

    uint256 private _displayIds;
    IDisplayNFT public displayNFTContract;
    string public baseTokenURI;

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
    event BaseURIUpdated(string newBaseURI);

    constructor(
        address _displayNFTAddress,
        string memory _baseTokenURI
    ) Ownable(msg.sender) {
        displayNFTContract = IDisplayNFT(_displayNFTAddress);
        baseTokenURI = _baseTokenURI;
    }

    function setBaseTokenURI(string memory newBaseURI) external onlyOwner {
        baseTokenURI = newBaseURI;
        emit BaseURIUpdated(newBaseURI);
    }

    function createTokenURI(
        uint256 displayId,
        string memory macId
    ) internal view returns (string memory) {
        return string(abi.encodePacked(baseTokenURI, displayId));
    }

    function registerDisplay(string memory macId) external returns (uint256) {
        require(!registeredMacIds[macId], "MAC ID already registered");

        _displayIds += 1;
        uint256 displayId = _displayIds;

        string memory tokenURI = createTokenURI(displayId, macId);
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

contract DisplayNFT is ERC721URIStorage, Ownable {
    uint256 private _tokenIds;
    address public operatorRegistry;

    constructor() ERC721("Display NFT", "DISP") Ownable(msg.sender) {}

    function setOperatorRegistry(address _operatorRegistry) external onlyOwner {
        operatorRegistry = _operatorRegistry;
    }

    function mint(
        address to,
        string memory tokenURI
    ) external returns (uint256) {
        require(msg.sender == operatorRegistry, "Only registry can mint");

        _tokenIds += 1;
        uint256 tokenId = _tokenIds;

        _mint(to, tokenId);
        _setTokenURI(tokenId, tokenURI);

        return tokenId;
    }
}
