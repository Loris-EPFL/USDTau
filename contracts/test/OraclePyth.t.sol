// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import "src/PriceFeeds/PythVTAOPriceFeed.sol";
import "src/PriceFeeds/PythWTAOPriceFeed.sol";
import "src/PriceFeeds/PythPriceFeedBase.sol";

import "./TestContracts/Accounts.sol";
import "./TestContracts/PythOracleMock.sol";
import "./TestContracts/PythDeployment.t.sol";

import "src/Interfaces/IVTAOPriceFeed.sol";
import "src/Interfaces/ITAOPriceFeed.sol";

import "forge-std/Test.sol";
import "lib/forge-std/src/console2.sol";

contract OraclesPyth is TestAccounts {
    PythOracleMock pythOracle;
    
    IMainnetPriceFeed vtaoPriceFeed;
    ITAOPriceFeed wtaoPriceFeed;

    IERC20Metadata vtaoToken;
    IERC20Metadata wtaoToken;

    PythTestDeployer.LiquityContracts[] contractsArray;
    CollateralRegistryTester collateralRegistry;
    IBoldToken boldToken;

    // Pyth price IDs from TaoFiPriceFeed.sol
    bytes32 constant USDC_PRICE_ID = 0xeaa020c61cc479712813461ce153894a96a6c00b21ed0cfc2798d1f9a9e9c94a;
    bytes32 constant TAO_PRICE_ID = 0x410f41de235f2db824e562ea7ab2d3d3d4ff048316c61d629c0b93f58584e1af;

    struct Vars {
        uint256 numCollaterals;
        uint256 initialColl;
        uint256 price;
        uint256 coll;
        uint256 debtRequest;
        uint256 debt_B;
        uint256 debt_C;
        uint256 debt_D;
        uint256 ICR_A;
        uint256 ICR_B;
        uint256 ICR_C;
        uint256 ICR_D;
        uint256 redemptionICR_A;
        uint256 redemptionICR_B;
        uint256 redemptionICR_C;
        uint256 redemptionICR_D;
        uint256 troveId_A;
        uint256 troveId_B;
        uint256 troveId_C;
        uint256 troveId_D;
        int64 newTaoPrice;
        uint256 systemPrice;
        uint256 newSystemPrice;
        uint256 newSystemRedemptionPrice;
        LatestTroveData troveDataBefore_A;
        LatestTroveData troveDataBefore_B;
        LatestTroveData troveDataBefore_C;
        LatestTroveData troveDataBefore_D;
        LatestTroveData troveDataAfter_A;
        LatestTroveData troveDataAfter_B;
        LatestTroveData troveDataAfter_C;
        LatestTroveData troveDataAfter_D;
    }

    function setUp() public {
        try vm.envString("MAINNET_RPC_URL") returns (string memory rpcUrl) {
            vm.createSelectFork(rpcUrl);
        } catch {
            vm.skip(true);
        }

        Vars memory vars;

        accounts = new Accounts();
        createAccounts();

        (A, B, C, D, E, F) =
            (accountsList[0], accountsList[1], accountsList[2], accountsList[3], accountsList[4], accountsList[5]);

        vars.numCollaterals = 2; // vTAO and WTAO
        PythTestDeployer.TroveManagerParams memory tmParams =
            PythTestDeployer.TroveManagerParams(150e16, 110e16, 10e16, 110e16, 5e16, 10e16);
        PythTestDeployer.TroveManagerParams[] memory troveManagerParamsArray =
            new PythTestDeployer.TroveManagerParams[](vars.numCollaterals);
        for (uint256 i = 0; i < troveManagerParamsArray.length; i++) {
            troveManagerParamsArray[i] = tmParams;
        }

        PythTestDeployer deployer = new PythTestDeployer();
        PythTestDeployer.DeploymentResult memory result =
            deployer.deployAndConnectContractsMainnet(troveManagerParamsArray);
        collateralRegistry = CollateralRegistryTester(address(result.collateralRegistry));
        boldToken = result.boldToken;

        // Initialize Pyth oracle mock
        pythOracle = new PythOracleMock();
        
        // Set up initial price data for TAO
        pythOracle.setPriceData(
            TAO_PRICE_ID,
            500_00000000, // $500 with 8 decimals
            1_00000000,   // $1 confidence
            -8,           // 8 decimal places
            block.timestamp
        );

        // Set up initial price data for USDC
        pythOracle.setPriceData(
            USDC_PRICE_ID,
            1_00000000,   // $1 with 8 decimals
            100000,       // $0.001 confidence
            -8,           // 8 decimal places
            block.timestamp
        );

        // Etch the mock oracle to the Pyth oracle address
        vm.etch(result.externalAddresses.VTAOOracle, address(pythOracle).code);
        vm.etch(result.externalAddresses.WTAOOracle, address(pythOracle).code);

        vtaoToken = IERC20Metadata(result.externalAddresses.VTAOToken);
        wtaoToken = IERC20Metadata(result.externalAddresses.WTAOToken);

        // Record contracts
        for (uint256 c = 0; c < vars.numCollaterals; c++) {
            contractsArray.push(result.contractsArray[c]);
        }

        // Give all users all collaterals
        vars.initialColl = 1000_000e18;
        for (uint256 i = 0; i < 6; i++) {
            for (uint256 j = 0; j < vars.numCollaterals; j++) {
                deal(address(contractsArray[j].collToken), accountsList[i], vars.initialColl);
                vm.startPrank(accountsList[i]);
                contractsArray[j].collToken.approve(address(contractsArray[j].borrowerOperations), type(uint256).max);
                vm.stopPrank();
            }
        }

        vtaoPriceFeed = IMainnetPriceFeed(address(contractsArray[0].priceFeed));
        wtaoPriceFeed = ITAOPriceFeed(address(contractsArray[1].priceFeed));

        // Artificially decay the base rate so we start with a low redemption rate.
        collateralRegistry.setBaseRate(0);
    }

    function _getLatestPriceFromPythOracle(bytes32 _priceId) internal view returns (uint256) {
        PythOracleMock.Price memory priceData = pythOracle.getPriceUnsafe(_priceId);
        
        // Convert to uint and scale to 18 decimals
        uint8 decimals = uint8(uint32(-priceData.expo));
        return uint256(uint64(priceData.price)) * 10 ** (18 - decimals);
    }

    function _getLatestPriceFromTAOOracle() internal view returns (uint256) {
        return _getLatestPriceFromPythOracle(TAO_PRICE_ID);
    }

    function redeem(address _from, uint256 _boldAmount) public {
        vm.startPrank(_from);
        collateralRegistry.redeemCollateral(_boldAmount, MAX_UINT256, 1e18);
        vm.stopPrank();
    }

    function mockVTAOPrice(int64 _price) internal {
        pythOracle.setPriceData(
            TAO_PRICE_ID,
            _price,
            1_00000000,   // $1 confidence
            -8,           // 8 decimal places
            block.timestamp
        );
    }

    function mockWTAOPrice(int64 _price) internal {
        pythOracle.setPriceData(
            TAO_PRICE_ID,
            _price,
            1_00000000,   // $1 confidence
            -8,           // 8 decimal places
            block.timestamp
        );
    }

    function mockVTAOToken() internal {
        // Mock vTAO token behavior if needed
        // For now, we'll use the actual token addresses
    }

    function mockWTAOToken() internal {
        // Mock WTAO token behavior if needed
        // For now, we'll use the actual token addresses
    }

    // Test functions

    function testPythOracleSetup() public {
        // Test that Pyth oracles are properly set up
        uint256 vtaoPrice = vtaoPriceFeed.lastGoodPrice();
        uint256 wtaoPrice = wtaoPriceFeed.lastGoodPrice();
        
        assertGt(vtaoPrice, 0, "vTAO price should be greater than 0");
        assertGt(wtaoPrice, 0, "WTAO price should be greater than 0");
        
        console2.log("vTAO price:", vtaoPrice);
        console2.log("WTAO price:", wtaoPrice);
    }

    function testPythPriceFeedFetch() public {
        // Test fetching prices from Pyth price feeds
        (uint256 vtaoPrice, bool vtaoOracleDown) = vtaoPriceFeed.fetchPrice();
        (uint256 wtaoPrice, bool wtaoOracleDown) = wtaoPriceFeed.fetchPrice();
        
        assertFalse(vtaoOracleDown, "vTAO oracle should not be down");
        assertFalse(wtaoOracleDown, "WTAO oracle should not be down");
        assertGt(vtaoPrice, 0, "vTAO price should be greater than 0");
        assertGt(wtaoPrice, 0, "WTAO price should be greater than 0");
        
        console2.log("Fetched vTAO price:", vtaoPrice);
        console2.log("Fetched WTAO price:", wtaoPrice);
    }

    function testPythPriceUpdate() public {
        // Test updating Pyth oracle prices
        uint256 initialPrice = vtaoPriceFeed.lastGoodPrice();
        
        // Update the price
        mockVTAOPrice(600_00000000); // $600
        
        (uint256 newPrice,) = vtaoPriceFeed.fetchPrice();
        
        assertNotEq(initialPrice, newPrice, "Price should have changed");
        assertEq(newPrice, 600e18, "New price should be $600");
        
        console2.log("Initial price:", initialPrice);
        console2.log("New price:", newPrice);
    }

    function testPythOracleStalePrice() public {
        // Test stale price detection
        // Set a price with old timestamp
        pythOracle.setPriceData(
            TAO_PRICE_ID,
            500_00000000, // $500
            1_00000000,   // $1 confidence
            -8,           // 8 decimal places
            block.timestamp - 25 hours // Make it stale (older than 24 hours)
        );
        
        // This should trigger oracle failure handling
        (uint256 price, bool oracleDown) = vtaoPriceFeed.fetchPrice();
        
        // Depending on implementation, it might use last good price or shut down
        console2.log("Price with stale oracle:", price);
        console2.log("Oracle down:", oracleDown);
    }

    function testOpenTroveWithPythOracle() public {
        // Test opening a trove with Pyth oracle prices
        uint256 collAmount = 10e18; // 10 vTAO
        uint256 debtAmount = 2000e18; // 2000 BOLD
        
        vm.startPrank(A);
        
        uint256 troveId = contractsArray[0].borrowerOperations.openTrove(
            A,
            0, // ownerIndex
            collAmount, // ETH amount
            debtAmount, // Bold amount
            0, // upperHint
            0, // lowerHint
            5e16, // annualInterestRate (5%)
            1000e18, // maxUpfrontFee
            address(0), // addManager
            address(0), // removeManager
            A // receiver
        );
        
        vm.stopPrank();
        
        assertGt(troveId, 0, "Trove should be opened successfully");
        
        // Check trove data
        LatestTroveData memory troveData = contractsArray[0].troveManager.getLatestTroveData(troveId);
        assertEq(troveData.entireColl, collAmount, "Collateral should match");
        assertGt(troveData.entireDebt, debtAmount, "Debt should be greater than requested (includes fees)");
        
        console2.log("Opened trove ID:", troveId);
        console2.log("Trove collateral:", troveData.entireColl);
        console2.log("Trove debt:", troveData.entireDebt);
    }

    function testRedemptionWithPythOracle() public {
        // First, open some troves
        testOpenTroveWithPythOracle();
        
        // Open another trove with user B
        uint256 collAmount = 5e18; // 5 vTAO
        uint256 debtAmount = 1000e18; // 1000 BOLD
        
        vm.startPrank(B);
        
        uint256 troveId_B = contractsArray[0].borrowerOperations.openTrove(
            B,
            0, // ownerIndex
            collAmount, // ETH amount
            debtAmount, // Bold amount
            0, // upperHint
            0, // lowerHint
            5e16, // annualInterestRate (5%)
            1000e18, // maxUpfrontFee
            address(0), // addManager
            address(0), // removeManager
            B // receiver
        );
        
        vm.stopPrank();
        
        // Now test redemption
        uint256 redemptionAmount = 500e18; // Redeem 500 BOLD
        
        vm.startPrank(A);
        uint256 boldBalanceBefore = boldToken.balanceOf(A);
        uint256 collBalanceBefore = vtaoToken.balanceOf(A);
        
        collateralRegistry.redeemCollateral(redemptionAmount, MAX_UINT256, 1e18);
        
        uint256 boldBalanceAfter = boldToken.balanceOf(A);
        uint256 collBalanceAfter = vtaoToken.balanceOf(A);
        
        vm.stopPrank();
        
        assertLt(boldBalanceAfter, boldBalanceBefore, "BOLD balance should decrease");
        assertGt(collBalanceAfter, collBalanceBefore, "Collateral balance should increase");
        
        console2.log("BOLD balance change:", boldBalanceBefore - boldBalanceAfter);
        console2.log("Collateral balance change:", collBalanceAfter - collBalanceBefore);
    }
}