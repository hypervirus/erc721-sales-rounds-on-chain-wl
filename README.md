
# ERC721 With On Chain WL and Multiple Sales Rounds

An ERC721 NFT smart contract with fixed supply, multiple sales rounds, on-chain whitelist functionality, and royalties support.

## Features

- **Multiple Sales Rounds**: Configure and manage different sales phases with unique parameters
- **On-Chain Whitelist**: Add/remove addresses to whitelist for each sale round
- **Per-Wallet Limits**: Set maximum tokens per wallet for each round
- **Public/Whitelist Sales**: Toggle between whitelist-only and public sales phases
- **Fixed Supply**: Maximum token count is set at deployment and cannot be changed
- **Hidden Metadata**: Pre-reveal placeholder metadata for all tokens
- **Metadata Reveal**: Owner can reveal the collection when ready
- **ERC721Enumerable**: Full enumeration support for all tokens
- **Royalties Support**: Implements ERC-2981 for marketplace royalties

## Prerequisites

- [Node.js](https://nodejs.org/) (>= 14.x)
- [npm](https://www.npmjs.com/) (>= 6.x)
- [Hardhat](https://hardhat.org/) or [Truffle](https://trufflesuite.com/)
- [OpenZeppelin Contracts](https://www.openzeppelin.com/contracts)

## Installation

1. Create a new project directory and initialize it:

```bash
mkdir my-nft-project
cd my-nft-project
npm init -y
```

2. Install required dependencies:

```bash
npm install --save-dev hardhat @nomiclabs/hardhat-ethers ethers @nomiclabs/hardhat-waffle @openzeppelin/contracts dotenv
```

3. Initialize Hardhat:

```bash
npx hardhat
```

4. Create a `contracts` directory and add the WhitelistNFT contract:

```bash
mkdir contracts
```

5. Create a file named `WhitelistNFT.sol` in the contracts directory and copy the contract code into it.

## Deployment

1. Create a deployment script in the `scripts` directory:

```javascript
// scripts/deploy.js
const hre = require("hardhat");

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with the account:", deployer.address);

  // Deploy WhitelistNFT contract
  const WhitelistNFT = await hre.ethers.getContractFactory("WhitelistNFT");
  const whitelistNFT = await WhitelistNFT.deploy(
    "MyNFTCollection",                // Collection name
    "MNFT",                           // Symbol
    10000,                            // Maximum supply
    "ipfs://QmYourHiddenURI/hidden.json", // Hidden metadata URI
    deployer.address,                 // Royalty receiver address
    500                               // Royalty percentage (5%)
  );

  await whitelistNFT.deployed();
  console.log("WhitelistNFT deployed to:", whitelistNFT.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
```

2. Configure Hardhat network settings in `hardhat.config.js`

3. Deploy the contract:

```bash
npx hardhat run scripts/deploy.js --network <your-network>
```

## Usage Guide

### Contract Deployment Parameters

When deploying the WhitelistNFT contract, you need to provide the following parameters:

1. **_name**: The name of your NFT collection (e.g., "My Awesome NFTs")
2. **_symbol**: A short symbol for your collection (e.g., "MNFT")
3. **_maxSupply**: The maximum number of NFTs that can ever be minted
4. **_hiddenBaseURI**: The URI for hidden metadata before collection reveal (typically points to a single placeholder JSON file)
5. **_royaltyReceiver**: Address that will receive royalties from secondary sales
6. **_royaltyPercentage**: Percentage of sales that go to royalties in basis points (e.g., 500 = 5%)

### Setting Up Sales Rounds

After deployment, you need to set up your sales rounds before minting can begin:

1. Create a new sale round:

```javascript
// Create Round 1 (Whitelist sale)
await whitelistNFT.createSaleRound(
  1,                                      // roundId (sequential)
  0,                                      // state (0=Inactive, 1=Whitelist, 2=Public)
  ethers.utils.parseEther("0.05"),        // price per NFT
  3,                                      // maxPerWallet
  3,                                      // maxPerTransaction
  Math.floor(Date.now() / 1000) + 3600,   // startTime (1 hour from now)
  Math.floor(Date.now() / 1000) + 86400   // endTime (24 hours from now)
);

// Create Round 2 (Public sale)
await whitelistNFT.createSaleRound(
  2,                                      // roundId (sequential)
  2,                                      // state (0=Inactive, 1=Whitelist, 2=Public)
  ethers.utils.parseEther("0.08"),        // higher price for public sale
  5,                                      // maxPerWallet
  5,                                      // maxPerTransaction
  Math.floor(Date.now() / 1000) + 86400,  // startTime (after Round 1 ends)
  Math.floor(Date.now() / 1000) + 172800  // endTime (48 hours after Round 1 ends)
);
```

2. Add addresses to the whitelist for Round 1:

```javascript
// Add whitelist addresses for Round 1
const addresses = [
  "0xabc...",
  "0xdef...",
  "0x123..."
];
await whitelistNFT.addToWhitelist(1, addresses);
```

3. Activate a sale round:

```javascript
// Activate Round 1
await whitelistNFT.activateSaleRound(1);
```

### Managing Sale Rounds

You can change the state of a sale round or adjust the whitelist at any time:

```javascript
// Change Round 1 from Whitelist to Public
await whitelistNFT.updateSaleRoundState(1, 2); // 2 = Public

// Remove addresses from whitelist
const addressesToRemove = ["0xabc..."];
await whitelistNFT.removeFromWhitelist(1, addressesToRemove);
```

### Setting Up Metadata

#### Hidden Metadata

Before revealing your collection, all tokens will return the same hidden metadata URI. This should point to a JSON file with placeholder information:

```json
{
  "name": "Hidden NFT",
  "description": "This NFT has not been revealed yet!",
  "image": "ipfs://QmYourHiddenImageCID/hidden.png"
}
```

#### Revealed Metadata

Prepare your revealed metadata with sequential JSON files. For example, if your base URI is `ipfs://QmRevealedCID/`, then token ID 1 would fetch `ipfs://QmRevealedCID/1.json`.

Each JSON file should follow a structure like:

```json
{
  "name": "NFT #1",
  "description": "Description for NFT #1",
  "image": "ipfs://QmYourImagesCID/1.png",
  "attributes": [
    {
      "trait_type": "Background",
      "value": "Blue"
    },
    {
      "trait_type": "Eyes",
      "value": "Green"
    }
  ]
}
```

### Minting NFTs

Users can mint NFTs by calling the `mint` function and sending the required ETH:

```javascript
// Example using ethers.js
const contractAddress = "0xYourContractAddress";
const abi = [...]; // The ABI of your contract
const quantity = 2; // Number of NFTs to mint
const price = ethers.utils.parseEther("0.1"); // Price per NFT * quantity

const contract = new ethers.Contract(contractAddress, abi, signer);
const tx = await contract.mint(quantity, { value: price });
await tx.wait();
```

The contract will enforce different rules based on the active sale round:
- In a Whitelist round, only whitelisted addresses can mint, up to their allocation
- In a Public round, anyone can mint up to the per-wallet limit

### Owner Functions

#### Revealing the Collection

When you're ready to reveal your collection:

```javascript
const revealedBaseURI = "ipfs://QmYourRevealedMetadataCID/";
const tx = await contract.revealCollection(revealedBaseURI);
await tx.wait();
```

#### Updating Royalty Information

```javascript
const newReceiver = "0xNewRoyaltyReceiverAddress";
const newPercentage = 1000; // 10%
const tx = await contract.setRoyaltyInfo(newReceiver, newPercentage);
await tx.wait();
```

#### Withdrawing Funds

```javascript
const tx = await contract.withdraw();
await tx.wait();
```

## Contract Functions Reference

### Sales Round Management

- **createSaleRound(uint256 _roundId, SaleState _state, uint256 _price, uint256 _maxPerWallet, uint256 _maxPerTransaction, uint256 _startTime, uint256 _endTime)**: Creates a new sale round.
  - Round IDs must be sequential
  - State: 0 = Inactive, 1 = Whitelist, 2 = Public
  - All other parameters are configurable per round

- **activateSaleRound(uint256 _roundId)**: Activates a specific sale round.
  - Can only activate the next sequential round
  - Round must be properly configured

- **updateSaleRoundState(uint256 _roundId, SaleState _state)**: Updates the state of a sale round.
  - Allows changing between Whitelist and Public states

### Whitelist Management

- **addToWhitelist(uint256 _roundId, address[] calldata _addresses)**: Adds addresses to the whitelist for a specific round.

- **removeFromWhitelist(uint256 _roundId, address[] calldata _addresses)**: Removes addresses from the whitelist.

- **isWhitelisted(uint256 _roundId, address _address)**: Checks if an address is whitelisted for a specific round.

### Minting and Metadata

- **mint(uint256 quantity)**: Mints the specified quantity of NFTs to the caller's address.
  - Enforces rules based on the active sale round
  - Requires sending sufficient ETH

- **tokenURI(uint256 tokenId)**: Returns the metadata URI for a specific token.
  - Returns hiddenBaseURI if the collection is not revealed
  - Returns the token-specific URI if the collection is revealed

- **revealCollection(string memory _revealedBaseURI)**: Reveals the collection with the specified base URI.
  - Can only be called by the owner
  - Sets isRevealed to true

### Royalties and Administration

- **royaltyInfo(uint256 tokenId, uint256 salePrice)**: Returns royalty information for a token.
  - Implements ERC-2981 standard
  - Returns the royalty receiver address and the royalty amount based on the sale price

- **setRoyaltyInfo(address _receiver, uint96 _percentage)**: Updates royalty information.
  - Can only be called by the owner
  - Percentage is in basis points (e.g., 500 = 5%)
  - Maximum percentage is 10000 (100%)

- **withdraw()**: Withdraws all funds from the contract to the owner's address.
  - Can only be called by the owner

- **getCurrentSaleRound()**: Returns details of the current active sale round.
  - Useful for frontend applications to display current sale information

## Sale States Explained

The contract uses an enum `SaleState` to track the state of each sale round:

1. **Inactive**: Minting is disabled
2. **Whitelist**: Only addresses on the whitelist for the current round can mint
3. **Public**: Anyone can mint, subject to per-wallet limits

## Security Considerations

- The contract uses OpenZeppelin's battle-tested libraries for security
- Constructor parameters cannot be changed after deployment (particularly maxSupply)
- Owner functions are protected with the Ownable modifier
- Sale rounds have configurable start and end times to prevent early/late minting
- Consider a professional audit before deploying with significant value

## License

This project is licensed under the MIT License - see the LICENSE file for details.
```
