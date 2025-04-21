// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/CoreStable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract CoreStableTest is Test {
    CoreStable public coreStable;
    address public priceFeedAddress = 0x0dF0566e8e3a7e8259e16663972b11910F89BdbE8;
    address public owner = address(this);
    address public user = address(0x1);

    // Mock price feed data
    uint256 constant MOCK_PRICE = 2000 * 1e8; // 2000 USD per ETH (Chainlink 8 decimals)

    function setUp() public {
        // Deploy the implementation contract
        CoreStable implementation = new CoreStable();
        
        // Deploy the proxy and initialize
        coreStable = CoreStable(address(new ERC1967Proxy(address(implementation), "")));
        coreStable.initialize(priceFeedAddress);

        // Mock the price feed behavior
        vm.mockCall(
            priceFeedAddress,
            abi.encodeWithSelector(AggregatorV3Interface.latestRoundData.selector),
            abi.encode(1, int256(MOCK_PRICE), block.timestamp, block.timestamp, 1)
        );

        // Label addresses for better test readability
        vm.label(owner, "Owner");
        vm.label(user, "User");
    }

    function testInitialSetup() public {
        assertEq(coreStable.name(), "CoreStable");
        assertEq(coreStable.symbol(), "CUSD");
        assertEq(coreStable.priceFeedAddress(), priceFeedAddress);
        assertEq(coreStable.owner(), owner);
        assertEq(coreStable.totalSupply(), 0);
    }

    function testMint() public {
        uint256 ethAmount = 1e18; // 1 ETH
        uint256 expectedStableAmount = (ethAmount * MOCK_PRICE * 1e10) / 1e18; // Adjust for 18 decimals

        vm.deal(user, ethAmount);
        vm.prank(user);
        coreStable.mint{value: ethAmount}();

        assertEq(coreStable.balanceOf(user), expectedStableAmount);
        assertEq(address(coreStable).balance, ethAmount);
        assertEq(coreStable.totalSupply(), expectedStableAmount);
    }

    function testBurn() public {
        uint256 ethAmount = 1e18; // 1 ETH
        uint256 stableAmount = (ethAmount * MOCK_PRICE * 1e10) / 1e18;

        vm.deal(user, ethAmount);
        vm.prank(user);
        coreStable.mint{value: ethAmount}();

        vm.prank(user);
        coreStable.burn(stableAmount);

        assertEq(coreStable.balanceOf(user), 0);
        assertEq(address(coreStable).balance, 0);
        assertEq(coreStable.totalSupply(), 0);
    }

    function testGetLatestPrice() public {
        uint256 price = coreStable.getLatestPrice();
        assertGt(price, 0);
        assertEq(price / 1e10, MOCK_PRICE); // Check adjusted price (18 decimals)
    }

    function testUpgradeability() public {
        // Deploy a new implementation
        CoreStable newImplementation = new CoreStable();
        
        // Upgrade the proxy (only owner can call)
        coreStable._authorizeUpgrade(address(newImplementation));
        // Note: In a real scenario, use OpenZeppelin's upgrade plugin or a separate script
        // For testing, we'll simulate the upgrade state
        vm.expectRevert("Unauthorized"); // Ensure only owner can upgrade
        vm.prank(user);
        coreStable._authorizeUpgrade(address(newImplementation));
    }

    function testFailMintWithZeroEth() public {
        vm.prank(user);
        coreStable.mint{value: 0}();
    }

    function testFailBurnWithZeroAmount() public {
        vm.prank(user);
        coreStable.burn(0);
    }

    function testFailBurnInsufficientBalance() public {
        vm.prank(user);
        coreStable.burn(1e18); // No tokens minted yet
    }
}