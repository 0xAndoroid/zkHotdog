import { ethers } from "ethers";
import * as dotenv from "dotenv";
import * as fs from 'fs';
import * as path from 'path';
import axios from 'axios';

dotenv.config();

// Check if the process.env object is empty
if (!Object.keys(process.env).length) {
  throw new Error("process.env object is empty");
}

// Setup env variables
const provider = new ethers.JsonRpcProvider(process.env.RPC_URL);
const wallet = new ethers.Wallet(process.env.PRIVATE_KEY!, provider);
const chainId = Number(process.env.CHAIN_ID || '31337');

// Paths to deployment files
const avsDeploymentPath = path.resolve(__dirname, `../foundry/deployments/zk-hotdog/${chainId}.json`);
const coreDeploymentPath = path.resolve(__dirname, `../foundry/deployments/core/${chainId}.json`);

// Load deployment data (will need to create these files with proper addresses)
let avsDeploymentData: any;
let coreDeploymentData: any;

try {
  avsDeploymentData = JSON.parse(fs.readFileSync(avsDeploymentPath, 'utf8'));
  coreDeploymentData = JSON.parse(fs.readFileSync(coreDeploymentPath, 'utf8'));
} catch (error) {
  console.warn("Deployment data files not found. Using environment variables instead.");
  
  // Fall back to environment variables
  avsDeploymentData = {
    addresses: {
      zkHotdogServiceManager: process.env.SERVICE_MANAGER_ADDRESS,
      stakeRegistry: process.env.STAKE_REGISTRY_ADDRESS
    }
  };
  
  coreDeploymentData = {
    addresses: {
      delegation: process.env.DELEGATION_MANAGER_ADDRESS,
      avsDirectory: process.env.AVS_DIRECTORY_ADDRESS
    }
  };
}

// Contract addresses
const delegationManagerAddress = coreDeploymentData.addresses.delegation;
const avsDirectoryAddress = coreDeploymentData.addresses.avsDirectory;
const zkHotdogServiceManagerAddress = avsDeploymentData.addresses.zkHotdogServiceManager;
const ecdsaStakeRegistryAddress = avsDeploymentData.addresses.stakeRegistry;
const nftContractAddress = process.env.NFT_CONTRACT_ADDRESS;

// ABIs (simplified - in a real implementation, you would load complete ABIs from files)
const delegationManagerABI = [
  "function registerAsOperator(tuple(__deprecated_earningsReceiver address, delegationApprover address, stakerOptOutWindowBlocks uint256), string memory)",
];

const ecdsaRegistryABI = [
  "function registerOperatorWithSignature(tuple(bytes signature, bytes32 salt, uint256 expiry), address operatorAddress)",
];

const zkHotdogServiceManagerABI = [
  "function createNewTask(uint256 tokenId, string memory imageUrl) external returns (tuple(uint256 tokenId, string imageUrl, uint32 taskCreatedBlock))",
  "function respondToTask(tuple(uint256 tokenId, string imageUrl, uint32 taskCreatedBlock) calldata task, uint32 referenceTaskIndex, bool result, bytes calldata signature) external",
  "function latestTaskNum() external view returns (uint32)",
  "event NewTaskCreated(uint32 indexed taskIndex, tuple(uint256 tokenId, string imageUrl, uint32 taskCreatedBlock) task)"
];

const avsDirectoryABI = [
  "function calculateOperatorAVSRegistrationDigestHash(address operator, address avs, bytes32 salt, uint256 expiry) external view returns (bytes32)",
];

// Initialize contract instances
const delegationManager = new ethers.Contract(delegationManagerAddress, delegationManagerABI, wallet);
const zkHotdogServiceManager = new ethers.Contract(zkHotdogServiceManagerAddress, zkHotdogServiceManagerABI, wallet);
const ecdsaRegistryContract = new ethers.Contract(ecdsaStakeRegistryAddress, ecdsaRegistryABI, wallet);
const avsDirectory = new ethers.Contract(avsDirectoryAddress, avsDirectoryABI, wallet);

/**
 * Analyze image with LLM to check if red dots are located on the ends of measured objects
 * @param imageUrl URL to the image file
 * @returns Promise resolving to true if validation passes, false otherwise
 */
async function analyzeImageWithLLM(imageUrl: string): Promise<boolean> {
  try {
    console.log(`Analyzing image at ${imageUrl} with LLM...`);
    
    // Download the image
    const imageResponse = await axios.get(imageUrl, {
      responseType: 'arraybuffer'
    });
    
    // Convert image to base64
    const base64Image = Buffer.from(imageResponse.data).toString('base64');
    
    // Call LLM API (OpenAI's example here)
    const response = await axios.post(
      'https://api.openai.com/v1/chat/completions',
      {
        model: 'gpt-4-vision-preview',
        messages: [
          {
            role: 'user',
            content: [
              { 
                type: 'text', 
                text: 'Are red dots located on the ends of measured objects in this image? Please answer only "yes" or "no".' 
              },
              {
                type: 'image_url',
                image_url: {
                  url: `data:image/jpeg;base64,${base64Image}`
                }
              }
            ]
          }
        ],
        max_tokens: 10
      },
      {
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${process.env.OPENAI_API_KEY}`
        }
      }
    );
    
    // Extract answer from response
    const answer = response.data.choices[0].message.content.toLowerCase().trim();
    console.log(`LLM response: ${answer}`);
    
    return answer === 'yes';
  } catch (error) {
    console.error('Error analyzing image with LLM:', error);
    return false;
  }
}

/**
 * Sign and respond to a task
 * @param taskIndex The index of the task
 * @param task The task data
 */
const signAndRespondToTask = async (taskIndex: number, task: any) => {
  try {
    console.log(`Processing task ${taskIndex} for token ID ${task.tokenId}`);

    // Analyze the image
    const isValid = await analyzeImageWithLLM(task.imageUrl);
    console.log(`Verification result: ${isValid ? 'PASSED' : 'FAILED'}`);

    // Create message to sign
    const message = `ZkHotdog Verification Task:${task.tokenId}${task.imageUrl}${isValid ? 'true' : 'false'}`;
    const messageHash = ethers.solidityPackedKeccak256(["string"], [message]);
    const messageBytes = ethers.getBytes(messageHash);
    
    // Sign the message
    const signature = await wallet.signMessage(messageBytes);
    console.log(`Signing and responding to task ${taskIndex}`);

    // Submit response
    const tx = await zkHotdogServiceManager.respondToTask(
      { 
        tokenId: task.tokenId, 
        imageUrl: task.imageUrl, 
        taskCreatedBlock: task.taskCreatedBlock 
      },
      taskIndex,
      isValid,
      signature
    );
    
    await tx.wait();
    console.log(`Responded to task ${taskIndex} with result: ${isValid}`);
  } catch (error) {
    console.error(`Error in processing task ${taskIndex}:`, error);
  }
};

/**
 * Register as an operator
 */
const registerOperator = async () => {
  try {
    // Register as an Operator in EigenLayer
    console.log("Registering as an operator in EigenLayer...");
    try {
      const tx1 = await delegationManager.registerAsOperator({
        __deprecated_earningsReceiver: await wallet.getAddress(),
        delegationApprover: "0x0000000000000000000000000000000000000000",
        stakerOptOutWindowBlocks: 0
      }, "");
      await tx1.wait();
      console.log("Operator registered to Core EigenLayer contracts");
    } catch (error: any) {
      if (error.toString().includes("already registered")) {
        console.log("Operator already registered to Core EigenLayer contracts");
      } else {
        console.error("Error in registering as operator:", error);
        throw error;
      }
    }
    
    // Register with AVS
    const salt = ethers.randomBytes(32);
    const expiry = Math.floor(Date.now() / 1000) + 86400; // 24 hours from now

    // Define the output structure
    const operatorSignatureWithSaltAndExpiry = {
      signature: "",
      salt: salt,
      expiry: expiry
    };

    // Calculate the digest hash
    const operatorDigestHash = await avsDirectory.calculateOperatorAVSRegistrationDigestHash(
      wallet.getAddress(), 
      zkHotdogServiceManagerAddress, 
      salt, 
      expiry
    );
    
    // Sign the digest hash with the operator's private key
    console.log("Signing digest hash with operator's private key");
    const operatorSignature = await wallet.signMessage(ethers.getBytes(operatorDigestHash));
    operatorSignatureWithSaltAndExpiry.signature = operatorSignature;

    console.log("Registering Operator to AVS Registry contract");
    
    // Register Operator to AVS
    try {
      const tx2 = await ecdsaRegistryContract.registerOperatorWithSignature(
        operatorSignatureWithSaltAndExpiry,
        wallet.getAddress()
      );
      await tx2.wait();
      console.log("Operator registered on AVS successfully");
    } catch (error: any) {
      if (error.toString().includes("already registered")) {
        console.log("Operator already registered to AVS");
      } else {
        console.error("Error in registering with AVS:", error);
        throw error;
      }
    }
  } catch (error) {
    console.error("Error in registering as operator:", error);
    throw error;
  }
};

/**
 * Monitor for new tasks
 */
const monitorNewTasks = async () => {
  console.log("Monitoring for new tasks...");
  
  zkHotdogServiceManager.on("NewTaskCreated", async (taskIndex: number, task: any) => {
    console.log(`New task detected: Index ${taskIndex}, Token ID ${task.tokenId}`);
    await signAndRespondToTask(taskIndex, task);
  });
};

/**
 * Process existing tasks that haven't been responded to
 */
const processExistingTasks = async () => {
  try {
    const latestTaskNum = Number(await zkHotdogServiceManager.latestTaskNum());
    console.log(`Checking ${latestTaskNum} existing tasks...`);
    
    // Process last 10 tasks or all tasks if fewer than 10
    const startTask = Math.max(0, latestTaskNum - 10);
    
    for (let i = startTask; i < latestTaskNum; i++) {
      try {
        // Fetch task details (this would require additional contract methods in a real implementation)
        // Here we're simulating this by just creating a dummy task
        const task = {
          tokenId: i + 1000, // Dummy token ID
          imageUrl: process.env.TEST_IMAGE_URL || "https://example.com/test.jpg",
          taskCreatedBlock: await provider.getBlockNumber() - 10
        };
        
        await signAndRespondToTask(i, task);
      } catch (error) {
        console.error(`Error processing task ${i}:`, error);
        // Continue with next task
      }
    }
  } catch (error) {
    console.error("Error processing existing tasks:", error);
  }
};

/**
 * Main function
 */
const main = async () => {
  try {
    await registerOperator();
    await processExistingTasks();
    await monitorNewTasks();
    
    // Keep the process running
    console.log("Operator agent running. Press Ctrl+C to exit.");
  } catch (error) {
    console.error("Error in main function:", error);
    process.exit(1);
  }
};

// Run the main function
if (require.main === module) {
  main().catch(error => {
    console.error("Unhandled error:", error);
    process.exit(1);
  });
}

export { registerOperator, monitorNewTasks, signAndRespondToTask };