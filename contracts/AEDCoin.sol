// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract AEDCoin is ERC20, Ownable {
    // Event for minting and burning
    event Mint(address indexed to, uint256 amount);
    event Burn(address indexed from, uint256 amount);

    constructor() ERC20("AEDCoin", "AEDC") Ownable(msg.sender) {
        // Initial supply can be 0; mint only when AED is deposited
    }

    // Mint function restricted to owner (e.g., escrow admin)
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
        emit Mint(to, amount);
    }

    // Burn function restricted to owner (e.g., for redemption)
    function burn(address from, uint256 amount) external onlyOwner {
        _burn(from, amount);
        emit Burn(from, amount);
    }

    // Optional: Allow users to burn their own tokens (for redemption requests)
    function burnSelf(uint256 amount) external {
        _burn(msg.sender, amount);
        emit Burn(msg.sender, amount);
    }
}