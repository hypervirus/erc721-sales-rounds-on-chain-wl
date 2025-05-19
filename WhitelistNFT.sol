
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/interfaces/IERC2981.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract WhitelistNFT is ERC721Enumerable, Ownable, IERC2981 {
    using Strings for uint256;
    
    // Maximum supply of tokens
    uint256 public immutable maxSupply;
    
    // Hidden URI for metadata before reveal
    string private hiddenBaseURI;
    
    // Revealed URI for metadata after reveal
    string private revealedBaseURI;
    
    // Flag to check if collection is revealed
    bool public isRevealed = false;
    
    // Royalty information
    address private royaltyReceiver;
    uint96 private royaltyPercentage;
    
    // Sale Round struct
    enum SaleState { Inactive, Whitelist, Public }
    
    struct SaleRound {
        SaleState state;
        uint256 price;
        uint256 maxPerWallet;
        uint256 maxPerTransaction;
        uint256 startTime;
        uint256 endTime;
    }
    
    // Current active sale round
    uint256 public currentRoundId;
    
    // Mapping for all sale rounds
    mapping(uint256 => SaleRound) public saleRounds;
    
    // Whitelist mappings
    mapping(uint256 => mapping(address => bool)) public whitelist;
    mapping(uint256 => mapping(address => uint256)) public whitelistMinted;
    
    // Public sale tracking
    mapping(address => uint256) public publicMinted;
    
    // Events
    event SaleRoundCreated(uint256 roundId, uint256 price, SaleState state);
    event SaleRoundUpdated(uint256 roundId, SaleState state);
    event WhitelistUpdated(uint256 roundId, address account, bool isWhitelisted);
    
    constructor(
        string memory _name,
        string memory _symbol,
        uint256 _maxSupply,
        string memory _hiddenBaseURI,
        address _royaltyReceiver,
        uint96 _royaltyPercentage
    ) ERC721(_name, _symbol) Ownable(msg.sender) {
        maxSupply = _maxSupply;
        hiddenBaseURI = _hiddenBaseURI;
        royaltyReceiver = _royaltyReceiver;
        royaltyPercentage = _royaltyPercentage;
        
        // Initialize with inactive round 0
        saleRounds[0] = SaleRound({
            state: SaleState.Inactive,
            price: 0,
            maxPerWallet: 0,
            maxPerTransaction: 0,
            startTime: 0,
            endTime: 0
        });
        currentRoundId = 0;
    }
    
    // Helper function to check if token exists
    function _exists(uint256 tokenId) internal view returns (bool) {
        return tokenId > 0 && tokenId <= totalSupply();
    }
    
    // Public mint function
    function mint(uint256 quantity) external payable {
        SaleRound memory currentRound = saleRounds[currentRoundId];
        
        // Check if sale is active
        require(currentRound.state != SaleState.Inactive, "Sale not active");
        require(block.timestamp >= currentRound.startTime, "Sale not started");
        require(block.timestamp <= currentRound.endTime, "Sale ended");
        
        // Check quantity
        require(quantity > 0, "Must mint at least 1 NFT");
        require(quantity <= currentRound.maxPerTransaction, "Exceeds max per transaction");
        
        // Check supply
        uint256 supply = totalSupply();
        require(supply + quantity <= maxSupply, "Exceeds maximum supply");
        
        // Check payment
        require(msg.value >= currentRound.price * quantity, "Insufficient payment");
        
        // Apply different rules based on sale state
        if (currentRound.state == SaleState.Whitelist) {
            // Check if sender is whitelisted
            require(whitelist[currentRoundId][msg.sender], "Not whitelisted");
            
            // Check whitelist minting limit per wallet
            require(whitelistMinted[currentRoundId][msg.sender] + quantity <= currentRound.maxPerWallet, 
                    "Exceeds whitelist allocation");
            
            // Update minted count
            whitelistMinted[currentRoundId][msg.sender] += quantity;
        } else if (currentRound.state == SaleState.Public) {
            // Check public minting limit per wallet
            require(publicMinted[msg.sender] + quantity <= currentRound.maxPerWallet, 
                    "Exceeds wallet allocation");
            
            // Update minted count
            publicMinted[msg.sender] += quantity;
        }
        
        // Mint tokens
        for (uint256 i = 0; i < quantity; i++) {
            _safeMint(msg.sender, supply + i + 1);
        }
    }
    
    // Owner functions for managing sales rounds
    function createSaleRound(
        uint256 _roundId,
        SaleState _state,
        uint256 _price,
        uint256 _maxPerWallet,
        uint256 _maxPerTransaction,
        uint256 _startTime,
        uint256 _endTime
    ) external onlyOwner {
        require(_roundId > currentRoundId, "Round ID must be sequential");
        require(_endTime > _startTime, "End time must be after start time");
        require(_maxPerTransaction > 0, "Max per tx must be positive");
        require(_maxPerWallet > 0, "Max per wallet must be positive");
        
        saleRounds[_roundId] = SaleRound({
            state: _state,
            price: _price,
            maxPerWallet: _maxPerWallet,
            maxPerTransaction: _maxPerTransaction,
            startTime: _startTime,
            endTime: _endTime
        });
        
        emit SaleRoundCreated(_roundId, _price, _state);
    }
    
    // Activate a specific sale round
    function activateSaleRound(uint256 _roundId) external onlyOwner {
        require(_roundId <= currentRoundId + 1, "Can only activate next round");
        require(saleRounds[_roundId].state != SaleState.Inactive, "Round not configured");
        
        currentRoundId = _roundId;
        
        emit SaleRoundUpdated(_roundId, saleRounds[_roundId].state);
    }
    
    // Update sale round state
    function updateSaleRoundState(uint256 _roundId, SaleState _state) external onlyOwner {
        require(saleRounds[_roundId].state != SaleState.Inactive, "Round not configured");
        
        saleRounds[_roundId].state = _state;
        
        emit SaleRoundUpdated(_roundId, _state);
    }
    
    // Add addresses to whitelist for a specific round
    function addToWhitelist(uint256 _roundId, address[] calldata _addresses) external onlyOwner {
        require(saleRounds[_roundId].state != SaleState.Inactive, "Round not configured");
        
        for (uint256 i = 0; i < _addresses.length; i++) {
            whitelist[_roundId][_addresses[i]] = true;
            emit WhitelistUpdated(_roundId, _addresses[i], true);
        }
    }
    
    // Remove addresses from whitelist for a specific round
    function removeFromWhitelist(uint256 _roundId, address[] calldata _addresses) external onlyOwner {
        require(saleRounds[_roundId].state != SaleState.Inactive, "Round not configured");
        
        for (uint256 i = 0; i < _addresses.length; i++) {
            whitelist[_roundId][_addresses[i]] = false;
            emit WhitelistUpdated(_roundId, _addresses[i], false);
        }
    }
    
    // Override tokenURI function to handle hidden/revealed state
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_exists(tokenId), "Token does not exist");
        
        if (!isRevealed) {
            return hiddenBaseURI;
        }
        
        return string(abi.encodePacked(revealedBaseURI, tokenId.toString(), ".json"));
    }
    
    // Owner function to reveal collection
    function revealCollection(string memory _revealedBaseURI) external onlyOwner {
        revealedBaseURI = _revealedBaseURI;
        isRevealed = true;
    }
    
    // Owner function to set royalty info
    function setRoyaltyInfo(address _receiver, uint96 _percentage) external onlyOwner {
        require(_percentage <= 10000, "Percentage cannot exceed 100%");
        royaltyReceiver = _receiver;
        royaltyPercentage = _percentage;
    }
    
    // Owner function to withdraw funds
    function withdraw() external onlyOwner {
        (bool success, ) = payable(owner()).call{value: address(this).balance}("");
        require(success, "Withdrawal failed");
    }
    
    // Implementation of IERC2981 royaltyInfo
    function royaltyInfo(uint256 _tokenId, uint256 _salePrice) external view override returns (address receiver, uint256 royaltyAmount) {
        require(_exists(_tokenId), "Token does not exist");
        
        // Calculate royalty amount (percentage is in basis points, e.g. 500 = 5%)
        uint256 amount = (_salePrice * royaltyPercentage) / 10000;
        
        return (royaltyReceiver, amount);
    }
    
    // Check if an address is whitelisted for a specific round
    function isWhitelisted(uint256 _roundId, address _address) public view returns (bool) {
        return whitelist[_roundId][_address];
    }
    
    // Get current active sale round details
    function getCurrentSaleRound() public view returns (
        SaleState state,
        uint256 price, 
        uint256 maxPerWallet,
        uint256 maxPerTransaction,
        uint256 startTime,
        uint256 endTime
    ) {
        SaleRound memory round = saleRounds[currentRoundId];
        return (
            round.state,
            round.price,
            round.maxPerWallet,
            round.maxPerTransaction,
            round.startTime,
            round.endTime
        );
    }
    
    // Override supportsInterface to declare IERC2981 support
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721Enumerable, IERC165) returns (bool) {
        return 
            interfaceId == type(IERC2981).interfaceId || 
            super.supportsInterface(interfaceId);
    }
}
