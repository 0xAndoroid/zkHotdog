// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {ZkHotdogServiceManager} from "../contracts/ZkHotdogServiceManager.sol";
import {ZkHotdog} from "../contracts/ZkHotdog.sol";
import {MockZkVerify} from "../contracts/MockZkVerify.sol";
import {MockAVSDeployer} from "@eigenlayer-middleware/test/utils/MockAVSDeployer.sol";
import {ECDSAStakeRegistry} from "@eigenlayer-middleware/src/unaudited/ECDSAStakeRegistry.sol";
import {Vm} from "forge-std/Vm.sol";
import {console2} from "forge-std/Test.sol";
import {ZkHotdogDeploymentLib} from "../script/utils/ZkHotdogDeploymentLib.sol";
import {CoreDeploymentLib} from "../script/utils/CoreDeploymentLib.sol";
import {UpgradeableProxyLib} from "../script/utils/UpgradeableProxyLib.sol";
import {ERC20Mock} from "./ERC20Mock.sol";
import {IERC20, StrategyFactory} from "@eigenlayer/contracts/strategies/StrategyFactory.sol";

import {
    Quorum,
    StrategyParams,
    IStrategy
} from "@eigenlayer-middleware/src/interfaces/IECDSAStakeRegistryEventsAndErrors.sol";
import {IStrategyManager} from "@eigenlayer/contracts/interfaces/IStrategyManager.sol";
import {IDelegationManager} from "@eigenlayer/contracts/interfaces/IDelegationManager.sol";
import {ISignatureUtils} from "@eigenlayer/contracts/interfaces/ISignatureUtils.sol";
import {AVSDirectory} from "@eigenlayer/contracts/core/AVSDirectory.sol";
import {IAVSDirectory} from "@eigenlayer/contracts/interfaces/IAVSDirectory.sol";
import {Test, console2 as console} from "forge-std/Test.sol";
import {IZkHotdogServiceManager} from "../contracts/IZkHotdogServiceManager.sol";
import {ECDSAUpgradeable} from
    "@openzeppelin-upgrades/contracts/utils/cryptography/ECDSAUpgradeable.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

contract ZkHotdogTaskManagerSetup is Test {
    Quorum internal quorum;

    struct Operator {
        Vm.Wallet key;
        Vm.Wallet signingKey;
    }

    struct User {
        Vm.Wallet key;
    }

    struct AVSOwner {
        Vm.Wallet key;
    }

    Operator[] internal operators;
    User internal user;
    AVSOwner internal owner;

    ZkHotdogDeploymentLib.DeploymentData internal zkHotdogDeployment;
    CoreDeploymentLib.DeploymentData internal coreDeployment;
    CoreDeploymentLib.DeploymentConfigData coreConfigData;

    ERC20Mock public mockToken;
    MockZkVerify public mockZkVerify;
    ZkHotdog public zkHotdogNft;
    bytes32 public mockVkey = bytes32(uint256(123456789));

    mapping(address => IStrategy) public tokenToStrategy;

    // Mock data for attestation verification
    uint256 public mockAttestationId = 12345;
    bytes32[] public mockMerklePath;
    uint256 public mockLeafCount = 10;
    uint256 public mockIndex = 3;
    string public constant TEST_IMAGE_URL = "https://example.com/hotdog.jpg";
    uint256 public constant TEST_LENGTH = 25; // 25 cm

    function setUp() public virtual {
        user = User({key: vm.createWallet("user_wallet")});
        owner = AVSOwner({key: vm.createWallet("owner_wallet")});

        // Create mock merkle path
        mockMerklePath = new bytes32[](3);
        mockMerklePath[0] = bytes32(uint256(111));
        mockMerklePath[1] = bytes32(uint256(222));
        mockMerklePath[2] = bytes32(uint256(333));

        address proxyAdmin = UpgradeableProxyLib.deployProxyAdmin();

        coreConfigData =
            CoreDeploymentLib.readDeploymentConfigValues("test/mockData/config/core/", 1337);
        coreDeployment = CoreDeploymentLib.deployContracts(proxyAdmin, coreConfigData);

        mockToken = new ERC20Mock();

        // These will be deployed by ZkHotdogDeploymentLib

        IStrategy strategy = addStrategy(address(mockToken));
        quorum.strategies.push(StrategyParams({strategy: strategy, multiplier: 10_000}));

        zkHotdogDeployment = ZkHotdogDeploymentLib.deployContracts(
            proxyAdmin, coreDeployment, quorum, owner.key.addr, owner.key.addr
        );
        labelContracts(coreDeployment, zkHotdogDeployment);

        // Use zkHotdogNft from deployment
        zkHotdogNft = ZkHotdog(zkHotdogDeployment.zkHotdogNft);
    }

    function addStrategy(
        address token
    ) public returns (IStrategy) {
        if (tokenToStrategy[token] != IStrategy(address(0))) {
            return tokenToStrategy[token];
        }

        StrategyFactory strategyFactory = StrategyFactory(coreDeployment.strategyFactory);
        IStrategy newStrategy = strategyFactory.deployNewStrategy(IERC20(token));
        tokenToStrategy[token] = newStrategy;
        return newStrategy;
    }

    function labelContracts(
        CoreDeploymentLib.DeploymentData memory coreDeploymentArg,
        ZkHotdogDeploymentLib.DeploymentData memory zkHotdogDeploymentArg
    ) internal {
        vm.label(coreDeploymentArg.delegationManager, "DelegationManager");
        vm.label(coreDeploymentArg.avsDirectory, "AVSDirectory");
        vm.label(coreDeploymentArg.strategyManager, "StrategyManager");
        vm.label(coreDeploymentArg.eigenPodManager, "EigenPodManager");
        vm.label(coreDeploymentArg.rewardsCoordinator, "RewardsCoordinator");
        vm.label(coreDeploymentArg.eigenPodBeacon, "EigenPodBeacon");
        vm.label(coreDeploymentArg.pauserRegistry, "PauserRegistry");
        vm.label(coreDeploymentArg.strategyFactory, "StrategyFactory");
        vm.label(coreDeploymentArg.strategyBeacon, "StrategyBeacon");
        vm.label(zkHotdogDeploymentArg.zkHotdogServiceManager, "ZkHotdogServiceManager");
        vm.label(zkHotdogDeploymentArg.stakeRegistry, "StakeRegistry");
        vm.label(address(zkHotdogNft), "ZkHotdogNFT");
        vm.label(address(mockZkVerify), "MockZkVerify");
    }

    function signWithOperatorKey(
        Operator memory operator,
        bytes32 digest
    ) internal pure returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(operator.key.privateKey, digest);
        return abi.encodePacked(r, s, v);
    }

    function signWithSigningKey(
        Operator memory operator,
        bytes32 digest
    ) internal pure returns (bytes memory) {
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(operator.signingKey.privateKey, digest);
        return abi.encodePacked(r, s, v);
    }

    function mintMockTokens(Operator memory operator, uint256 amount) internal {
        mockToken.mint(operator.key.addr, amount);
    }

    function depositTokenIntoStrategy(
        Operator memory operator,
        address token,
        uint256 amount
    ) internal returns (uint256) {
        IStrategy strategy = IStrategy(tokenToStrategy[token]);
        require(address(strategy) != address(0), "Strategy was not found");
        IStrategyManager strategyManager = IStrategyManager(coreDeployment.strategyManager);

        vm.startPrank(operator.key.addr);
        mockToken.approve(address(strategyManager), amount);
        uint256 shares = strategyManager.depositIntoStrategy(strategy, IERC20(token), amount);
        vm.stopPrank();

        return shares;
    }

    function registerAsOperator(
        Operator memory operator
    ) internal {
        IDelegationManager delegationManager = IDelegationManager(coreDeployment.delegationManager);

        IDelegationManager.OperatorDetails memory operatorDetails = IDelegationManager
            .OperatorDetails({
            __deprecated_earningsReceiver: operator.key.addr,
            delegationApprover: address(0),
            stakerOptOutWindowBlocks: 0
        });

        vm.prank(operator.key.addr);
        delegationManager.registerAsOperator(operatorDetails, "");
    }

    function registerOperatorToAVS(
        Operator memory operator
    ) internal {
        ECDSAStakeRegistry stakeRegistry = ECDSAStakeRegistry(zkHotdogDeployment.stakeRegistry);
        AVSDirectory avsDirectory = AVSDirectory(coreDeployment.avsDirectory);

        bytes32 salt = keccak256(abi.encodePacked(block.timestamp, operator.key.addr));
        uint256 expiry = block.timestamp + 1 hours;

        bytes32 operatorRegistrationDigestHash = avsDirectory
            .calculateOperatorAVSRegistrationDigestHash(
            operator.key.addr, address(zkHotdogDeployment.zkHotdogServiceManager), salt, expiry
        );

        bytes memory signature = signWithOperatorKey(operator, operatorRegistrationDigestHash);

        ISignatureUtils.SignatureWithSaltAndExpiry memory operatorSignature = ISignatureUtils
            .SignatureWithSaltAndExpiry({signature: signature, salt: salt, expiry: expiry});

        vm.prank(address(operator.key.addr));
        stakeRegistry.registerOperatorWithSignature(operatorSignature, operator.signingKey.addr);
    }

    function deregisterOperatorFromAVS(
        Operator memory operator
    ) internal {
        ECDSAStakeRegistry stakeRegistry = ECDSAStakeRegistry(zkHotdogDeployment.stakeRegistry);

        vm.prank(operator.key.addr);
        stakeRegistry.deregisterOperator();
    }

    function createAndAddOperator() internal returns (Operator memory) {
        Vm.Wallet memory operatorKey =
            vm.createWallet(string.concat("operator", vm.toString(operators.length)));
        Vm.Wallet memory signingKey =
            vm.createWallet(string.concat("signing", vm.toString(operators.length)));

        Operator memory newOperator = Operator({key: operatorKey, signingKey: signingKey});

        operators.push(newOperator);
        return newOperator;
    }

    function updateOperatorWeights(
        Operator[] memory _operators
    ) internal {
        ECDSAStakeRegistry stakeRegistry = ECDSAStakeRegistry(zkHotdogDeployment.stakeRegistry);

        address[] memory operatorAddresses = new address[](_operators.length);
        for (uint256 i = 0; i < _operators.length; i++) {
            operatorAddresses[i] = _operators[i].key.addr;
        }

        stakeRegistry.updateOperators(operatorAddresses);
    }

    function getSortedOperatorSignatures(
        Operator[] memory _operators,
        bytes32 digest
    ) internal pure returns (bytes[] memory) {
        uint256 length = _operators.length;
        bytes[] memory signatures = new bytes[](length);
        address[] memory addresses = new address[](length);

        for (uint256 i = 0; i < length; i++) {
            addresses[i] = _operators[i].key.addr;
            signatures[i] = signWithOperatorKey(_operators[i], digest);
        }

        for (uint256 i = 0; i < length - 1; i++) {
            for (uint256 j = 0; j < length - i - 1; j++) {
                if (addresses[j] > addresses[j + 1]) {
                    // Swap addresses
                    address tempAddr = addresses[j];
                    addresses[j] = addresses[j + 1];
                    addresses[j + 1] = tempAddr;

                    // Swap signatures
                    bytes memory tempSig = signatures[j];
                    signatures[j] = signatures[j + 1];
                    signatures[j + 1] = tempSig;
                }
            }
        }

        return signatures;
    }

    function mintHotdogNFT(User memory _user) internal returns (uint256) {
        // Ensure the service manager is set first
        address contractOwner = zkHotdogNft.owner();
        vm.prank(contractOwner);
        zkHotdogNft.setServiceManager(zkHotdogDeployment.zkHotdogServiceManager);
        
        // Mint the NFT
        vm.prank(_user.key.addr);
        uint256 tokenId = zkHotdogNft.mintWithAttestation(
            TEST_IMAGE_URL,
            TEST_LENGTH,
            mockAttestationId,
            mockMerklePath,
            mockLeafCount,
            mockIndex
        );
        
        return tokenId;
    }

    function createVerificationTask(User memory _user, uint256 tokenId) internal returns (IZkHotdogServiceManager.Task memory) {
        IZkHotdogServiceManager zkHotdogServiceManager =
            IZkHotdogServiceManager(zkHotdogDeployment.zkHotdogServiceManager);

        vm.prank(_user.key.addr);
        return zkHotdogServiceManager.createNewTask(tokenId, TEST_IMAGE_URL);
    }

    function respondToTask(
        Operator memory operator,
        IZkHotdogServiceManager.Task memory task,
        uint32 referenceTaskIndex,
        bool result
    ) internal {
        // Create the message hash
        bytes32 messageHash = keccak256(
            abi.encodePacked(
                "ZkHotdog Verification Task:",
                Strings.toString(task.tokenId),
                task.imageUrl,
                result ? "true" : "false"
            )
        );
        
        bytes32 ethSignedMessageHash = ECDSAUpgradeable.toEthSignedMessageHash(messageHash);
                
        // Create signature from signing key
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(operator.signingKey.privateKey, ethSignedMessageHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        // Mock the isValidSignature call for this specific operator
        vm.mockCall(
            zkHotdogDeployment.stakeRegistry,
            abi.encodeWithSelector(ECDSAStakeRegistry.isValidSignature.selector, ethSignedMessageHash, signature),
            abi.encode(bytes4(0x1626ba7e)) // IERC1271Upgradeable.isValidSignature.selector
        );

        vm.prank(operator.key.addr);
        IZkHotdogServiceManager(zkHotdogDeployment.zkHotdogServiceManager).respondToTask(
            task, referenceTaskIndex, result, signature
        );
    }
}

contract ZkHotdogServiceManagerInitialization is ZkHotdogTaskManagerSetup {
    function testInitialization() public view {
        ECDSAStakeRegistry stakeRegistry = ECDSAStakeRegistry(zkHotdogDeployment.stakeRegistry);

        Quorum memory quorum = stakeRegistry.quorum();

        assertGt(quorum.strategies.length, 0, "No strategies in quorum");
        assertEq(
            address(quorum.strategies[0].strategy),
            address(tokenToStrategy[address(mockToken)]),
            "First strategy doesn't match mock token strategy"
        );

        assertTrue(zkHotdogDeployment.stakeRegistry != address(0), "StakeRegistry not deployed");
        assertTrue(
            zkHotdogDeployment.zkHotdogServiceManager != address(0),
            "ZkHotdogServiceManager not deployed"
        );
        assertTrue(coreDeployment.delegationManager != address(0), "DelegationManager not deployed");
        assertTrue(coreDeployment.avsDirectory != address(0), "AVSDirectory not deployed");
        assertTrue(coreDeployment.strategyManager != address(0), "StrategyManager not deployed");
        assertTrue(coreDeployment.eigenPodManager != address(0), "EigenPodManager not deployed");
        assertTrue(coreDeployment.strategyFactory != address(0), "StrategyFactory not deployed");
        assertTrue(coreDeployment.strategyBeacon != address(0), "StrategyBeacon not deployed");
        
        // Check service manager is properly initialized with the NFT contract
        ZkHotdogServiceManager serviceManager = ZkHotdogServiceManager(zkHotdogDeployment.zkHotdogServiceManager);
        assertEq(address(serviceManager.zkHotdogNft()), address(zkHotdogNft), "NFT contract not set correctly");
        
        // Check NFT contract has service manager set
        assertEq(zkHotdogNft.serviceManager(), zkHotdogDeployment.zkHotdogServiceManager, "Service manager not set in NFT contract");
    }
}

contract RegisterOperator is ZkHotdogTaskManagerSetup {
    uint256 internal constant INITIAL_BALANCE = 100 ether;
    uint256 internal constant DEPOSIT_AMOUNT = 1 ether;
    uint256 internal constant OPERATOR_COUNT = 4;

    IDelegationManager internal delegationManager;
    AVSDirectory internal avsDirectory;
    IZkHotdogServiceManager internal sm;
    ECDSAStakeRegistry internal stakeRegistry;

    function setUp() public virtual override {
        super.setUp();
        /// Setting to internal state for convenience
        delegationManager = IDelegationManager(coreDeployment.delegationManager);
        avsDirectory = AVSDirectory(coreDeployment.avsDirectory);
        sm = IZkHotdogServiceManager(zkHotdogDeployment.zkHotdogServiceManager);
        stakeRegistry = ECDSAStakeRegistry(zkHotdogDeployment.stakeRegistry);

        addStrategy(address(mockToken));

        while (operators.length < OPERATOR_COUNT) {
            createAndAddOperator();
        }

        for (uint256 i = 0; i < OPERATOR_COUNT; i++) {
            mintMockTokens(operators[i], INITIAL_BALANCE);

            depositTokenIntoStrategy(operators[i], address(mockToken), DEPOSIT_AMOUNT);

            registerAsOperator(operators[i]);
        }
    }

    function testVerifyOperatorStates() public view {
        for (uint256 i = 0; i < OPERATOR_COUNT; i++) {
            address operatorAddr = operators[i].key.addr;

            uint256 operatorShares =
                delegationManager.operatorShares(operatorAddr, tokenToStrategy[address(mockToken)]);
            assertEq(
                operatorShares, DEPOSIT_AMOUNT, "Operator shares in DelegationManager incorrect"
            );
        }
    }

    function test_RegisterOperatorToAVS() public {
        address operatorAddr = operators[0].key.addr;
        registerOperatorToAVS(operators[0]);
        assertTrue(
            avsDirectory.avsOperatorStatus(address(sm), operatorAddr)
                == IAVSDirectory.OperatorAVSRegistrationStatus.REGISTERED,
            "Operator not registered in AVSDirectory"
        );

        address signingKey = stakeRegistry.getLastestOperatorSigningKey(operatorAddr);
        assertTrue(signingKey != address(0), "Operator signing key not set in ECDSAStakeRegistry");

        uint256 operatorWeight = stakeRegistry.getLastCheckpointOperatorWeight(operatorAddr);
        assertTrue(operatorWeight > 0, "Operator weight not set in ECDSAStakeRegistry");
    }
}

contract CreateTask is ZkHotdogTaskManagerSetup {
    IZkHotdogServiceManager internal sm;

    function setUp() public override {
        super.setUp();
        sm = IZkHotdogServiceManager(zkHotdogDeployment.zkHotdogServiceManager);
    }

    function testCreateTask() public {
        // This test verifies that tokens properly get a task created
        // when they are minted with the service manager set
        
        // Get owner of NFT contract for later use
        address contractOwner = zkHotdogNft.owner();
        
        // Set the service manager to our deployment
        vm.prank(contractOwner);
        zkHotdogNft.setServiceManager(zkHotdogDeployment.zkHotdogServiceManager);
        
        // Mint an NFT - this should automatically create a task
        vm.prank(address(0xdeadbeef));
        uint256 tokenId = zkHotdogNft.mintWithAttestation(
            TEST_IMAGE_URL,
            TEST_LENGTH,
            mockAttestationId,
            mockMerklePath,
            mockLeafCount,
            mockIndex
        );
        
        // Check token was minted
        assertEq(zkHotdogNft.ownerOf(tokenId), address(0xdeadbeef));
        
        // Create a second task to verify manual task creation works too
        vm.prank(address(0xdeadbeef));
        IZkHotdogServiceManager.Task memory newTask = sm.createNewTask(tokenId, "https://example.com/different-image.jpg");

        // Verify the new task was created with correct parameters
        assertEq(newTask.tokenId, tokenId, "Token ID not set correctly");
        assertEq(newTask.imageUrl, "https://example.com/different-image.jpg", "Image URL not set correctly");
        assertEq(newTask.taskCreatedBlock, uint32(block.number), "Task created block not set correctly");
    }
    
    function testCreateTaskForNonExistentToken() public {
        uint256 nonExistentTokenId = 999;
        
        vm.prank(user.key.addr);
        vm.expectRevert("ERC721: invalid token ID");
        sm.createNewTask(nonExistentTokenId, TEST_IMAGE_URL);
    }
    
    function testCreateTaskForAlreadyVerifiedToken() public {
        // Mint an NFT
        uint256 tokenId = mintHotdogNFT(user);
        
        // Get current owner of NFT contract
        address contractOwner = zkHotdogNft.owner();
        
        // Set service manager in NFT using contract owner address
        vm.prank(contractOwner);
        zkHotdogNft.setServiceManager(zkHotdogDeployment.zkHotdogServiceManager);
        
        // Verify the token directly
        vm.prank(contractOwner);
        zkHotdogNft.verifyToken(tokenId);
        
        // Try to create verification task for already verified token
        vm.prank(user.key.addr);
        vm.expectRevert("Token already verified");
        sm.createNewTask(tokenId, TEST_IMAGE_URL);
    }
}

contract RespondToTask is ZkHotdogTaskManagerSetup {
    using ECDSAUpgradeable for bytes32;

    uint256 internal constant INITIAL_BALANCE = 100 ether;
    uint256 internal constant DEPOSIT_AMOUNT = 1 ether;
    uint256 internal constant OPERATOR_COUNT = 4;

    IDelegationManager internal delegationManager;
    AVSDirectory internal avsDirectory;
    IZkHotdogServiceManager internal sm;
    ECDSAStakeRegistry internal stakeRegistry;
    uint256 internal tokenId;
    IZkHotdogServiceManager.Task internal task;
    uint32 internal taskIndex;

    function setUp() public override {
        super.setUp();

        delegationManager = IDelegationManager(coreDeployment.delegationManager);
        avsDirectory = AVSDirectory(coreDeployment.avsDirectory);
        sm = IZkHotdogServiceManager(zkHotdogDeployment.zkHotdogServiceManager);
        stakeRegistry = ECDSAStakeRegistry(zkHotdogDeployment.stakeRegistry);

        // Get current owner of NFT contract
        address contractOwner = zkHotdogNft.owner();
        
        // Set service manager in NFT using contract owner address
        vm.prank(contractOwner);
        zkHotdogNft.setServiceManager(zkHotdogDeployment.zkHotdogServiceManager);

        addStrategy(address(mockToken));

        while (operators.length < OPERATOR_COUNT) {
            createAndAddOperator();
        }

        for (uint256 i = 0; i < OPERATOR_COUNT; i++) {
            mintMockTokens(operators[i], INITIAL_BALANCE);
            depositTokenIntoStrategy(operators[i], address(mockToken), DEPOSIT_AMOUNT);
            registerAsOperator(operators[i]);
            registerOperatorToAVS(operators[i]);
        }
        
        // Update operator weights
        updateOperatorWeights(operators);
        
        // Mint an NFT and create a task to verify it
        tokenId = mintHotdogNFT(user);
        task = createVerificationTask(user, tokenId);
        taskIndex = sm.latestTaskNum() - 1;
    }

    function testRespondToTask() public {
        // Initially token should not be verified
        assertFalse(zkHotdogNft.isVerified(tokenId), "Token should not be verified initially");
        
        // Respond to task with verification result = true
        respondToTask(operators[0], task, taskIndex, true);
        
        // Check task response was recorded
        bytes memory response = sm.allTaskResponses(operators[0].key.addr, taskIndex);
        assertTrue(response.length > 0, "Task response not recorded");
        
        // Token should now be verified
        assertTrue(zkHotdogNft.isVerified(tokenId), "Token should be verified after response");
    }
    
    function testRespondToTaskWithNegativeResult() public {
        // Initially token should not be verified
        assertFalse(zkHotdogNft.isVerified(tokenId), "Token should not be verified initially");
        
        // Respond to task with verification result = false
        respondToTask(operators[0], task, taskIndex, false);
        
        // Check task response was recorded
        bytes memory response = sm.allTaskResponses(operators[0].key.addr, taskIndex);
        assertTrue(response.length > 0, "Task response not recorded");
        
        // Token should still not be verified
        assertFalse(zkHotdogNft.isVerified(tokenId), "Token should not be verified after negative result");
    }
    
    function testOnlyOperatorCanRespond() public {
        // Try to respond to task as non-operator
        bytes32 messageHash = keccak256(
            abi.encodePacked(
                "ZkHotdog Verification Task:",
                Strings.toString(task.tokenId),
                task.imageUrl,
                true ? "true" : "false"
            )
        );
        bytes32 ethSignedMessageHash = messageHash.toEthSignedMessageHash();
        
        // Create a fake signature with the user wallet
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(user.key.privateKey, ethSignedMessageHash);
        bytes memory signature = abi.encodePacked(r, s, v);
        
        // This should revert
        vm.prank(user.key.addr);
        vm.expectRevert("Caller must be a registered operator");
        sm.respondToTask(task, taskIndex, true, signature);
    }
    
    function testOperatorCannotRespondTwice() public {
        // Respond to task first time
        respondToTask(operators[0], task, taskIndex, true);
        
        // Create the message hash for second attempt
        bytes32 messageHash = keccak256(
            abi.encodePacked(
                "ZkHotdog Verification Task:",
                Strings.toString(task.tokenId),
                task.imageUrl,
                false ? "true" : "false"
            )
        );
        
        bytes32 ethSignedMessageHash = ECDSAUpgradeable.toEthSignedMessageHash(messageHash);
        
        // Create signature from signing key
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(operators[0].signingKey.privateKey, ethSignedMessageHash);
        bytes memory signature = abi.encodePacked(r, s, v);
        
        // Try to respond again
        vm.prank(operators[0].key.addr);
        vm.expectRevert("Operator has already responded to this task");
        sm.respondToTask(task, taskIndex, false, signature);
    }
}
