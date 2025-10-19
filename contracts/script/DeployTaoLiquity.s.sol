// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Script.sol";
import "forge-std/console2.sol";

// Core Liquity contracts
import {BorrowerOperations} from "src/BorrowerOperations.sol";
import {TroveManager} from "src/TroveManager.sol";
import {ActivePool} from "src/ActivePool.sol";
import {StabilityPool} from "src/StabilityPool.sol";
import {DefaultPool} from "src/DefaultPool.sol";
import {CollSurplusPool} from "src/CollSurplusPool.sol";
import {SortedTroves} from "src/SortedTroves.sol";
import {GasPool} from "src/GasPool.sol";
import {BoldToken} from "src/BoldToken.sol";
import {CollateralRegistry} from "src/CollateralRegistry.sol";
import {TroveNFT} from "src/TroveNFT.sol";
import {AddressesRegistry} from "src/AddressesRegistry.sol";
import {MetadataNFT, IMetadataNFT} from "src/NFTMetadata/MetadataNFT.sol";
import {FixedAssetReader} from "src/NFTMetadata/utils/FixedAssets.sol";

// Price feeds
import {PythWTAOPriceFeed} from "src/PriceFeeds/PythWTAOPriceFeed.sol";

// Pyth oracle wrapper
import {PythAggregatorV3} from "@pythnetwork/pyth-sdk-solidity/PythAggregatorV3.sol";

// Interfaces
import {IERC20Metadata} from "openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IWETH} from "src/Interfaces/IWETH.sol";
import {IPriceFeed} from "src/Interfaces/IPriceFeed.sol";
import {IAddressesRegistry} from "src/Interfaces/IAddressesRegistry.sol";
import {IInterestRouter} from "src/Interfaces/IInterestRouter.sol";
import {IBorrowerOperations} from "src/Interfaces/IBorrowerOperations.sol";
import {ITroveManager} from "src/Interfaces/ITroveManager.sol";
import {ITroveNFT} from "src/Interfaces/ITroveNFT.sol";
import {IStabilityPool} from "src/Interfaces/IStabilityPool.sol";
import {IActivePool} from "src/Interfaces/IActivePool.sol";
import {IDefaultPool} from "src/Interfaces/IDefaultPool.sol";
import {ICollSurplusPool} from "src/Interfaces/ICollSurplusPool.sol";
import {ISortedTroves} from "src/Interfaces/ISortedTroves.sol";
import {IHintHelpers} from "src/Interfaces/IHintHelpers.sol";
import {IMultiTroveGetter} from "src/Interfaces/IMultiTroveGetter.sol";
import {ICollateralRegistry} from "src/Interfaces/ICollateralRegistry.sol";
import {IBoldToken} from "src/Interfaces/IBoldToken.sol";

// Test contracts
import {MockInterestRouter} from "test/TestContracts/MockInterestRouter.sol";

// Uniswap V3 interfaces
import {IUniswapV3Factory} from "src/Zappers/Modules/Exchanges/UniswapV3/IUniswapV3Factory.sol";
import {IUniswapV3Pool} from "src/Zappers/Modules/Exchanges/UniswapV3/IUniswapV3Pool.sol";

contract DeployTaoLiquity is Script {
    // Deployment configuration
    uint256 constant CCR = 1.5e18; // 150%
    uint256 constant MCR = 1.1e18; // 110%
    uint256 constant BCR = 1e17; // 10% - Bootstrap Collateral Ratio
    uint256 constant SCR = 1.3e18; // 130% - System Collateral Ratio
    uint256 constant LIQUIDATION_PENALTY_SP = 0.05e18; // 5%
    uint256 constant LIQUIDATION_PENALTY_REDISTRIBUTION = 0.05e18; // 5%
    uint256 constant MIN_DEBT = 2000e18; // 2000 Bold
    uint256 constant INTEREST_RATE_IN_BPS = 500; // 5%
    uint256 constant MAX_DEBT = 1e24; // 1M Bold
    uint256 constant BOOTSTRAP_PERIOD = 14 days;
    uint256 constant REDEMPTION_FEE_FLOOR = 0.005e18; // 0.5%
    uint256 constant MIN_ANNUAL_INTEREST_RATE = 0.005e18; // 0.5%
    uint256 constant MAX_ANNUAL_INTEREST_RATE = 0.75e18; // 75%

    // Network-specific addresses
    address constant PYTH_ORACLE = 0x2880aB155794e7179c9eE2e38200202908C17B43;
    address constant WETH_ADDRESS = 0x9Dc08C6e2BF0F1eeD1E00670f80Df39145529F81;
    address constant VTAO_ADDRESS = 0x31049849CCdD983D8F401077537438eaF12B12Af;
    address constant WTAO_ADDRESS = 0x9Dc08C6e2BF0F1eeD1E00670f80Df39145529F81;
    
    // Pyth price feed IDs
    bytes32 constant VTAO_PRICE_FEED_ID = 0x410f41de235f2db824e562ea7ab2d3d3d4ff048316c61d629c0b93f58584e1af;
    bytes32 constant WTAO_PRICE_FEED_ID = 0x410f41de235f2db824e562ea7ab2d3d3d4ff048316c61d629c0b93f58584e1af;

    // Uniswap V3 configuration
    address constant UNISWAP_V3_FACTORY = 0x20D0Cdf9004bf56BCa52A25C9288AAd0EbB97D59;
    uint24 constant POOL_FEE = 3000; // 0.3%

    // CREATE2 salt for deterministic addresses
    bytes32 constant SALT = keccak256("TaoLiquity");

    PythAggregatorV3 public deployedWTaoAggregator;

    struct LiquityContracts {
        BoldToken boldToken;
        AddressesRegistry addressesRegistry;
        BorrowerOperations borrowerOperations;
        TroveManager troveManager;
        TroveNFT troveNFT;
        StabilityPool stabilityPool;
        ActivePool activePool;
        DefaultPool defaultPool;
        CollSurplusPool collSurplusPool;
        SortedTroves sortedTroves;
        GasPool gasPool;
        PythWTAOPriceFeed priceFeed;
        MockInterestRouter interestRouter;
    }

    struct PreminedAddresses {
        address addressesRegistry;
        address boldToken;
        address borrowerOperations;
        address troveManager;
        address troveNFT;
        address stabilityPool;
        address activePool;
        address defaultPool;
        address collSurplusPool;
        address sortedTroves;
        address gasPool;
        address priceFeed;
        address interestRouter;
    }

    function run() external {
        // uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(); 

        deployedWTaoAggregator = new PythAggregatorV3(
            PYTH_ORACLE, // Pyth contract address
            WTAO_PRICE_FEED_ID // TAO price ID
        );


        console2.log("Deploying Tao Liquity contracts...");
        // console2.log("Deployer address:", vm.addr(deployerPrivateKey));

        LiquityContracts memory contracts = _deployAndConnectContracts();

        console2.log("=== Deployment Summary ===");
        console2.log("BoldToken:", address(contracts.boldToken));
        console2.log("AddressesRegistry:", address(contracts.addressesRegistry));
        console2.log("BorrowerOperations:", address(contracts.borrowerOperations));
        console2.log("TroveManager:", address(contracts.troveManager));
        console2.log("TroveNFT:", address(contracts.troveNFT));
        console2.log("StabilityPool:", address(contracts.stabilityPool));
        console2.log("ActivePool:", address(contracts.activePool));
        console2.log("DefaultPool:", address(contracts.defaultPool));
        console2.log("CollSurplusPool:", address(contracts.collSurplusPool));
        console2.log("SortedTroves:", address(contracts.sortedTroves));
        console2.log("GasPool:", address(contracts.gasPool));
        console2.log("PriceFeed:", address(contracts.priceFeed));
        console2.log("InterestRouter:", address(contracts.interestRouter));

        vm.stopBroadcast();
    }
    
    function _deployAndConnectContracts() internal returns (LiquityContracts memory contracts) {
        // Step 1: Premine all contract addresses using CREATE2
        PreminedAddresses memory addresses = _premineAddresses();
        
        // Step 2: Deploy AddressesRegistry first
         contracts.addressesRegistry = new AddressesRegistry{salt: SALT}(
             msg.sender, // owner
             CCR,
             MCR,
             BCR, // BCR - Bootstrap Collateral Ratio
             SCR, // SCR - System Collateral Ratio  
             LIQUIDATION_PENALTY_SP,
             LIQUIDATION_PENALTY_REDISTRIBUTION
         );
         require(address(contracts.addressesRegistry) == addresses.addressesRegistry, "AddressesRegistry address mismatch");
         
         // Step 3: Populate the registry with premined addresses BEFORE deploying other contracts
         _populateAddressesRegistry(contracts.addressesRegistry, addresses);
         
         // Step 4: Deploy all contracts to their predetermined addresses
        contracts.boldToken = new BoldToken{salt: SALT}(msg.sender);
        require(address(contracts.boldToken) == addresses.boldToken, "BoldToken address mismatch");
        
        contracts.borrowerOperations = new BorrowerOperations{salt: SALT}(contracts.addressesRegistry);
        require(address(contracts.borrowerOperations) == addresses.borrowerOperations, "BorrowerOperations address mismatch");
        
        contracts.troveManager = new TroveManager{salt: SALT}(contracts.addressesRegistry);
        require(address(contracts.troveManager) == addresses.troveManager, "TroveManager address mismatch");
        
        contracts.troveNFT = new TroveNFT{salt: SALT}(contracts.addressesRegistry);
        require(address(contracts.troveNFT) == addresses.troveNFT, "TroveNFT address mismatch");
        
        contracts.stabilityPool = new StabilityPool{salt: SALT}(contracts.addressesRegistry);
        require(address(contracts.stabilityPool) == addresses.stabilityPool, "StabilityPool address mismatch");
        
        contracts.activePool = new ActivePool{salt: SALT}(contracts.addressesRegistry);
        require(address(contracts.activePool) == addresses.activePool, "ActivePool address mismatch");
        
        contracts.defaultPool = new DefaultPool{salt: SALT}(contracts.addressesRegistry);
        require(address(contracts.defaultPool) == addresses.defaultPool, "DefaultPool address mismatch");
        
        contracts.collSurplusPool = new CollSurplusPool{salt: SALT}(contracts.addressesRegistry);
        require(address(contracts.collSurplusPool) == addresses.collSurplusPool, "CollSurplusPool address mismatch");
        
        contracts.sortedTroves = new SortedTroves{salt: SALT}(contracts.addressesRegistry);
        require(address(contracts.sortedTroves) == addresses.sortedTroves, "SortedTroves address mismatch");
        
        contracts.gasPool = new GasPool{salt: SALT}(contracts.addressesRegistry);
        require(address(contracts.gasPool) == addresses.gasPool, "GasPool address mismatch");

        console.log("deploying pyth price feed");
        
        contracts.priceFeed = new PythWTAOPriceFeed{salt: SALT}(
            address(deployedWTaoAggregator),
            3600, // 24 hours staleness threshold
            addresses.borrowerOperations // Use pre-mined address
        );
        require(address(contracts.priceFeed) == addresses.priceFeed, "PriceFeed address mismatch");
        
        contracts.interestRouter = new MockInterestRouter{salt: SALT}();
        require(address(contracts.interestRouter) == addresses.interestRouter, "InterestRouter address mismatch");
        
        console2.log("All contracts deployed successfully with CREATE2 addresses");
        
        return contracts;
    }

    function _premineAddresses() internal view returns (PreminedAddresses memory addresses) {
        // First, calculate the AddressesRegistry address using CREATE2
        bytes memory registryBytecode = abi.encodePacked(
            type(AddressesRegistry).creationCode,
            abi.encode(
                msg.sender, // owner
                CCR,
                MCR,
                BCR, // BCR - Bootstrap Collateral Ratio
                SCR, // SCR - System Collateral Ratio  
                LIQUIDATION_PENALTY_SP,
                LIQUIDATION_PENALTY_REDISTRIBUTION
            )
        );
        address registryAddress = vm.computeCreate2Address(SALT, keccak256(registryBytecode));
        
        // Get creation code for each contract
        bytes memory boldTokenBytecode = abi.encodePacked(
            type(BoldToken).creationCode,
            abi.encode(msg.sender) // owner parameter for constructor
        );
        bytes memory borrowerOpsBytecode = abi.encodePacked(
            type(BorrowerOperations).creationCode,
            abi.encode(registryAddress) // calculated addressesRegistry
        );
        bytes memory troveManagerBytecode = abi.encodePacked(
            type(TroveManager).creationCode,
            abi.encode(registryAddress) // calculated addressesRegistry
        );
        bytes memory troveNFTBytecode = abi.encodePacked(
            type(TroveNFT).creationCode,
            abi.encode(registryAddress) // calculated addressesRegistry
        );
        bytes memory stabilityPoolBytecode = abi.encodePacked(
            type(StabilityPool).creationCode,
            abi.encode(registryAddress) // calculated addressesRegistry
        );
        bytes memory activePoolBytecode = abi.encodePacked(
            type(ActivePool).creationCode,
            abi.encode(registryAddress) // calculated addressesRegistry
        );
        bytes memory defaultPoolBytecode = abi.encodePacked(
            type(DefaultPool).creationCode,
            abi.encode(registryAddress) // calculated addressesRegistry
        );
        bytes memory collSurplusPoolBytecode = abi.encodePacked(
            type(CollSurplusPool).creationCode,
            abi.encode(registryAddress) // calculated addressesRegistry
        );
        bytes memory sortedTrovesBytecode = abi.encodePacked(
            type(SortedTroves).creationCode,
            abi.encode(registryAddress) // calculated addressesRegistry
        );
        bytes memory gasPoolBytecode = abi.encodePacked(
            type(GasPool).creationCode,
            abi.encode(registryAddress) // calculated addressesRegistry
        );
        bytes memory priceFeedBytecode = abi.encodePacked(
            type(PythWTAOPriceFeed).creationCode,
            abi.encode(address(deployedWTaoAggregator), 3600, vm.computeCreate2Address(SALT, keccak256(borrowerOpsBytecode)))
        );
        bytes memory interestRouterBytecode = type(MockInterestRouter).creationCode;

        // Compute CREATE2 addresses
        addresses.addressesRegistry = registryAddress;
        addresses.boldToken = vm.computeCreate2Address(SALT, keccak256(boldTokenBytecode));
        addresses.borrowerOperations = vm.computeCreate2Address(SALT, keccak256(borrowerOpsBytecode));
        addresses.troveManager = vm.computeCreate2Address(SALT, keccak256(troveManagerBytecode));
        addresses.troveNFT = vm.computeCreate2Address(SALT, keccak256(troveNFTBytecode));
        addresses.stabilityPool = vm.computeCreate2Address(SALT, keccak256(stabilityPoolBytecode));
        addresses.activePool = vm.computeCreate2Address(SALT, keccak256(activePoolBytecode));
        addresses.defaultPool = vm.computeCreate2Address(SALT, keccak256(defaultPoolBytecode));
        addresses.collSurplusPool = vm.computeCreate2Address(SALT, keccak256(collSurplusPoolBytecode));
        addresses.sortedTroves = vm.computeCreate2Address(SALT, keccak256(sortedTrovesBytecode));
        addresses.gasPool = vm.computeCreate2Address(SALT, keccak256(gasPoolBytecode));
        addresses.priceFeed = vm.computeCreate2Address(SALT, keccak256(priceFeedBytecode));
        addresses.interestRouter = vm.computeCreate2Address(SALT, keccak256(interestRouterBytecode));

        return addresses;
    }

    function _populateAddressesRegistry(AddressesRegistry registry, PreminedAddresses memory addresses) internal {
        // Set all addresses in the registry using the correct AddressVars struct
        IAddressesRegistry.AddressVars memory addressVars = IAddressesRegistry.AddressVars({
            collToken: IERC20Metadata(VTAO_ADDRESS),
            borrowerOperations: IBorrowerOperations(addresses.borrowerOperations),
            troveManager: ITroveManager(addresses.troveManager),
            troveNFT: ITroveNFT(addresses.troveNFT),
            metadataNFT: IMetadataNFT(address(0)), // Not used in this deployment
            stabilityPool: IStabilityPool(addresses.stabilityPool),
            priceFeed: IPriceFeed(addresses.priceFeed),
            activePool: IActivePool(addresses.activePool),
            defaultPool: IDefaultPool(addresses.defaultPool),
            gasPoolAddress: addresses.gasPool,
            collSurplusPool: ICollSurplusPool(addresses.collSurplusPool),
            sortedTroves: ISortedTroves(addresses.sortedTroves),
            interestRouter: IInterestRouter(addresses.interestRouter),
            hintHelpers: IHintHelpers(address(0)), // Not deployed in this script
            multiTroveGetter: IMultiTroveGetter(address(0)), // Not deployed in this script
            collateralRegistry: ICollateralRegistry(address(0)), // Not deployed in this script
            boldToken: IBoldToken(addresses.boldToken),
            WETH: IWETH(WETH_ADDRESS)
        });
        registry.setAddresses(addressVars);
        
        console2.log("AddressesRegistry populated with all premined addresses");
    }
    

}