// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import "src/AddressesRegistry.sol";
import "src/ActivePool.sol";
import "src/BoldToken.sol";
import "src/BorrowerOperations.sol";
import "src/CollSurplusPool.sol";
import "src/DefaultPool.sol";
import "src/GasPool.sol";
import "src/HintHelpers.sol";
import "src/MultiTroveGetter.sol";
import "src/SortedTroves.sol";
import "src/StabilityPool.sol";
import "./BorrowerOperationsTester.t.sol";
import "./TroveManagerTester.t.sol";
import "./CollateralRegistryTester.sol";
import "src/TroveNFT.sol";
import "src/NFTMetadata/MetadataNFT.sol";
import "src/CollateralRegistry.sol";
import "./MockInterestRouter.sol";
import "./PriceFeedTestnet.sol";
import "./MetadataDeployment.sol";
import "src/Zappers/WETHZapper.sol";
import "src/Zappers/GasCompZapper.sol";
import "src/Zappers/LeverageLSTZapper.sol";
import "src/Zappers/LeverageWETHZapper.sol";
import "src/Zappers/Modules/FlashLoans/BalancerFlashLoan.sol";
import "src/Zappers/Interfaces/IFlashLoanProvider.sol";
import "src/Tokens/IWTAO.sol";
import "src/Zappers/Interfaces/IExchange.sol";
import "src/Zappers/Modules/Exchanges/UniswapV3/ISwapRouter.sol";
import "src/Zappers/Modules/Exchanges/UniswapV3/IUniswapV3Factory.sol";
import "src/Zappers/Modules/Exchanges/UniswapV3/IUniswapV3Pool.sol";
import "src/Zappers/Modules/Exchanges/UniV3Exchange.sol";
import "src/Zappers/Modules/Exchanges/UniswapV3/INonfungiblePositionManager.sol";
import {WETHTester} from "./WETHTester.sol";
import {ERC20Faucet} from "./ERC20Faucet.sol";
import {WTAO} from "src/Tokens/WTAO.sol";

import {PythVTAOPriceFeed} from "src/PriceFeeds/PythVTAOPriceFeed.sol";
import {PythWTAOPriceFeed} from "src/PriceFeeds/PythWTAOPriceFeed.sol";
import {BittensorPrecompileMock} from "./BittensorPrecompileMock.sol";
import {PythAggregatorV3} from "@pythnetwork/pyth-sdk-solidity/PythAggregatorV3.sol";
import "forge-std/Test.sol";
import "forge-std/console.sol";

import "forge-std/console2.sol";

uint256 constant _24_HOURS = 86400;
uint256 constant _48_HOURS = 172800;

// Pyth Test Deployer for vTAO and WTAO collaterals
contract PythTestDeployer is MetadataDeployment, Test {
    IWETH constant WETH_MAINNET = IWETH(0x9Dc08C6e2BF0F1eeD1E00670f80Df39145529F81);

    // UniV3
    IUniswapV3Factory constant uniV3Factory = IUniswapV3Factory(0x20D0Cdf9004bf56BCa52A25C9288AAd0EbB97D59);
    ISwapRouter constant uniV3Router = ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);
    INonfungiblePositionManager constant uniV3PositionManager =
        INonfungiblePositionManager(0xC36442b4a4522E871399CD717aBDD847Ab11FE88);
    uint24 constant UNIV3_FEE = 3000; // 0.3%
    uint24 constant UNIV3_FEE_WETH_COLL = 100; // 0.01%

    bytes32 constant SALT = keccak256("LiquityV2Pyth");

    struct LiquityContractsDevPools {
        IDefaultPool defaultPool;
        ICollSurplusPool collSurplusPool;
        GasPool gasPool;
    }

    struct LiquityContractsDev {
        IAddressesRegistry addressesRegistry;
        IBorrowerOperationsTester borrowerOperations; // Tester
        ISortedTroves sortedTroves;
        IActivePool activePool;
        IStabilityPool stabilityPool;
        ITroveManagerTester troveManager; // Tester
        ITroveNFT troveNFT;
        IPriceFeedTestnet priceFeed; // Tester
        IInterestRouter interestRouter;
        IERC20Metadata collToken;
        LiquityContractsDevPools pools;
    }

    struct LiquityContracts {
        IAddressesRegistry addressesRegistry;
        IActivePool activePool;
        IBorrowerOperations borrowerOperations;
        ICollSurplusPool collSurplusPool;
        IDefaultPool defaultPool;
        GasPool gasPool;
        IHintHelpers hintHelpers;
        IMultiTroveGetter multiTroveGetter;
        IPriceFeed priceFeed;
        ISortedTroves sortedTroves;
        IStabilityPool stabilityPool;
        ITroveManager troveManager;
        ITroveNFT troveNFT;
        IMetadataNFT metadataNFT;
        IInterestRouter interestRouter;
        IERC20Metadata collToken;
        ICollateralRegistry collateralRegistry;
        IBoldToken boldToken;
        IWETH WETH;
        IUniswapV3Pool uniV3Pool;
    }

    struct Zappers {
        WETHZapper wethZapper;
        GasCompZapper gasCompZapper;
        LeverageLSTZapper leverageLSTZapper;
        LeverageWETHZapper leverageWETHZapper;
    }

    struct DeploymentResult {
        LiquityContracts[] contractsArray;
        Zappers[] zappersArray;
        ICollateralRegistry collateralRegistry;
        IBoldToken boldToken;
        IHintHelpers hintHelpers;
        IMultiTroveGetter multiTroveGetter;
        ExternalAddresses externalAddresses;
        IUniswapV3Pool uniV3Pool;
    }

    struct DeploymentVarsMainnet {
        uint256 numCollaterals;
        IERC20Metadata[] collaterals;
        IAddressesRegistry[] addressesRegistries;
        ITroveManager[] troveManagers;
        OracleParams oracleParams;
        IPriceFeed[] priceFeeds;
        bytes bytecode;
        address boldTokenAddress;
        uint256 i;
    }

    struct DeploymentParamsMainnet {
        uint256 branch;
        IERC20Metadata collToken;
        IPriceFeed priceFeed;
        IBoldToken boldToken;
        ICollateralRegistry collateralRegistry;
        IWETH weth;
        IAddressesRegistry addressesRegistry;
        address troveManagerAddress;
        IHintHelpers hintHelpers;
        IMultiTroveGetter multiTroveGetter;
        IUniswapV3Pool uniV3Pool;
    }

    struct ExternalAddresses {
        address VTAOOracle;
        address WTAOOracle;
        address VTAOToken;
        address WTAOToken;
    }

    struct TroveManagerParams {
        uint256 CCR;
        uint256 MCR;
        uint256 BCR;
        uint256 SCR;
        uint256 LIQUIDATION_PENALTY_SP;
        uint256 LIQUIDATION_PENALTY_REDISTRIBUTION;
    }

    struct OracleParams {
        uint256 vtaoUsdStalenessThreshold;
        uint256 wtaoUsdStalenessThreshold;
    }

    // See: https://solidity-by-example.org/app/create2/
    function getBytecode(bytes memory _creationCode, address _addressesRegistry) public pure returns (bytes memory) {
        return abi.encodePacked(_creationCode, abi.encode(_addressesRegistry));
    }

    function getAddress(address _deployer, bytes memory _bytecode, bytes32 _salt) public pure returns (address) {
        bytes32 hash = keccak256(abi.encodePacked(bytes1(0xff), _deployer, _salt, keccak256(_bytecode)));

        // NOTE: cast last 20 bytes of hash to address
        return address(uint160(uint256(hash)));
    }

    function deployAndConnectContracts()
        external
        returns (
            LiquityContractsDev memory contracts,
            ICollateralRegistry collateralRegistry,
            IBoldToken boldToken,
            ERC20Faucet collFaucet
        )
    {
        // Deploy WETH tester with proper constructor parameters
        WETHTester weth = new WETHTester(1 ether, 1 days);

        // Deploy collateral faucet with proper constructor parameters
        collFaucet = new ERC20Faucet("Wrapped Ether", "WETH", 1 ether, 1 days);

        // Deploy Bold
        boldToken = new BoldToken(address(this));

        // Deploy registry
        IERC20Metadata[] memory collaterals = new IERC20Metadata[](1);
        ITroveManager[] memory troveManagers = new ITroveManager[](1);
        collaterals[0] = IERC20Metadata(address(weth));

        // Deploy contracts for single collateral - simplified version
        contracts.collToken = IERC20Metadata(address(weth));
        contracts.addressesRegistry = new AddressesRegistry(address(this), 150e16, 110e16, 10e16, 110e16, 5e16, 10e16);
        contracts.priceFeed = new PriceFeedTestnet();
        contracts.interestRouter = new MockInterestRouter();
        
        // Create minimal contract instances
        contracts.borrowerOperations = new BorrowerOperationsTester(contracts.addressesRegistry);
        contracts.troveManager = new TroveManagerTester(contracts.addressesRegistry);
        contracts.sortedTroves = new SortedTroves(contracts.addressesRegistry);
        contracts.activePool = new ActivePool(contracts.addressesRegistry);
        contracts.stabilityPool = new StabilityPool(contracts.addressesRegistry);
        contracts.troveNFT = new TroveNFT(contracts.addressesRegistry);
        contracts.pools.defaultPool = new DefaultPool(contracts.addressesRegistry);
        contracts.pools.collSurplusPool = new CollSurplusPool(contracts.addressesRegistry);
        contracts.pools.gasPool = new GasPool(contracts.addressesRegistry);
        
        troveManagers[0] = contracts.troveManager;

        collateralRegistry = new CollateralRegistryTester(boldToken, collaterals, troveManagers);

        return (contracts, collateralRegistry, boldToken, collFaucet);
    }

    function deployAndConnectContractsMainnet(TroveManagerParams[] memory _troveManagerParamsArray)
        external
        returns (DeploymentResult memory result)
    {
        DeploymentVarsMainnet memory vars;

        // Deploy and setup Bittensor precompile mock
        BittensorPrecompileMock precompileMock = new BittensorPrecompileMock();
        vm.etch(0x0000000000000000000000000000000000000805, address(precompileMock).code);

        // Use existing WTAO token as WETH implementation
        IWTAO wtaoToken = IWTAO(0x9Dc08C6e2BF0F1eeD1E00670f80Df39145529F81);

        // Pyth oracle addresses from TaoFiPriceFeed.sol
        result.externalAddresses.VTAOOracle = 0x2880aB155794e7179c9eE2e38200202908C17B43; // Pyth oracle
        result.externalAddresses.WTAOOracle = 0x2880aB155794e7179c9eE2e38200202908C17B43; // Pyth oracle
        result.externalAddresses.VTAOToken = 0x31049849CCdD983D8F401077537438eaF12B12Af; // Real vTAO token
        result.externalAddresses.WTAOToken = address(wtaoToken); // Deployed WTAO token

        vars.oracleParams.vtaoUsdStalenessThreshold = _24_HOURS;
        vars.oracleParams.wtaoUsdStalenessThreshold = _24_HOURS;

        // Colls: vTAO, WTAO
        vars.numCollaterals = 2;
        result.contractsArray = new LiquityContracts[](vars.numCollaterals);
        result.zappersArray = new Zappers[](vars.numCollaterals);
        vars.collaterals = new IERC20Metadata[](vars.numCollaterals);
        vars.addressesRegistries = new IAddressesRegistry[](vars.numCollaterals);
        vars.troveManagers = new ITroveManager[](vars.numCollaterals);
        address troveManagerAddress;

        // Deploy Bold
        vars.bytecode = abi.encodePacked(type(BoldToken).creationCode, abi.encode(address(this)));
        vars.boldTokenAddress = getAddress(address(this), vars.bytecode, SALT);
        result.boldToken = new BoldToken{salt: SALT}(address(this));
        assert(address(result.boldToken) == vars.boldTokenAddress);

        // vTAO
        vars.collaterals[0] = IERC20Metadata(result.externalAddresses.VTAOToken);
        (vars.addressesRegistries[0], troveManagerAddress) =
            _deployAddressesRegistryMainnet(_troveManagerParamsArray[0]);
        vars.troveManagers[0] = ITroveManager(troveManagerAddress);

        // WTAO
        vars.collaterals[1] = IERC20Metadata(result.externalAddresses.WTAOToken);
        (vars.addressesRegistries[1], troveManagerAddress) =
            _deployAddressesRegistryMainnet(_troveManagerParamsArray[1]);
        vars.troveManagers[1] = ITroveManager(troveManagerAddress);

        // Deploy registry and register the TMs
        result.collateralRegistry = new CollateralRegistryTester(result.boldToken, vars.collaterals, vars.troveManagers);

        result.hintHelpers = new HintHelpers(result.collateralRegistry);
        result.multiTroveGetter = new MultiTroveGetter(result.collateralRegistry);

        // Deploy price feeds for each collateral
        vars.priceFeeds = new IPriceFeed[](vars.numCollaterals);
        for (vars.i = 0; vars.i < vars.numCollaterals; vars.i++) {
            vars.priceFeeds[vars.i] = _deployPriceFeed(
                vars.i,
                result.externalAddresses,
                vars.oracleParams,
                address(vars.addressesRegistries[vars.i].borrowerOperations())
            );
        }

        // Connect contracts for each collateral
        for (vars.i = 0; vars.i < vars.numCollaterals; vars.i++) {
            // Use WTAO as WETH for both branches
            // - For vTAO branch (index 0): WETH != collToken, so GasCompZapper will be used
            // - For WTAO branch (index 1): WETH == collToken, so WETHZapper will be used
            IWETH wethForBranch = IWETH(address(wtaoToken));
            
            result.contractsArray[vars.i] = _connectContractsMainnet(
                DeploymentParamsMainnet({
                    branch: vars.i,
                    collToken: vars.collaterals[vars.i], // This is correct: vTAO for index 0, WTAO for index 1
                    priceFeed: vars.priceFeeds[vars.i],
                    boldToken: result.boldToken,
                    collateralRegistry: result.collateralRegistry,
                    weth: wethForBranch, // WTAO address for both branches
                    addressesRegistry: vars.addressesRegistries[vars.i],
                    troveManagerAddress: address(vars.troveManagers[vars.i]),
                    hintHelpers: result.hintHelpers,
                    multiTroveGetter: result.multiTroveGetter,
                    uniV3Pool: result.uniV3Pool
                }),
                result.zappersArray[vars.i]
            );
        }

        // Authorize CollateralRegistry to burn BoldToken
        result.boldToken.setCollateralRegistry(address(result.collateralRegistry));

        return result;
    }

    function _deployAddressesRegistryMainnet(TroveManagerParams memory _troveManagerParams)
        internal
        returns (IAddressesRegistry, address)
    {
        IAddressesRegistry addressesRegistry = new AddressesRegistry(
            address(this),
            _troveManagerParams.CCR,
            _troveManagerParams.MCR,
            _troveManagerParams.BCR,
            _troveManagerParams.SCR,
            _troveManagerParams.LIQUIDATION_PENALTY_SP,
            _troveManagerParams.LIQUIDATION_PENALTY_REDISTRIBUTION
        );

        // Pre-calculate TroveManager address
        bytes memory bytecode = getBytecode(type(TroveManager).creationCode, address(addressesRegistry));
        address troveManagerAddress = getAddress(address(this), bytecode, SALT);

        return (addressesRegistry, troveManagerAddress);
    }

    function _connectContractsMainnet(DeploymentParamsMainnet memory params, Zappers memory zappers)
        internal
        returns (LiquityContracts memory contracts)
    {
        contracts.addressesRegistry = params.addressesRegistry;
        contracts.collToken = params.collToken;
        contracts.priceFeed = params.priceFeed;
        contracts.boldToken = params.boldToken;
        contracts.collateralRegistry = params.collateralRegistry;
        contracts.WETH = IWETH(params.weth);
        contracts.hintHelpers = params.hintHelpers;
        contracts.multiTroveGetter = params.multiTroveGetter;

        // Deploy metadata first
        contracts.metadataNFT = deployMetadata(SALT);

        // Deploy mock interest router for mainnet tests
        MockInterestRouter mockInterestRouter = new MockInterestRouter();

        // Pre-calculate and set addresses in registry
        _preCalculateAndSetAddresses(params, mockInterestRouter);

        // Deploy contracts
        _deployContracts(params, contracts, mockInterestRouter);

        // Connect Bold token
        params.boldToken.setBranchAddresses(
            address(contracts.troveManager),
            address(contracts.stabilityPool),
            address(contracts.borrowerOperations),
            address(contracts.activePool)
        );

        // Deploy Uniswap V3 pool and assign to contracts
        contracts.uniV3Pool = _deployUniV3Pool(params.collToken, params.boldToken);

        // Deploy zappers
        _deployZappers(
            params.addressesRegistry,
            params.collToken,
            params.boldToken,
            params.weth,
            params.priceFeed,
            contracts.uniV3Pool,
            true, // mainnet
            zappers
        );
    }

    function _preCalculateAndSetAddresses(DeploymentParamsMainnet memory params, MockInterestRouter mockInterestRouter) internal {
        // Pre-calculate addresses using the same pattern as Deployment.t.sol
        address borrowerOperationsAddress = getAddress(
            address(this), getBytecode(type(BorrowerOperations).creationCode, address(params.addressesRegistry)), SALT
        );
        address troveNFTAddress = getAddress(
            address(this), getBytecode(type(TroveNFT).creationCode, address(params.addressesRegistry)), SALT
        );
        address stabilityPoolAddress = getAddress(
            address(this), getBytecode(type(StabilityPool).creationCode, address(params.addressesRegistry)), SALT
        );
        address activePoolAddress = getAddress(
            address(this), getBytecode(type(ActivePool).creationCode, address(params.addressesRegistry)), SALT
        );
        address defaultPoolAddress = getAddress(
            address(this), getBytecode(type(DefaultPool).creationCode, address(params.addressesRegistry)), SALT
        );
        address gasPoolAddress = getAddress(
            address(this), getBytecode(type(GasPool).creationCode, address(params.addressesRegistry)), SALT
        );
        address collSurplusPoolAddress = getAddress(
            address(this), getBytecode(type(CollSurplusPool).creationCode, address(params.addressesRegistry)), SALT
        );
        address sortedTrovesAddress = getAddress(
            address(this), getBytecode(type(SortedTroves).creationCode, address(params.addressesRegistry)), SALT
        );

        // Set addresses in registry BEFORE deploying contracts
        IAddressesRegistry.AddressVars memory addressVars = IAddressesRegistry.AddressVars({
            collToken: params.collToken,
            borrowerOperations: IBorrowerOperations(borrowerOperationsAddress),
            troveManager: ITroveManager(params.troveManagerAddress),
            troveNFT: ITroveNFT(troveNFTAddress),
            metadataNFT: IMetadataNFT(address(0)), // Will be set later
            stabilityPool: IStabilityPool(stabilityPoolAddress),
            priceFeed: params.priceFeed,
            activePool: IActivePool(activePoolAddress),
            defaultPool: IDefaultPool(defaultPoolAddress),
            gasPoolAddress: gasPoolAddress,
            collSurplusPool: ICollSurplusPool(collSurplusPoolAddress),
            sortedTroves: ISortedTroves(sortedTrovesAddress),
            interestRouter: IInterestRouter(address(mockInterestRouter)),
            hintHelpers: params.hintHelpers,
            multiTroveGetter: params.multiTroveGetter,
            collateralRegistry: params.collateralRegistry,
            boldToken: params.boldToken,
            WETH: params.weth
        });
        params.addressesRegistry.setAddresses(addressVars);
    }

    function _deployContracts(DeploymentParamsMainnet memory params, LiquityContracts memory contracts, MockInterestRouter mockInterestRouter) internal {
        // Now deploy the actual contracts
        contracts.borrowerOperations = new BorrowerOperations{salt: SALT}(params.addressesRegistry);
        contracts.troveManager = new TroveManager{salt: SALT}(params.addressesRegistry); // Actually deploy TM
        contracts.sortedTroves = new SortedTroves{salt: SALT}(params.addressesRegistry);
        contracts.activePool = new ActivePool{salt: SALT}(params.addressesRegistry);
        contracts.stabilityPool = new StabilityPool{salt: SALT}(params.addressesRegistry);
        contracts.troveNFT = new TroveNFT{salt: SALT}(params.addressesRegistry);
        contracts.defaultPool = new DefaultPool{salt: SALT}(params.addressesRegistry);
        contracts.collSurplusPool = new CollSurplusPool{salt: SALT}(params.addressesRegistry);
        contracts.gasPool = new GasPool{salt: SALT}(params.addressesRegistry);
        contracts.interestRouter = IInterestRouter(address(mockInterestRouter));
    }

    function _deployPriceFeed(
        uint256 _branch,
        ExternalAddresses memory _externalAddresses,
        OracleParams memory _oracleParams,
        address _borrowerOperationsAddress
    ) internal returns (IPriceFeed) {
        // Create PythAggregatorV3 for TAO-USD only once (shared by all branches)
        if (address(deployedTaoAggregator) == address(0)) {
            deployedTaoAggregator = new PythAggregatorV3(
                _externalAddresses.VTAOOracle, // Pyth contract address
                0x410f41de235f2db824e562ea7ab2d3d3d4ff048316c61d629c0b93f58584e1af // TAO price ID
            );
        }
        
        // Create PythAggregatorV3 instances for each branch
        // vTAO
        if (_branch == 0) {
            // Create PythAggregatorV3 for vTAO
            deployedVTaoAggregator = new PythAggregatorV3(
                _externalAddresses.VTAOOracle, // Pyth contract address
                0x410f41de235f2db824e562ea7ab2d3d3d4ff048316c61d629c0b93f58584e1af // TAO price ID
            );
            
            return new PythVTAOPriceFeed(
                address(deployedTaoAggregator), // TAO-USD aggregator
                address(deployedVTaoAggregator), // vTAO-USD aggregator
                _externalAddresses.VTAOToken,
                3600, // 1 hour staleness threshold for TAO-USD
                3600, // 1 hour staleness threshold for vTAO-USD
                _borrowerOperationsAddress
            );
        }

        // WTAO
        // Create PythAggregatorV3 for WTAO
        deployedWTaoAggregator = new PythAggregatorV3(
            _externalAddresses.WTAOOracle, // Pyth contract address
            0x410f41de235f2db824e562ea7ab2d3d3d4ff048316c61d629c0b93f58584e1af // TAO price ID
        );
        
        return new PythWTAOPriceFeed(
            address(deployedTaoAggregator), // TAO-USD aggregator
            3600, // 1 hour staleness threshold for TAO-USD
            _borrowerOperationsAddress
        );
    }

    function _deployZappers(
        IAddressesRegistry _addressesRegistry,
        IERC20 _collToken,
        IBoldToken _boldToken,
        IWETH _weth,
        IPriceFeed _priceFeed,
        IUniswapV3Pool _uniV3Pool,
        bool _mainnet,
        Zappers memory zappers // result
    ) internal {
        IFlashLoanProvider flashLoanProvider = new BalancerFlashLoan();
        IExchange uniV3Exchange = _deployUniV3Exchange(_collToken, _boldToken, _uniV3Pool);

        // Deploy zappers based on whether collToken is different from WETH
        // GasCompZapper requires collToken != WETH (for LSTs like vTAO)
        // WETHZapper is used when collToken == WETH (for WTAO)
        
        console.log("Deploying zappers for branch:");
        console.log("  collToken:", address(_collToken));
        console.log("  WETH:", address(_weth));
        console.log("  collToken != WETH:", _collToken != _weth);
        
        if (_collToken != _weth) {
            // Deploy GasCompZapper for LST tokens (vTAO - different from WETH)
            console.log("Deploying GasCompZapper for LST branch");
            zappers.gasCompZapper = new GasCompZapper(_addressesRegistry, flashLoanProvider, uniV3Exchange);
        } else {
            // Deploy WETHZapper for WETH-equivalent tokens (WTAO - same as WETH)
            console.log("Deploying WETHZapper for WETH branch");
            zappers.wethZapper = new WETHZapper(_addressesRegistry, flashLoanProvider, uniV3Exchange);
        }

        if (_mainnet) {
            _deployLeverageZappers(
                _addressesRegistry,
                _weth,
                _collToken,
                _boldToken,
                _priceFeed,
                flashLoanProvider,
                uniV3Exchange,
                _uniV3Pool,
                zappers
            );
        }
    }

    function _deployUniV3Pool(
        IERC20 _collToken,
        IBoldToken _boldToken
    ) internal returns (IUniswapV3Pool) {
        // Create pool with 0.3% fee tier (3000)
        address poolAddress = uniV3Factory.createPool(
            address(_collToken),
            address(_boldToken),
            UNIV3_FEE
        );
        
        return IUniswapV3Pool(poolAddress);
    }

    function _deployUniV3Exchange(IERC20 _collToken, IBoldToken _boldToken, IUniswapV3Pool _uniV3Pool)
        internal
        returns (IExchange)
    {
        return new UniV3Exchange(
            _collToken,
            _boldToken,
            UNIV3_FEE,
            uniV3Router
        );
    }

    function _deployLeverageZappers(
        IAddressesRegistry _addressesRegistry,
        IWETH _weth,
        IERC20 _collToken,
        IBoldToken _boldToken,
        IPriceFeed _priceFeed,
        IFlashLoanProvider _flashLoanProvider,
        IExchange _uniV3Exchange,
        IUniswapV3Pool _uniV3Pool,
        Zappers memory zappers // result
    ) internal {
        // Check if we're on WTAO branch (collateral token is WETH)
        bool isWTAO = address(_collToken) == address(_weth);
        
        if (isWTAO) {
            // Deploy leverage WETH zapper for WTAO branch
            // LeverageWETHZapper inherits from WETHZapper which requires collToken == WETH
            zappers.leverageWETHZapper = new LeverageWETHZapper(
                _addressesRegistry,
                _flashLoanProvider,
                _uniV3Exchange
            );
        } else {
            // Deploy leverage LST zapper for vTAO branch (LST tokens)
            // LeverageLSTZapper inherits from GasCompZapper which requires collToken != WETH
            zappers.leverageLSTZapper = new LeverageLSTZapper(
                _addressesRegistry,
                _flashLoanProvider,
                _uniV3Exchange
            );
        }
    }

    // Store deployed aggregators for oracle functions
    PythAggregatorV3 public deployedTaoAggregator;
    PythAggregatorV3 public deployedVTaoAggregator;
    PythAggregatorV3 public deployedWTaoAggregator;
    
    // Oracle functions that return proper PythAggregatorV3 instances instead of 0 addresses
    function ethUsdOracle() external view returns (address, uint256, uint8) {
        // Return TAO aggregator as the primary oracle (equivalent to ETH in mainnet)
        if (address(deployedTaoAggregator) != address(0)) {
            return (address(deployedTaoAggregator), 3600, 18); // 1 hour staleness, 18 decimals
        }
        return (address(0), 0, 0);
    }
    
    function taoUsdOracle() external view returns (address, uint256, uint8) {
        // Return TAO aggregator
        if (address(deployedTaoAggregator) != address(0)) {
            return (address(deployedTaoAggregator), 3600, 18); // 1 hour staleness, 18 decimals
        }
        return (address(0), 0, 0);
    }
    
    // Test function to verify deployment works correctly
    function test_deployAndConnectContractsMainnet() public {
        // Define trove manager parameters for 2 branches (vTAO and WTAO)
        TroveManagerParams[] memory troveManagerParamsArray = new TroveManagerParams[](2);
        
        // vTAO branch parameters
        troveManagerParamsArray[0] = TroveManagerParams({
            CCR: 150e16, // 150%
            MCR: 110e16, // 110%
            BCR: 10e16, // 10% (within valid range 5%-50%)
            SCR: 130e16, // 130%
            LIQUIDATION_PENALTY_SP: 5e16, // 5%
            LIQUIDATION_PENALTY_REDISTRIBUTION: 5e16 // 5%
        });
        
        // WTAO branch parameters
        troveManagerParamsArray[1] = TroveManagerParams({
            CCR: 150e16, // 150%
            MCR: 110e16, // 110%
            BCR: 10e16, // 10% (within valid range 5%-50%)
            SCR: 130e16, // 130%
            LIQUIDATION_PENALTY_SP: 5e16, // 5%
            LIQUIDATION_PENALTY_REDISTRIBUTION: 5e16 // 5%
        });
        
        // Deploy contracts
        DeploymentResult memory result = this.deployAndConnectContractsMainnet(troveManagerParamsArray);
        
        // Verify deployment was successful
        assertEq(result.contractsArray.length, 2, "Should deploy 2 branches");
        assertTrue(address(result.boldToken) != address(0), "BoldToken should be deployed");
        assertTrue(address(result.collateralRegistry) != address(0), "CollateralRegistry should be deployed");
        
        // Verify oracle functions return non-zero addresses
        (address ethOracle, uint256 ethStaleness, uint8 ethDecimals) = this.ethUsdOracle();
        assertTrue(ethOracle != address(0), "ethUsdOracle should return non-zero address");
        assertEq(ethStaleness, 3600, "ethUsdOracle staleness should be 1 hour");
        assertEq(ethDecimals, 18, "ethUsdOracle decimals should be 18");
        
        (address taoOracle, uint256 taoStaleness, uint8 taoDecimals) = this.taoUsdOracle();
        assertTrue(taoOracle != address(0), "taoUsdOracle should return non-zero address");
        assertEq(taoStaleness, 3600, "taoUsdOracle staleness should be 1 hour");
        assertEq(taoDecimals, 18, "taoUsdOracle decimals should be 18");
        
        // Verify price feeds are deployed
        for (uint256 i = 0; i < result.contractsArray.length; i++) {
            assertTrue(address(result.contractsArray[i].priceFeed) != address(0), "PriceFeed should be deployed");
        }
        
        console.log("Pyth deployment test completed successfully");
        console.log("ETH Oracle address:", ethOracle);
        console.log("TAO Oracle address:", taoOracle);
    }
}