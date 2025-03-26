# NFT Password Manager 🔐

A decentralized password manager built on Ethereum using NFT (ERC721) technology, where each password entry is represented as a unique NFT.

## Features ✨

- **NFT-Based Storage**: Each password entry is minted as an ERC721 token  
- **Full Ownership**: Users control their password data via NFT ownership  
- **On-Chain Encryption**: Passwords stored with encrypted metadata  
- **Transferable**: Securely transfer password entries by transferring NFTs  
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
function addPassword(string memory website, string memory encryptedUsername, string memory encryptedPassword) public
function updatePassword(uint256 tokenId, string memory newEncryptedPassword) external
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
make test     # Run all tests
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

## Environment Setup

1. Create `.env` file:
```ini
SEPOLIA_RPC_URL=your_rpc_url
PRIVATE_KEY=your_private_key
ETHERSCAN_API_KEY=your_key
```

2. Install dependencies:
```bash
forge install cyfrin/foundry-devops@0.2.2
forge install foundry-rs/forge-std@v1.8.2
forge install openzeppelin/openzeppelin-contracts@v5.0.2
```

## Security Considerations 🔒

- Always encrypt passwords client-side before storage  
- Never commit `.env` files with private keys  
- Mainnet deployment should use hardware wallets  

## Project Structure
```
.
├── contracts/
├── scripts/
├── test/
│   ├── unit/
│   └── integration/
├── lib/
└── Makefile
```

## License
SPDX-License-Identifier: MIT

