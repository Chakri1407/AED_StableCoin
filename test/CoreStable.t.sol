pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/CoreStable.sol";
import "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "lib/chainlink-brownie-contracts/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract MockPriceFeed is AggregatorV3Interface {
    int256 private price;
    
    function setPrice(int256 _price) external {
        price = _price;
    }
    
    function decimals() external pure override returns (uint8) {
        return 8; // ETH/USD price feed uses 8 decimals
    }
    
    function description() external pure override returns (string memory) {
        return "ETH/USD Price Feed";
    }
    
    function version() external pure override returns (uint256) {
        return 1;
    }
    
    function getRoundData(uint80) external view override returns (
        uint80 roundId,
        int256 answer,
        uint256 startedAt,
        uint256 updatedAt,
        uint80 answeredInRound
    ) {
        return (1, price, block.timestamp, block.timestamp, 1);
    }
    
    function latestRoundData() external view override returns (
        uint80 roundId,
        int256 answer,
        uint256 startedAt,
        uint256 updatedAt,
        uint80 answeredInRound
    ) {
        return (1, price, block.timestamp, block.timestamp, 1);
    }
}

contract CoreStableTest is Test {
    CoreStable public coreStable;
    ERC1967Proxy public proxy;
    MockPriceFeed public priceFeed;
    address public owner;
    address public user1;
    address public user2;
    
    // Chainlink ETH/USD price feed address on Polygon Amoy testnet
    address public constant PRICE_FEED_ADDRESS = 0xF0d50568e3A7e8259E16663972b11910F89BD8e7;
    
    uint256 constant INITIAL_PRICE = 2000e8; // $2000 per ETH (8 decimals)
    uint256 constant ETH_AMOUNT = 1 ether;
    uint256 constant SMALL_ETH_AMOUNT = 1e15; // 0.001 ETH
    
    event Minted(address indexed to, uint256 amount, uint256 ethAmount);
    event Burned(address indexed from, uint256 amount, uint256 ethAmount);
    
    function setUp() public {
        owner = address(this);
        user1 = address(0x1);
        user2 = address(0x2);
        
        priceFeed = new MockPriceFeed();
        priceFeed.setPrice(int256(INITIAL_PRICE));
        
        // Deploy implementation
        CoreStable implementation = new CoreStable();
        
        // Deploy proxy and initialize with the mock price feed
        proxy = new ERC1967Proxy(
            address(implementation),
            abi.encodeWithSelector(
                CoreStable.initialize.selector,
                address(priceFeed)
            )
        );
        
        coreStable = CoreStable(payable(address(proxy)));
    }
    
    function testInitialize() public view {
        assertEq(coreStable.name(), "CoreStable");
        assertEq(coreStable.symbol(), "CUSD");
        assertEq(coreStable.owner(), owner);
        assertEq(coreStable.priceFeedAddress(), address(priceFeed));
    }
    
    function testInitializeInvalidPriceFeed() public {
        CoreStable implementation = new CoreStable();
        vm.expectRevert("Invalid price feed address");
        new ERC1967Proxy(
            address(implementation),
            abi.encodeWithSelector(
                CoreStable.initialize.selector,
                address(0)
            )
        );
    }
    
    function testGetLatestPrice() public view {
        uint256 expectedPrice = INITIAL_PRICE * 1e10; // Adjust to 18 decimals
        assertEq(coreStable.getLatestPrice(), expectedPrice);
    }
    
    function testGetLatestPriceInvalidPrice() public {
        priceFeed.setPrice(0);
        vm.expectRevert("Invalid price feed");
        coreStable.getLatestPrice();
    }
    
    function testGetLatestPriceNegativePrice() public {
        priceFeed.setPrice(-1000e8);
        vm.expectRevert("Invalid price feed");
        coreStable.getLatestPrice();
    }
    
    function testGetLatestPriceHighPrice() public {
        uint256 highPrice = 100000e8; // $100,000 per ETH
        priceFeed.setPrice(int256(highPrice));
        assertEq(coreStable.getLatestPrice(), highPrice * 1e10);
    }
    
    function testMintWithPriceFeed() public {
        vm.deal(user1, ETH_AMOUNT);
        vm.startPrank(user1);
        
        uint256 expectedStableCoinAmount = (ETH_AMOUNT * INITIAL_PRICE * 1e10) / 1e18;
        console.log("Mint: Expected StableCoinAmount:", expectedStableCoinAmount);
        
        vm.expectEmit(true, false, false, true);
        emit Minted(user1, expectedStableCoinAmount, ETH_AMOUNT);
        
        coreStable.mint{value: ETH_AMOUNT}();
        
        assertEq(coreStable.balanceOf(user1), expectedStableCoinAmount);
        assertEq(address(coreStable).balance, ETH_AMOUNT);
        
        vm.stopPrank();
    }
    
    function testMintZeroETH() public {
        vm.prank(user1);
        vm.expectRevert("ETH amount must be greater than 0");
        coreStable.mint{value: 0}();
    }
    
    function testMintSmallAmount() public {
        vm.deal(user1, SMALL_ETH_AMOUNT);
        vm.prank(user1);
        
        uint256 expectedStableCoinAmount = (SMALL_ETH_AMOUNT * INITIAL_PRICE * 1e10) / 1e18;
        console.log("MintSmall: Expected StableCoinAmount:", expectedStableCoinAmount);
        
        coreStable.mint{value: SMALL_ETH_AMOUNT}();
        assertEq(coreStable.balanceOf(user1), expectedStableCoinAmount);
    }
    
    function testMintWithPriceChange() public {
        uint256 newPrice = 3000e8; // $3000 per ETH
        priceFeed.setPrice(int256(newPrice));
        
        vm.deal(user1, ETH_AMOUNT);
        vm.prank(user1);
        
        uint256 expectedStableCoinAmount = (ETH_AMOUNT * newPrice * 1e10) / 1e18;
        console.log("MintWithPriceChange: Expected StableCoinAmount:", expectedStableCoinAmount);
        
        coreStable.mint{value: ETH_AMOUNT}();
        assertEq(coreStable.balanceOf(user1), expectedStableCoinAmount);
    }
    
    function testBurn() public {
        // Mint tokens
        vm.deal(user1, ETH_AMOUNT);
        vm.prank(user1);
        coreStable.mint{value: ETH_AMOUNT}();
        
        uint256 stableCoinAmount = coreStable.balanceOf(user1);
        uint256 expectedEthAmount = (stableCoinAmount * 1e18) / (INITIAL_PRICE * 1e10);
        
        console.log("Burn: StableCoinAmount:", stableCoinAmount);
        console.log("Burn: ExpectedEthAmount:", expectedEthAmount);
        console.log("Burn: Contract ETH Balance Before:", address(coreStable).balance);
        
        vm.startPrank(user1);
        
        // Record logs to capture actual event data
        vm.recordLogs();
        coreStable.burn(stableCoinAmount);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        uint256 actualEthAmount;
        for (uint i = 0; i < logs.length; i++) {
            if (logs[i].topics[0] == keccak256("Burned(address,uint256,uint256)")) {
                (, uint256 burnedAmount, uint256 ethAmount) = abi.decode(logs[i].data, (address, uint256, uint256));
                actualEthAmount = ethAmount;
                console.log("Burn: Actual Burned Amount:", burnedAmount);
                console.log("Burn: Actual EthAmount:", actualEthAmount);
            }
        }
        
        console.log("Burn: Contract ETH Balance After:", address(coreStable).balance);
        console.log("Burn: User ETH Balance After:", user1.balance);
        
        assertEq(coreStable.balanceOf(user1), 0);
        assertEq(address(coreStable).balance, ETH_AMOUNT - expectedEthAmount);
        assertEq(actualEthAmount, expectedEthAmount, "Burned event ethAmount mismatch");
        
        vm.stopPrank();
    }
    
    function testBurnZeroAmount() public {
        vm.prank(user1);
        vm.expectRevert("Amount must be greater than 0");
        coreStable.burn(0);
    }
    
    function testBurnInsufficientBalance() public {
        vm.prank(user1);
        vm.expectRevert("Insufficient balance");
        coreStable.burn(100);
    }
    
    function testBurnSmallAmount() public {
        vm.deal(user1, SMALL_ETH_AMOUNT);
        vm.prank(user1);
        coreStable.mint{value: SMALL_ETH_AMOUNT}();
        
        uint256 stableCoinAmount = coreStable.balanceOf(user1);
        uint256 expectedEthAmount = (stableCoinAmount * 1e18) / (INITIAL_PRICE * 1e10);
        
        console.log("BurnSmall: StableCoinAmount:", stableCoinAmount);
        console.log("BurnSmall: ExpectedEthAmount:", expectedEthAmount);
        
        coreStable.burn(stableCoinAmount);
        assertEq(coreStable.balanceOf(user1), 0);
        assertEq(address(coreStable).balance, SMALL_ETH_AMOUNT - expectedEthAmount);
    }
    
    function testBurnWithPriceChange() public {
        // Mint with initial price
        vm.deal(user1, ETH_AMOUNT);
        vm.prank(user1);
        coreStable.mint{value: ETH_AMOUNT}();
        
        // Change price to 4000 USD/ETH (reduces ETH output)
        uint256 newPrice = 4000e8;
        priceFeed.setPrice(int256(newPrice));
        
        uint256 stableCoinAmount = coreStable.balanceOf(user1);
        uint256 expectedEthAmount = (stableCoinAmount * 1e18) / (newPrice * 1e10);
        
        console.log("BurnWithPriceChange: StableCoinAmount:", stableCoinAmount);
        console.log("BurnWithPriceChange: ExpectedEthAmount:", expectedEthAmount);
        console.log("BurnWithPriceChange: Contract ETH Balance Before:", address(coreStable).balance);
        
        vm.prank(user1);
        vm.expectEmit(true, false, false, true);
        emit Burned(user1, stableCoinAmount, expectedEthAmount);
        
        coreStable.burn(stableCoinAmount);
        
        console.log("BurnWithPriceChange: Contract ETH Balance After:", address(coreStable).balance);
        
        assertEq(coreStable.balanceOf(user1), 0);
        assertEq(address(coreStable).balance, ETH_AMOUNT - expectedEthAmount);
    }
    
    function testBurnWithPriceChangeInsufficientBalance() public {
        // Mint with initial price
        vm.deal(user1, ETH_AMOUNT);
        vm.prank(user1);
        coreStable.mint{value: ETH_AMOUNT}();
        
        // Change price to 1000 USD/ETH (increases ETH output)
        uint256 newPrice = 1000e8;
        priceFeed.setPrice(int256(newPrice));
        
        uint256 stableCoinAmount = coreStable.balanceOf(user1);
        uint256 expectedEthAmount = (stableCoinAmount * 1e18) / (newPrice * 1e10);
        
        console.log("BurnWithPriceChangeInsufficient: ExpectedEthAmount:", expectedEthAmount);
        console.log("BurnWithPriceChangeInsufficient: Contract ETH Balance:", address(coreStable).balance);
        
        vm.prank(user1);
        vm.expectRevert("Address: insufficient balance");
        coreStable.burn(stableCoinAmount);
    }
    
    function testMultipleMintAndBurn() public {
        vm.deal(user1, ETH_AMOUNT * 2);
        vm.startPrank(user1);
        
        // First mint
        coreStable.mint{value: ETH_AMOUNT}();
        uint256 firstMintAmount = coreStable.balanceOf(user1);
        console.log("MultipleMintAndBurn: First Mint Amount:", firstMintAmount);
        
        // Second mint
        coreStable.mint{value: ETH_AMOUNT}();
        uint256 totalMintAmount = coreStable.balanceOf(user1);
        console.log("MultipleMintAndBurn: Total Mint Amount:", totalMintAmount);
        
        // Burn half
        uint256 burnAmount = totalMintAmount / 2;
        uint256 expectedEthAmount = (burnAmount * 1e18) / (INITIAL_PRICE * 1e10);
        coreStable.burn(burnAmount);
        
        console.log("MultipleMintAndBurn: Burn Amount:", burnAmount);
        console.log("MultipleMintAndBurn: Remaining Balance:", coreStable.balanceOf(user1));
        
        assertEq(coreStable.balanceOf(user1), totalMintAmount - burnAmount);
        assertEq(address(coreStable).balance, (ETH_AMOUNT * 2) - expectedEthAmount);
        
        vm.stopPrank();
    }
    
    function testUpdatePriceFeed() public {
        MockPriceFeed newPriceFeed = new MockPriceFeed();
        newPriceFeed.setPrice(int256(INITIAL_PRICE));
        
        coreStable.updatePriceFeed(address(newPriceFeed));
        assertEq(coreStable.priceFeedAddress(), address(newPriceFeed));
        assertEq(coreStable.getLatestPrice(), INITIAL_PRICE * 1e10);
    }
    
    function testUpdatePriceFeedInvalidAddress() public {
        vm.expectRevert("Invalid address");
        coreStable.updatePriceFeed(address(0));
    }
    
    function testUpdatePriceFeedNonOwner() public {
        vm.prank(user1);
        vm.expectRevert();
        coreStable.updatePriceFeed(address(0x123));
    }
    
    function testReceiveETH() public {
        vm.deal(user1, ETH_AMOUNT);
        vm.prank(user1);
        vm.expectRevert("Use mint function to deposit ETH");
        (bool sent, ) = address(coreStable).call{value: ETH_AMOUNT}("");
        assertTrue(sent);
    }
    
//     function testUpgradeContract() public {
//     // Deploy a new implementation
//     CoreStable newImplementation = new CoreStable();
    
//     // Perform the upgrade as the owner
//     vm.prank(owner);
//     coreStable.upgradeTo(address(newImplementation));
    
//     // Verify the upgrade was successful
//     // You might need to add a method to check the implementation address
//     // or test functionality that confirms the upgrade worked
// }

// function testUpgradeContractNonOwner() public {
//     // Deploy a new implementation
//     CoreStable newImplementation = new CoreStable();
    
//     // Try to perform the upgrade as non-owner
//     vm.prank(user1);
//     vm.expectRevert("Ownable: caller is not the owner");
//     coreStable.upgradeTo(address(newImplementation));
// }
    
//     function testAuthorizeUpgradeNonOwner() public {
//         CoreStable newImplementation = new CoreStable();
//         vm.prank(user1);
//         vm.expectRevert("Ownable: caller is not the owner");
//         coreStable._authorizeUpgrade(address(newImplementation));
//     }
}