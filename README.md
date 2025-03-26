# NFT Password Manager 🔐

A decentralized password manager built on Ethereum using NFT (ERC721) technology, where each password entry is represented as a unique NFT.

## Demo Video 🎥
![Password Manager Demo](./assets/pmkitwalletdemo.gif)

## Features ✨

- **NFT-Based Storage**: Each password entry is minted as an ERC721 token  
- **Full Ownership**: Users control their password data via NFT ownership  
- **On-Chain Encryption**: Encrypted data stored in token metadata  
- **Gas Optimized**: Uses swap-and-pop for efficient deletions  
- **Decentralized**: No central authority controls your data  

## Tech Stack 🛠️

- **Solidity** (Smart Contracts)  
- **Foundry** (Development & Testing)  
- **OpenZeppelin** (ERC721 Implementation)  
- **Hardhat** (Alternative Development)  

## Contract Details 📜

**Contract Name**: PasswordManager  
**Symbol**: CPM  
**Standard**: ERC721  

### Key Functions:
```solidity
function addPassword(string calldata website, string calldata encryptedData) external
function updatePassword(uint256 tokenId, string calldata newEncryptedData) external
function deletePassword(uint256 tokenId) external
function getPasswords() external view returns (PasswordEntry[] memory)
```

## Development Commands ⚙️

### Setup
```bash
make install  # Install dependencies
make update   # Update dependencies
make build    # Build contracts
```

### Testing
```bash
make test     # Run all tests (100% coverage)
make anvil    # Start local Anvil chain (block-time=1)
make snapshot # Create test snapshot
```

### Deployment
```bash
make deploy ARGS="--network sepolia"  # Deploy to Sepolia
make deploy                          # Deploy to local Anvil
```

### Maintenance
```bash
make clean   # Clean project
make remove  # Remove all dependencies
make format  # Format code
```

## Security Considerations 🔒

- Always encrypt data client-side before storage  
- Never commit `.env` files with private keys  
- Mainnet deployment should use hardware wallets  
- Uses O(1) deletion pattern for gas efficiency  

## Project Structure
```
.
├── contracts/
│   └── PasswordManager.sol
├── scripts/
│   └── DeployPasswordManager.s.sol
├── test/
│   └── PasswordManager.t.sol
├── lib/
└── Makefile
```

## License
MIT
