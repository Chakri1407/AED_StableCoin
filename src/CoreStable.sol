// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract CoreStable is Initializable, ERC20Upgradeable, OwnableUpgradeable, UUPSUpgradeable {
    AggregatorV3Interface internal priceFeed;
    
    uint256 public constant USD_PRECISION = 1e18;
    address public priceFeedAddress;

    event Minted(address indexed to, uint256 amount, uint256 ethAmount);
    event Burned(address indexed from, uint256 amount, uint256 ethAmount);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _priceFeedAddress) external initializer {
        __ERC20_init("CoreStable", "CUSD");
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
        
        require(_priceFeedAddress != address(0), "Invalid price feed address");
        priceFeedAddress = _priceFeedAddress;
        priceFeed = AggregatorV3Interface(_priceFeedAddress);
    }

    function getLatestPrice() public view returns (uint256) {
        (, int256 price,,,) = priceFeed.latestRoundData();
        require(price > 0, "Invalid price feed");
        return uint256(price) * 1e10;
    }

    function mint() external payable {
        require(msg.value > 0, "ETH amount must be greater than 0");
        
        uint256 ethPrice = getLatestPrice();
        uint256 stableCoinAmount = (msg.value * ethPrice) / 1e18;
        
        _mint(msg.sender, stableCoinAmount);
        emit Minted(msg.sender, stableCoinAmount, msg.value);
    }

    function burn(uint256 amount) external {
        require(amount > 0, "Amount must be greater than 0");
        require(balanceOf(msg.sender) >= amount, "Insufficient balance");
        
        uint256 ethPrice = getLatestPrice();
        uint256 ethAmount = (amount * 1e18) / ethPrice;
        
        _burn(msg.sender, amount);
        payable(msg.sender).transfer(ethAmount);
        emit Burned(msg.sender, amount, ethAmount);
    }

    function updatePriceFeed(address _newPriceFeedAddress) external onlyOwner {
        require(_newPriceFeedAddress != address(0), "Invalid address");
        priceFeedAddress = _newPriceFeedAddress;
        priceFeed = AggregatorV3Interface(_newPriceFeedAddress);
    }


    receive() external payable {
        revert("Use mint function to deposit ETH");
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}