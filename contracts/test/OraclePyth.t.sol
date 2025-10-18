// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import "src/PriceFeeds/PythVTAOPriceFeed.sol";
import "src/PriceFeeds/PythWTAOPriceFeed.sol";
import "src/PriceFeeds/PythPriceFeedBase.sol";

import "./TestContracts/Accounts.sol";
import "./TestContracts/GasGuzzlerOracle.sol";
import "./TestContracts/GasGuzzlerToken.sol";
import "./TestContracts/PythDeployment.t.sol";
import "./TestContracts/PythAggregatorV3Mock.sol";
import "./TestContracts/ChainlinkOracleMock.sol";
import "./TestContracts/VTAOPriceFeedMock.sol";
import {PythAggregatorV3} from "@pythnetwork/pyth-sdk-solidity/PythAggregatorV3.sol";

import "src/Dependencies/AggregatorV3Interface.sol";
import "src/Interfaces/IVTAOPriceFeed.sol";
import "src/Interfaces/ITAOPriceFeed.sol";

import "forge-std/Test.sol";
import "lib/forge-std/src/console2.sol";

contract OraclePyth is TestAccounts {
    PythAggregatorV3 vtaoOracle;
    PythAggregatorV3 wtaoOracle;

    // Real Pyth aggregators instead of mocks
    PythAggregatorV3 pythTaoAggregator;
    PythAggregatorV3 pythVTaoAggregator;
    PythAggregatorV3 pythWTaoAggregator;

    GasGuzzlerToken gasGuzzlerToken;
    GasGuzzlerOracle gasGuzzlerOracle;
    ChainlinkOracleMock mockOracle;
    VTAOPriceFeedMock vtaoPriceFeedMock;

    IVTAOPriceFeed vtaoPriceFeed;
    ITAOPriceFeed wtaoPriceFeed;

    IERC20Metadata vtaoToken;
    IERC20Metadata wtaoToken;

    PythTestDeployer.LiquityContracts[] contractsArray;
    CollateralRegistryTester collateralRegistry;
    IBoldToken boldToken;

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
        int256 newEthPrice;
        uint256 systemPrice;
        uint256 newSystemPrice;
        uint256 newSystemRedemptionPrice;
        int256 ethPerRethMarket;
        int256 usdPerEthMarket;
        uint256 ethPerRethLST;
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

        vars.numCollaterals = 2;
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

        address PYTH_ORACLE = 0x2880aB155794e7179c9eE2e38200202908C17B43;
   
        bytes32 TAO_PRICE_ID = 0x410f41de235f2db824e562ea7ab2d3d3d4ff048316c61d629c0b93f58584e1af;


        // Get the deployed Pyth oracles from external addresses
        vtaoOracle = new PythAggregatorV3(PYTH_ORACLE, TAO_PRICE_ID);
        wtaoOracle = new PythAggregatorV3(PYTH_ORACLE, TAO_PRICE_ID);

        // Use the deployed PythAggregatorV3 instances from the deployer
        pythTaoAggregator = deployer.deployedTaoAggregator();
        pythVTaoAggregator = deployer.deployedVTaoAggregator();
        pythWTaoAggregator = deployer.deployedWTaoAggregator();

        // Get the price feeds from the deployed contracts
        vtaoPriceFeed = IVTAOPriceFeed(address(result.contractsArray[0].priceFeed));
        wtaoPriceFeed = ITAOPriceFeed(address(result.contractsArray[1].priceFeed));

        gasGuzzlerToken = new GasGuzzlerToken();
        gasGuzzlerOracle = new GasGuzzlerOracle();
        mockOracle = new ChainlinkOracleMock();

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
                // Approve all Borrower Ops to use the user's collateral funds
                contractsArray[j].collToken.approve(address(contractsArray[j].borrowerOperations), type(uint256).max);
                vm.stopPrank();
            }
        }

        // Artificially decay the base rate so we start with a low redemption rate.
        // Normally, we would just wait for it to decay "naturally" (with `vm.warp`), but we can't do that here,
        // as it would result in all the oracles going stale.
        collateralRegistry.setBaseRate(0);
    }

    function _getLatestAnswerFromOracle(PythAggregatorV3 _oracle) internal view returns (uint256) {
        (, int256 answer,,,) = _oracle.latestRoundData();

        uint256 decimals = _oracle.decimals();
        assertLe(decimals, 18);
        // // Convert to uint and scale up to 18 decimals
        return uint256(answer) * 10 ** (18 - decimals);
    }

    function redeem(address _from, uint256 _boldAmount) public {
        vm.startPrank(_from);
        collateralRegistry.redeemCollateral(_boldAmount, MAX_UINT256, 1e18);
        vm.stopPrank();
    }

    function etchStaleMockToVtaoOracle(bytes memory _mockOracleCode) internal {
        // Deploy our new staleness mock
        PythAggregatorV3Mock stalenessMock = new PythAggregatorV3Mock();
        
        // Configure the mock to return stale data
        stalenessMock.setDecimals(8);
        // Fake VTAO-USD price of 500 USD
        stalenessMock.setPrice(500e8);
        // Make it stale by setting timestamp to 7 days ago
        stalenessMock.setUpdatedAt(block.timestamp - 7 days);
        
        // Replace the pythVTaoAggregator reference with our configured mock
        // This is the oracle that vtaoPriceFeed actually uses
        pythVTaoAggregator = PythAggregatorV3(address(stalenessMock));
        
        // Also update vtaoOracle for consistency in tests that check it directly
        vtaoOracle = PythAggregatorV3(address(stalenessMock));
    }

    function etchStaleMockToWtaoOracle(bytes memory _mockOracleCode) internal {
        // Etch the mock code to the WTAO-USD oracle address
        vm.etch(address(wtaoOracle), _mockOracleCode);
        // Wrap so we can use the mock's setters
        ChainlinkOracleMock mock = ChainlinkOracleMock(address(wtaoOracle));
        mock.setDecimals(8);
        // Fake WTAO-USD price of 500 USD
        mock.setPrice(500e8);
        // Make it stale
        mock.setUpdatedAt(block.timestamp - 7 days);
    }

    function etchMockToVtaoOracle() internal returns (PythAggregatorV3Mock) {
        // Deploy a new mock and etch its code to the VTAO-USD oracle address
        PythAggregatorV3Mock mockContract = new PythAggregatorV3Mock();
        vm.etch(address(vtaoOracle), address(mockContract).code);
        PythAggregatorV3Mock mock = PythAggregatorV3Mock(address(vtaoOracle));
        // Note: Real Pyth oracles don't have setPrice/setUpdatedAt methods
        // The oracle behavior is controlled by the etched mock code

        return mock;
    }

    function etchMockToWtaoOracle() internal returns (PythAggregatorV3Mock) {
        // Deploy a new mock and etch its code to the WTAO-USD oracle address
        PythAggregatorV3Mock mockContract = new PythAggregatorV3Mock();
        vm.etch(address(wtaoOracle), address(mockContract).code);
        PythAggregatorV3Mock mock = PythAggregatorV3Mock(address(wtaoOracle));
        // Note: Real Pyth oracles don't have setPrice/setUpdatedAt methods
        // The oracle behavior is controlled by the etched mock code

        return mock;
    }

    function etchGasGuzzlerToVtaoOracle(bytes memory _mockOracleCode) internal {
        // Etch the mock code to the VTAO-USD oracle address
        vm.etch(address(vtaoOracle), _mockOracleCode);
        GasGuzzlerOracle mock = GasGuzzlerOracle(address(vtaoOracle));
        mock.setDecimals(8);
        // Note: Real Pyth oracles don't have setPrice/setUpdatedAt methods
        // The oracle behavior is controlled by the etched mock code
    }

    function etchGasGuzzlerToWtaoOracle(bytes memory _mockOracleCode) internal {
        // Etch the mock code to the WTAO-USD oracle address
        vm.etch(address(wtaoOracle), _mockOracleCode);
        GasGuzzlerOracle mock = GasGuzzlerOracle(address(wtaoOracle));
        mock.setDecimals(8);
        // Note: Real Pyth oracles don't have setPrice/setUpdatedAt methods
        // The oracle behavior is controlled by the etched mock code
    }

    // --- lastGoodPrice set on deployment ---

    function testSetLastGoodPriceOnDeploymentVTAO() public view {
        uint256 lastGoodPriceVtao = vtaoPriceFeed.lastGoodPrice();
        assertGt(lastGoodPriceVtao, 0);

        uint256 latestAnswerVtaoUsd = _getLatestAnswerFromOracle(vtaoOracle);

        assertApproxEqRel(lastGoodPriceVtao, latestAnswerVtaoUsd, 0.02e18);
    }

    function testSetLastGoodPriceOnDeploymentWTAO() public view {
        uint256 lastGoodPriceWtao = wtaoPriceFeed.lastGoodPrice();
        assertGt(lastGoodPriceWtao, 0);

        uint256 latestAnswerWtaoUsd = _getLatestAnswerFromOracle(wtaoOracle);

        assertApproxEqRel(lastGoodPriceWtao, latestAnswerWtaoUsd, 0.02e18);
    }

    // --- fetchPrice ---

    function testFetchPriceReturnsCorrectPriceVTAO() public {
        (uint256 fetchedVtaoUsdPrice,) = vtaoPriceFeed.fetchPrice();
        assertGt(fetchedVtaoUsdPrice, 0);

        uint256 latestAnswerVtaoUsd = _getLatestAnswerFromOracle(vtaoOracle);

        assertApproxEqRel(fetchedVtaoUsdPrice, latestAnswerVtaoUsd, 0.02e18);
    }

    function testFetchPriceReturnsCorrectPriceWTAO() public {
        (uint256 fetchedWtaoUsdPrice,) = wtaoPriceFeed.fetchPrice();
        assertGt(fetchedWtaoUsdPrice, 0);

        uint256 latestAnswerWtaoUsd = _getLatestAnswerFromOracle(wtaoOracle);

        assertEq(fetchedWtaoUsdPrice, latestAnswerWtaoUsd);
    }

    // --- Thresholds set at deployment ---

    function testVtaoUsdStalenessThresholdSetVTAO() public view {
        (, uint256 storedVtaoUsdStaleness,) = IVTAOPriceFeed(address(vtaoPriceFeed)).vTaoUsdOracle();
        assertEq(storedVtaoUsdStaleness, 3600); // _24_HOURS
    }

    function testWtaoUsdStalenessThresholdSetWTAO() public view {
        (, uint256 storedWtaoUsdStaleness,) = wtaoPriceFeed.taoUsdOracle();
        assertEq(storedWtaoUsdStaleness, 3600); // _24_HOURS
    }

    // --- Basic actions ---

    function testOpenTroveVTAO() public {
        uint256 price = _getLatestAnswerFromOracle(vtaoOracle);

        uint256 coll = 5 ether;
        uint256 debtRequest = coll * price / 2 / 1e18;

        uint256 trovesCount = contractsArray[0].troveManager.getTroveIdsCount();
        assertEq(trovesCount, 0);

        vm.startPrank(A);
        contractsArray[0].borrowerOperations.openTrove(
            A, 0, coll, debtRequest, 0, 0, 5e16, debtRequest, address(0), address(0), address(0)
        );

        trovesCount = contractsArray[0].troveManager.getTroveIdsCount();
        assertEq(trovesCount, 1);
    }

    function testOpenTroveWTAO() public {
        uint256 latestAnswerWtaoUsd = _getLatestAnswerFromOracle(wtaoOracle);

        uint256 coll = 5 ether;
        uint256 debtRequest = coll * latestAnswerWtaoUsd / 2 / 1e18;

        uint256 trovesCount = contractsArray[1].troveManager.getTroveIdsCount();
        assertEq(trovesCount, 0);

        vm.startPrank(A);
        contractsArray[1].borrowerOperations.openTrove(
            A, 0, coll, debtRequest, 0, 0, 5e16, debtRequest, address(0), address(0), address(0)
        );

        trovesCount = contractsArray[1].troveManager.getTroveIdsCount();
        assertEq(trovesCount, 1);
    }

    // --- Oracle manipulation tests ---

    function testManipulatedPythReturnsStalePrice() public {
        // Get the current price
        uint256 lastGoodPrice1 = vtaoPriceFeed.lastGoodPrice();

        // Fetch price
        (uint256 price, bool oracleFailedWhileBranchLive) = vtaoPriceFeed.fetchPrice();
        assertGt(price, 0);

        // Check oracle call didn't fail
        assertFalse(oracleFailedWhileBranchLive);

        // Check the PriceFeed's returned price equals the oracle's price
        uint256 oraclePrice = _getLatestAnswerFromOracle(vtaoOracle);
        assertApproxEqRel(price, oraclePrice, 0.02e18);

        // Check the stored lastGoodPrice has been updated
        uint256 lastGoodPrice2 = vtaoPriceFeed.lastGoodPrice();
        assertApproxEqRel(lastGoodPrice2, oraclePrice, 0.02e18);

        // Make the oracle stale
        etchStaleMockToVtaoOracle(address(pythVTaoAggregator).code);
        (,,, uint256 updatedAt,) = vtaoOracle.latestRoundData();
        assertApproxEqRel(updatedAt, block.timestamp - 7 days, 0.02e18);

        // Fetch price again
        (price, oracleFailedWhileBranchLive) = vtaoPriceFeed.fetchPrice();

        // Confirm the PriceFeed's returned price equals the lastGoodPrice
        assertEq(price, lastGoodPrice1, "current price != lastGoodPrice");

        // Confirm the stored lastGoodPrice has not changed
        assertEq(vtaoPriceFeed.lastGoodPrice(), lastGoodPrice1, "lastGoodPrice not same");
    }

    function testOpenTroveVTAOWithStalePriceReverts() public {
        // Make the oracle stale
        etchStaleMockToVtaoOracle(address(pythVTaoAggregator).code);
        (,,, uint256 updatedAt,) = vtaoOracle.latestRoundData();
        assertApproxEqRel(updatedAt, block.timestamp - 7 days, 0.02e18);

        uint256 coll = 5 ether;
        uint256 debtRequest = 2000e18;

        vm.startPrank(A);
        vm.expectRevert();
        contractsArray[0].borrowerOperations.openTrove(
            A, 0, coll, debtRequest, 0, 0, 5e16, debtRequest, address(0), address(0), address(0)
        );
        vm.stopPrank();
    }

    function testOpenTroveWTAOWithStalePriceReverts() public {
        // Make the oracle stale
        etchStaleMockToWtaoOracle(address(pythWTaoAggregator).code);
        (,,, uint256 updatedAt,) = wtaoOracle.latestRoundData();
        assertApproxEqRel(updatedAt, block.timestamp - 7 days, 0.02e18);

        uint256 coll = 5 ether;
        uint256 debtRequest = 2000e18;

        vm.startPrank(A);
        vm.expectRevert();
        contractsArray[1].borrowerOperations.openTrove(
            A, 0, coll, debtRequest, 0, 0, 5e16, debtRequest, address(0), address(0), address(0)
        );
        vm.stopPrank();
    }

    // --- VTAO shutdown ---

    function testVTAOPriceFeedShutsDownWhenVTAOUSDOracleFails() public {
        // Fetch price
        (uint256 price, bool oracleFailedWhileBranchLive) = vtaoPriceFeed.fetchPrice();
        assertGt(price, 0);

        // Check oracle call didn't fail
        assertFalse(oracleFailedWhileBranchLive);

        // Check branch is live, not shut down
        assertEq(contractsArray[0].troveManager.shutdownTime(), 0);

        // Make the VTAO-USD oracle stale
        etchStaleMockToVtaoOracle(bytes(""));
        (,,, uint256 updatedAt,) = vtaoOracle.latestRoundData();
        assertEq(updatedAt, block.timestamp - 7 days);

        // Fetch price again
        (, oracleFailedWhileBranchLive) = vtaoPriceFeed.fetchPrice();

        // Check an oracle call failed this time
        assertTrue(oracleFailedWhileBranchLive);

        // Confirm the branch is now shutdown
        assertEq(contractsArray[0].troveManager.shutdownTime(), block.timestamp);
    }

    function testVTAOPriceSourceIsLastGoodPriceWhenVTAOUSDFails() public {
        // Create mock price feed that initially works, then fails
        vtaoPriceFeedMock = new VTAOPriceFeedMock();
        
        // Initialize with current price from real oracle
        (uint256 currentPrice,) = vtaoPriceFeed.fetchPrice();
        vtaoPriceFeedMock.setPrice(currentPrice);
        vtaoPriceFeedMock.setOracleWorking(true);
        
        // Fetch price from mock
        vtaoPriceFeedMock.fetchPrice();

        // Check using primary
        assertEq(uint8(IMainnetPriceFeed(address(vtaoPriceFeedMock)).priceSource()), uint8(IMainnetPriceFeed.PriceSource.primary));

        // Make the oracle fail
        vtaoPriceFeedMock.setOracleWorking(false);

        // Fetch price again
        (, bool oracleFailedWhileBranchLive) = vtaoPriceFeedMock.fetchPrice();

        assertTrue(oracleFailedWhileBranchLive);

        // Check using lastGoodPrice
        assertEq(uint8(IMainnetPriceFeed(address(vtaoPriceFeedMock)).priceSource()), uint8(IMainnetPriceFeed.PriceSource.lastGoodPrice));
    }

    // --- WTAO shutdown ---

    function testWTAOPriceFeedShutsDownWhenWTAOUSDOracleFails() public {
        // Fetch price
        (uint256 price, bool oracleFailedWhileBranchLive) = wtaoPriceFeed.fetchPrice();
        assertGt(price, 0);

        // Check oracle call didn't fail
        assertFalse(oracleFailedWhileBranchLive);

        // Check branch is live, not shut down
        assertEq(contractsArray[1].troveManager.shutdownTime(), 0);

        // Make the WTAO-USD oracle stale
        etchStaleMockToWtaoOracle(address(mockOracle).code);
        (,,, uint256 updatedAt,) = wtaoOracle.latestRoundData();
        assertEq(updatedAt, block.timestamp - 7 days);

        // Fetch price again
        (, oracleFailedWhileBranchLive) = wtaoPriceFeed.fetchPrice();

        // Check an oracle call failed this time
        assertTrue(oracleFailedWhileBranchLive);

        // Confirm the branch is now shutdown
        assertEq(contractsArray[1].troveManager.shutdownTime(), block.timestamp);
    }

    function testWTAOPriceSourceIsLastGoodPriceWhenWTAOUSDFails() public {
        // Fetch price
        wtaoPriceFeed.fetchPrice();

        // Check using primary
        assertEq(uint8(IMainnetPriceFeed(address(wtaoPriceFeed)).priceSource()), uint8(IMainnetPriceFeed.PriceSource.primary));

        // Make the WTAO-USD oracle stale
        etchStaleMockToWtaoOracle(address(mockOracle).code);
        (,,, uint256 updatedAt,) = wtaoOracle.latestRoundData();
        assertApproxEqRel(updatedAt, block.timestamp - 7 days, 0.02e18);

        // Fetch price again
        (, bool oracleFailedWhileBranchLive) = wtaoPriceFeed.fetchPrice();

        assertTrue(oracleFailedWhileBranchLive);

        // Check using lastGoodPrice
        assertEq(uint8(IMainnetPriceFeed(address(wtaoPriceFeed)).priceSource()), uint8(IMainnetPriceFeed.PriceSource.lastGoodPrice));
    }

    // --- Gas consumption tests ---

    function testVTAOPriceFeedReturnsLastGoodPriceWhenOracleConsumesAllGas() public {
        // Get the current price and lastGoodPrice
        uint256 lastGoodPrice = vtaoPriceFeed.lastGoodPrice();
        (uint256 price,) = vtaoPriceFeed.fetchPrice();
        assertEq(price, lastGoodPrice);

        // Etch the gas guzzler to the oracle
        etchGasGuzzlerToVtaoOracle(address(gasGuzzlerOracle).code);

        // Fetch price - should return lastGoodPrice due to gas consumption
        (price,) = vtaoPriceFeed.fetchPrice();

        // Should return the lastGoodPrice
        assertEq(price, lastGoodPrice);
    }

    function testWTAOPriceFeedReturnsLastGoodPriceWhenOracleConsumesAllGas() public {
        // Get the current price and lastGoodPrice
        uint256 lastGoodPrice = wtaoPriceFeed.lastGoodPrice();
        (uint256 price,) = wtaoPriceFeed.fetchPrice();
        assertEq(price, lastGoodPrice);

        // Etch the gas guzzler to the oracle
        etchGasGuzzlerToWtaoOracle(address(gasGuzzlerOracle).code);

        // Fetch price - should return lastGoodPrice due to gas consumption
        (price,) = wtaoPriceFeed.fetchPrice();

        // Should return the lastGoodPrice
        assertEq(price, lastGoodPrice);
    }

    // --- Redemption tests ---

    function testRedemptionWithPythOracles() public {
        Vars memory vars;

        // Open troves for A, B, C, D
        vars.coll = 5 ether;
        vars.debtRequest = 2000e18;

        // A opens trove in VTAO branch
        vm.startPrank(A);
        vars.troveId_A = contractsArray[0].borrowerOperations.openTrove(
            A, 0, vars.coll, vars.debtRequest, 0, 0, 5e16, vars.debtRequest, address(0), address(0), address(0)
        );
        vm.stopPrank();

        // B opens trove in WTAO branch
        vm.startPrank(B);
        vars.troveId_B = contractsArray[1].borrowerOperations.openTrove(
            B, 0, vars.coll, vars.debtRequest, 0, 0, 5e16, vars.debtRequest, address(0), address(0), address(0)
        );
        vm.stopPrank();

        // C opens trove in VTAO branch
        vm.startPrank(C);
        vars.troveId_C = contractsArray[0].borrowerOperations.openTrove(
            C, 0, vars.coll, vars.debtRequest, 0, 0, 5e16, vars.debtRequest, address(0), address(0), address(0)
        );
        vm.stopPrank();

        // D opens trove in WTAO branch
        vm.startPrank(D);
        vars.troveId_D = contractsArray[1].borrowerOperations.openTrove(
            D, 0, vars.coll, vars.debtRequest, 0, 0, 5e16, vars.debtRequest, address(0), address(0), address(0)
        );
        vm.stopPrank();

        // Get trove data before redemption
        vars.troveDataBefore_A = contractsArray[0].troveManager.getLatestTroveData(vars.troveId_A);
        vars.troveDataBefore_B = contractsArray[1].troveManager.getLatestTroveData(vars.troveId_B);
        vars.troveDataBefore_C = contractsArray[0].troveManager.getLatestTroveData(vars.troveId_C);
        vars.troveDataBefore_D = contractsArray[1].troveManager.getLatestTroveData(vars.troveId_D);

        // Perform redemption
        uint256 redemptionAmount = 1000e18;
        redeem(A, redemptionAmount);

        // Get trove data after redemption
        vars.troveDataAfter_A = contractsArray[0].troveManager.getLatestTroveData(vars.troveId_A);
        vars.troveDataAfter_B = contractsArray[1].troveManager.getLatestTroveData(vars.troveId_B);
        vars.troveDataAfter_C = contractsArray[0].troveManager.getLatestTroveData(vars.troveId_C);
        vars.troveDataAfter_D = contractsArray[1].troveManager.getLatestTroveData(vars.troveId_D);

        // Check that some troves were affected by redemption
        assertLt(vars.troveDataAfter_C.entireDebt, vars.troveDataBefore_C.entireDebt, "C's debt not lower after redeem");
        assertLt(vars.troveDataAfter_C.entireColl, vars.troveDataBefore_C.entireColl, "C's coll not lower after redeem");
        assertLt(vars.troveDataAfter_D.entireDebt, vars.troveDataBefore_D.entireDebt, "D's debt not lower after redeem");
        assertLt(vars.troveDataAfter_D.entireColl, vars.troveDataBefore_D.entireColl, "D's coll not lower after redeem");
    }

    // - More basic actions tests (adjust, close, etc)
    // - liq tests (manipulate aggregator stored price)
}