# AEDCoin - AED-Pegged Stablecoin

AEDCoin (AEDC) is a fiat-backed stablecoin pegged 1:1 to the UAE Dirham (AED), built on the Ethereum blockchain as an ERC-20 token. It aims to facilitate seamless digital transactions in the UAE's growing crypto ecosystem while adhering to Central Bank of UAE (CBUAE) regulations.

## Features
- **1:1 Pegging:** Fully backed by AED reserves held in escrow.
- **Restricted Minting/Burning:** Only authorized entities (e.g., escrow admin) can mint or burn tokens.
- **Compliance:** Designed to meet UAE's *Payment Token Services Regulation* requirements.
- **Transparency:** Reserve audits and on-chain verification.

## Tech Stack
- **Blockchain:** Ethereum (deployable to Polygon for scalability).
- **Smart Contract:** Solidity with OpenZeppelin libraries.
- **Development Tools:** Hardhat, Ethers.js.
- **Testing:** Mocha/Chai via Hardhat.

## Prerequisites
- Node.js (>=16.x) and npm
- Hardhat (`npm install --save-dev hardhat`)
- OpenZeppelin Contracts (`npm install @openzeppelin/contracts`)
- Infura/Alchemy API key for testnet/mainnet access
- MetaMask or a wallet with a private key

## Installation
1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/aedcoin.git
   cd aedcoin

Install dependencies:
bash

Collapse

Wrap

Copy
npm install
Configure environment variables:
Create a .env file:
plaintext

Collapse

Wrap

Copy
INFURA_KEY=your_infura_key
PRIVATE_KEY=your_wallet_private_key
Usage
Compile the smart contract:
bash

Collapse

Wrap

Copy
npx hardhat compile
Run tests:
bash

Collapse

Wrap

Copy
npx hardhat test
Deploy to Sepolia testnet:
bash

Collapse

Wrap

Copy
npx hardhat run scripts/deploy.js --network sepolia
Smart Contract
File: contracts/AEDCoin.sol
Key Functions:
mint(address to, uint256 amount): Mint tokens (owner only).
burn(address from, uint256 amount): Burn tokens (owner only).
burnSelf(uint256 amount): User-initiated burn (optional).
Deployment
Testnet: Deployed on Sepolia at [Insert Contract Address].
Mainnet: TBD after regulatory approval.
Contributing
Fork the repository.
Create a feature branch (git checkout -b feature/your-feature).
Commit changes (git commit -m "Add your feature").
Push to the branch (git push origin feature/your-feature).
Open a pull request.
License
MIT License - see  for details.

Contact
For inquiries, reach out to your.email@example.com.

text

Collapse

Wrap

Copy

**Notes:**
- Replace `yourusername`, `your_infura_key`, `your_wallet_private_key`, and `your.email@example.com` with your actual details.
- Add a `LICENSE` file if you want to include one (e.g., MIT License text).
- Update the contract address after deployment.

---

### Notion Document
This is a structured document for your Notion workspace, designed to help you organize the project internally. You can copy this into a new Notion page and format it with headers, tables, and toggles as needed.