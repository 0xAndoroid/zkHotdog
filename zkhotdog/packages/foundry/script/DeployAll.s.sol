// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import "../contracts/ZkHotdog.sol";
import "../contracts/MockZkVerify.sol";
import "../contracts/ZkHotdogServiceManager.sol";
import "./utils/ZkHotdogDeploymentLib.sol";
import "./utils/CoreDeploymentLib.sol";
import "./utils/UpgradeableProxyLib.sol";
import {Quorum, StrategyParams, IStrategy} from "@eigenlayer-middleware/src/interfaces/IECDSAStakeRegistryEventsAndErrors.sol";
import {ERC20Mock} from "../test/ERC20Mock.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title DeployAll
 * @dev Script to deploy all contracts for ZkHotdog to a local Anvil instance
 */
contract DeployAll is Script {
    // Config from .env
    string public constant RPC_URL_ENV = "ANVIL_RPC_URL";
    string public constant PRIVATE_KEY_ENV = "DEPLOYER_PRIVATE_KEY";
    string public constant ZK_VERIFY_DEPLOY_ENV = "ZK_VERIFY_DEPLOY";
    string public constant ZK_VERIFY_ADDRESS_ENV = "ZK_VERIFY_ADDRESS";
    string public constant VKEY_ENV = "VKEY";
    string public constant DEPLOY_EIGENLAYER_CORE_ENV = "DEPLOY_EIGENLAYER_CORE";
    string public constant EIGENLAYER_AVS_DIRECTORY_ENV = "EIGENLAYER_AVS_DIRECTORY";
    string public constant EIGENLAYER_STAKE_REGISTRY_ENV = "EIGENLAYER_STAKE_REGISTRY";
    string public constant EIGENLAYER_REWARDS_COORDINATOR_ENV = "EIGENLAYER_REWARDS_COORDINATOR";
    string public constant EIGENLAYER_DELEGATION_MANAGER_ENV = "EIGENLAYER_DELEGATION_MANAGER";
    string public constant VERBOSE_ENV = "VERBOSE";

    function log(string memory message) internal view {
        bool verbose = true;
        try vm.envBool(VERBOSE_ENV) returns (bool v) {
            verbose = v;
        } catch {
            // Default to true if not specified
        }
        
        if (verbose) {
            console.log(message);
        }
    }

    function run() public {
        // Load private key from .env
        uint256 deployerPrivateKey = vm.envUint(PRIVATE_KEY_ENV);
        vm.startBroadcast(deployerPrivateKey);

        log("Starting deployment...");
        
        // Deploy or use existing zkVerify contract
        address zkVerifyAddress;
        bool deployZkVerify = true;
        try vm.envBool(ZK_VERIFY_DEPLOY_ENV) returns (bool deploy) {
            deployZkVerify = deploy;
        } catch {
            // Default to true if not specified
        }
        
        if (deployZkVerify) {
            // Deploy MockZkVerify
            log("Deploying MockZkVerify...");
            MockZkVerify mockZkVerify = new MockZkVerify();
            zkVerifyAddress = address(mockZkVerify);
            log(string.concat("MockZkVerify deployed to: ", vm.toString(zkVerifyAddress)));
        } else {
            // Use existing zkVerify contract
            zkVerifyAddress = vm.envAddress(ZK_VERIFY_ADDRESS_ENV);
            log(string.concat("Using existing zkVerify at: ", vm.toString(zkVerifyAddress)));
        }

        // Get vkey from .env or use a default for testing
        bytes32 vkey;
        try vm.envBytes32(VKEY_ENV) returns (bytes32 v) {
            vkey = v;
        } catch {
            // Default testing value if not specified
            vkey = bytes32(uint256(123456789));
            log("Using default test vkey");
        }
        
        // Deploy ZkHotdog Contract
        log("Deploying ZkHotdog NFT...");
        ZkHotdog zkHotdog = new ZkHotdog(zkVerifyAddress, vkey);
        log(string.concat("ZkHotdog deployed to: ", vm.toString(address(zkHotdog))));

        // Deploy EigenLayer core or use existing deployment
        CoreDeploymentLib.DeploymentData memory coreDeployment;
        address proxyAdmin = UpgradeableProxyLib.deployProxyAdmin();
        log(string.concat("ProxyAdmin deployed to: ", vm.toString(proxyAdmin)));
        
        bool deployEigenLayerCore = true;
        try vm.envBool(DEPLOY_EIGENLAYER_CORE_ENV) returns (bool deploy) {
            deployEigenLayerCore = deploy;
        } catch {
            // Default to true if not specified
        }
        
        if (deployEigenLayerCore) {
            // Deploy EigenLayer core
            log("Deploying EigenLayer core...");
            
            // Create a mock ETH deposit contract for testing (used when deploying to local network)
            address ethPOSDeposit;
            if (block.chainid == 1) {
                ethPOSDeposit = 0x00000000219ab540356cBB839Cbe05303d7705Fa;
            } else {
                // Mock implementation for local testing
                ethPOSDeposit = address(0x1234567890123456789012345678901234567890);
                log("Using mock ETH POS Deposit for local testing");
            }
            
            // Create mock core deployment data with strategy factory capability
            // Create proper deployment config with null/default values
            CoreDeploymentLib.DeploymentConfigData memory coreConfig;
            
            // Set default values for configs
            coreConfig.strategyManager.initPausedStatus = 0;
            coreConfig.strategyManager.initWithdrawalDelayBlocks = 50400;
            coreConfig.delegationManager.initPausedStatus = 0;
            coreConfig.delegationManager.withdrawalDelayBlocks = 50400;
            coreConfig.eigenPodManager.initPausedStatus = 0;
            coreConfig.rewardsCoordinator.initPausedStatus = 0;
            coreConfig.rewardsCoordinator.updater = msg.sender; // Use deployer as updater
            coreConfig.rewardsCoordinator.activationDelay = 86400; // 1 day
            coreConfig.rewardsCoordinator.globalOperatorCommissionBips = 1000; // 10%
            coreConfig.strategyFactory.initPausedStatus = 0;
            
            // Deploy core contracts properly with strategy factory
            coreDeployment = CoreDeploymentLib.deployContracts(proxyAdmin, coreConfig);
            
            log("EigenLayer core deployed successfully");
        } else {
            // Use existing EigenLayer deployment
            coreDeployment.avsDirectory = vm.envAddress(EIGENLAYER_AVS_DIRECTORY_ENV);
            coreDeployment.rewardsCoordinator = vm.envAddress(EIGENLAYER_REWARDS_COORDINATOR_ENV);
            coreDeployment.delegationManager = vm.envAddress(EIGENLAYER_DELEGATION_MANAGER_ENV);
            log("Using existing EigenLayer deployment");
        }

        // Setup ERC20 token for testing
        log("Deploying ERC20 mock token for testing...");
        ERC20Mock mockToken = new ERC20Mock();
        log(string.concat("ERC20Mock deployed to: ", vm.toString(address(mockToken))));

        // Setup quorum
        log("Setting up quorum...");
        
        // Create a strategy for the mock token using the strategy factory
        log("Deploying strategy for mock token...");
        
        // Verify strategyFactory address
        address strategyFactoryAddr = coreDeployment.strategyFactory;
        log(string.concat("Using StrategyFactory at: ", vm.toString(strategyFactoryAddr)));
        
        // Call the deployNewStrategy function on the StrategyFactory
        bytes memory callData = abi.encodeWithSignature(
            "deployNewStrategy(address)", 
            address(mockToken)
        );
        
        (bool success, bytes memory returnData) = strategyFactoryAddr.call(callData);
        require(success, "Strategy deployment failed");
        
        // Decode the returned strategy address
        IStrategy strategy = abi.decode(returnData, (IStrategy));
        log(string.concat("Token strategy deployed to: ", vm.toString(address(strategy))));
        
        // Setup quorum with at least one strategy
        Quorum memory quorum;
        quorum.strategies = new StrategyParams[](1);
        quorum.strategies[0] = StrategyParams({
            strategy: strategy,
            multiplier: 10_000 // Standard multiplier value as seen in the tests
        });
        
        // Deploy ZkHotdogServiceManager contract
        log("Deploying ZkHotdogServiceManager...");
        address owner = vm.addr(deployerPrivateKey);
        ZkHotdogDeploymentLib.DeploymentData memory zkHotdogDeployment = ZkHotdogDeploymentLib.deployContracts(
            proxyAdmin,
            coreDeployment,
            quorum,
            owner,
            owner
        );
        
        // Store the strategy in the deployment data for future use
        zkHotdogDeployment.strategy = address(strategy);
        zkHotdogDeployment.token = address(mockToken);
        log(string.concat("ZkHotdogServiceManager deployed to: ", vm.toString(zkHotdogDeployment.zkHotdogServiceManager)));
        log(string.concat("StakeRegistry deployed to: ", vm.toString(zkHotdogDeployment.stakeRegistry)));

        // Set service manager in ZkHotdog contract
        log("Setting service manager in ZkHotdog NFT...");
        zkHotdog.setServiceManager(zkHotdogDeployment.zkHotdogServiceManager);
        log("Service manager set successfully");

        // Deployment Summary
        log("\n=== DEPLOYMENT SUMMARY ===");
        log(string.concat("ZkVerify:                ", vm.toString(zkVerifyAddress)));
        log(string.concat("ZkHotdog NFT:            ", vm.toString(address(zkHotdog))));
        log(string.concat("ZkHotdogServiceManager:  ", vm.toString(zkHotdogDeployment.zkHotdogServiceManager)));
        log(string.concat("EigenLayer AVS Directory:", vm.toString(coreDeployment.avsDirectory)));
        log(string.concat("StakeRegistry:           ", vm.toString(zkHotdogDeployment.stakeRegistry)));
        log(string.concat("RewardsCoordinator:      ", vm.toString(coreDeployment.rewardsCoordinator)));
        log(string.concat("DelegationManager:       ", vm.toString(coreDeployment.delegationManager)));
        log(string.concat("MockToken:               ", vm.toString(address(mockToken))));
        log(string.concat("TokenStrategy:           ", vm.toString(address(strategy))));
        log(string.concat("StrategyFactory:         ", vm.toString(coreDeployment.strategyFactory)));
        log("=========================\n");

        vm.stopBroadcast();
    }
}