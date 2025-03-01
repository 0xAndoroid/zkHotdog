// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IZkHotdogServiceManager
 * @dev Interface for ZkHotdog EigenLayer AVS Service Manager
 */
interface IZkHotdogServiceManager {
    // Events
    event NewTaskCreated(uint32 indexed taskIndex, Task task);
    event TaskResponded(
        uint32 indexed taskIndex,
        Task task,
        address operator,
        bool result
    );

    // Struct representing an image verification task
    struct Task {
        uint256 tokenId;
        string imageUrl;
        uint32 taskCreatedBlock;
    }

    /**
     * @dev Returns the latest task number
     */
    function latestTaskNum() external view returns (uint32);

    /**
     * @dev Returns the hash of a task at the given index
     * @param taskIndex The index of the task
     */
    function allTaskHashes(uint32 taskIndex) external view returns (bytes32);

    /**
     * @dev Returns the response for a task from an operator
     * @param operator The address of the operator
     * @param taskIndex The index of the task
     */
    function allTaskResponses(
        address operator,
        uint32 taskIndex
    ) external view returns (bytes memory);

    /**
     * @dev Creates a new task for image verification
     * @param tokenId The token ID to verify
     * @param imageUrl The URL of the image to verify
     * @return newTask The created task
     */
    function createNewTask(
        uint256 tokenId,
        string memory imageUrl
    ) external returns (Task memory);

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
    ) external;
}

