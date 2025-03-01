// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ECDSAServiceManagerBase} from "@eigenlayer-middleware/src/unaudited/ECDSAServiceManagerBase.sol";
import {ECDSAStakeRegistry} from "@eigenlayer-middleware/src/unaudited/ECDSAStakeRegistry.sol";
import {IServiceManager} from "@eigenlayer-middleware/src/interfaces/IServiceManager.sol";
import {ECDSAUpgradeable} from "@openzeppelin-upgrades/contracts/utils/cryptography/ECDSAUpgradeable.sol";
import {IERC1271Upgradeable} from "@openzeppelin-upgrades/contracts/interfaces/IERC1271Upgradeable.sol";
import "./IZkHotdogServiceManager.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import {IRewardsCoordinator} from "@eigenlayer/contracts/interfaces/IRewardsCoordinator.sol";
import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "./ZkHotdog.sol";

/**
 * @title ZkHotdog EigenLayer AVS Service Manager
 * @dev Primary entrypoint for procuring services from ZkHotdog AVS
 */
contract ZkHotdogServiceManager is
    ECDSAServiceManagerBase,
    IZkHotdogServiceManager
{
    using ECDSAUpgradeable for bytes32;

    // Latest task number
    uint32 public latestTaskNum;

    // ZkHotdog NFT contract
    ZkHotdog public zkHotdogNft;

    // Mapping of task indices to all tasks hashes
    mapping(uint32 => bytes32) public allTaskHashes;

    // Mapping of operator addresses to task indices to response data
    mapping(address => mapping(uint32 => bytes)) public allTaskResponses;

    // Mapping of task indices to verification results
    mapping(uint32 => bool) public taskVerificationResults;

    // Modifier to restrict function access to registered operators
    modifier onlyOperator() {
        require(
            ECDSAStakeRegistry(stakeRegistry).operatorRegistered(msg.sender),
            "Caller must be a registered operator"
        );
        _;
    }

    /**
     * @dev Constructor
     * @param _avsDirectory EigenLayer AVS Directory
     * @param _stakeRegistry EigenLayer Stake Registry
     * @param _rewardsCoordinator EigenLayer Rewards Coordinator
     * @param _delegationManager EigenLayer Delegation Manager
     */
    constructor(
        address _avsDirectory,
        address _stakeRegistry,
        address _rewardsCoordinator,
        address _delegationManager
    )
        ECDSAServiceManagerBase(
            _avsDirectory,
            _stakeRegistry,
            _rewardsCoordinator,
            _delegationManager
        )
    {}

    /**
     * @dev Initialize the service manager
     * @param initialOwner Initial owner address
     * @param _rewardsInitiator Rewards initiator address
     * @param _zkHotdogNft ZkHotdog NFT contract address
     */
    function initialize(
        address initialOwner,
        address _rewardsInitiator,
        address _zkHotdogNft
    ) external initializer {
        __ServiceManagerBase_init(initialOwner, _rewardsInitiator);
        zkHotdogNft = ZkHotdog(_zkHotdogNft);
    }

    /**
     * @dev Creates a new task for image verification
     * @param tokenId The token ID to verify
     * @param imageUrl The URL of the image to verify
     * @return newTask The created task
     */
    function createNewTask(
        uint256 tokenId,
        string memory imageUrl
    ) external returns (Task memory) {
        // zkHotdogNft.ownerOf(tokenId);
        require(!zkHotdogNft.isVerified(tokenId), "Token already verified");

        // Create a new task
        Task memory newTask;
        newTask.tokenId = tokenId;
        newTask.imageUrl = imageUrl;
        newTask.taskCreatedBlock = uint32(block.number);

        // Store hash of task on-chain
        allTaskHashes[latestTaskNum] = keccak256(abi.encode(newTask));

        // Emit event and increment task number
        emit NewTaskCreated(latestTaskNum, newTask);
        latestTaskNum = latestTaskNum + 1;

        return newTask;
    }

    /**
     * @dev Responds to a task with verification result
     * @param task The task that is being responded to
     * @param referenceTaskIndex The index of the task
     * @param result The verification result (true if red dots are on the ends of measured objects)
     * @param signature The signature proving operator's authorization
     */
    function respondToTask(
        Task calldata task,
        uint32 referenceTaskIndex,
        bool result,
        bytes calldata signature
    ) external onlyOperator {
        // Check that the task is valid and hasn't been responded to yet
        require(
            keccak256(abi.encode(task)) == allTaskHashes[referenceTaskIndex],
            "Task does not match the one recorded in the contract"
        );
        require(
            allTaskResponses[msg.sender][referenceTaskIndex].length == 0,
            "Operator has already responded to this task"
        );

        // Create and verify the message hash
        bytes32 messageHash = keccak256(
            abi.encodePacked(
                "ZkHotdog Verification Task:",
                Strings.toString(task.tokenId),
                task.imageUrl,
                result ? "true" : "false"
            )
        );
        bytes32 ethSignedMessageHash = messageHash.toEthSignedMessageHash();

        // Verify signature using EigenLayer's stake registry
        bytes4 magicValue = IERC1271Upgradeable.isValidSignature.selector;
        bytes4 isValidSignatureResult = ECDSAStakeRegistry(stakeRegistry)
            .isValidSignature(ethSignedMessageHash, signature);

        require(magicValue == isValidSignatureResult, "Invalid signature");

        // Store task response
        allTaskResponses[msg.sender][referenceTaskIndex] = abi.encode(
            result,
            signature
        );
        taskVerificationResults[referenceTaskIndex] = result;

        // If verification was successful, update the NFT contract
        if (result) {
            try zkHotdogNft.verifyToken(task.tokenId) {
                // Successfully verified the token
            } catch {
                // Verification failed in the NFT contract
            }
        }

        // Emit event
        emit TaskResponded(referenceTaskIndex, task, msg.sender, result);
    }

    /**
     * @dev Update the zkHotdog NFT contract address
     * @param _zkHotdogNft New ZkHotdog NFT contract address
     */
    function updateZkHotdogNft(address _zkHotdogNft) external onlyOwner {
        require(_zkHotdogNft != address(0), "Invalid address");
        zkHotdogNft = ZkHotdog(_zkHotdogNft);
    }
}
