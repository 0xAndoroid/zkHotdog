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
// Use chainId from env or default to 31337 (Anvil/Hardhat)
const chainId = Number(process.env.CHAIN_ID || '31337');

// Paths to deployment files
const avsDeploymentPath = path.resolve(__dirname, `../../foundry/deployments/zk-hotdog/${chainId}.json`);
const coreDeploymentPath = path.resolve(__dirname, `../../foundry/deployments/core/${chainId}.json`);

// Load deployment data
let avsDeploymentData: any;
let coreDeploymentData: any;

try {
  avsDeploymentData = JSON.parse(fs.readFileSync(avsDeploymentPath, 'utf8'));
  coreDeploymentData = JSON.parse(fs.readFileSync(coreDeploymentPath, 'utf8'));
} catch (error) {
  console.warn("Deployment data files not found. Using environment variables instead.");

  // Fall back to environment variables
  avsDeploymentData = {
    zkHotdogServiceManager: process.env.SERVICE_MANAGER_ADDRESS,
    stakeRegistry: process.env.STAKE_REGISTRY_ADDRESS
  };

  coreDeploymentData = {
    delegation: process.env.DELEGATION_MANAGER_ADDRESS,
    avsDirectory: process.env.AVS_DIRECTORY_ADDRESS
  };
}

// Contract addresses
const delegationManagerAddress = coreDeploymentData.delegation;
const avsDirectoryAddress = coreDeploymentData.avsDirectory;
const zkHotdogServiceManagerAddress = avsDeploymentData.zkHotdogServiceManager;
const ecdsaStakeRegistryAddress = avsDeploymentData.stakeRegistry;
const nftContractAddress = process.env.NFT_CONTRACT_ADDRESS;

// Load ABIs - try from local abis dir first, fallback to direct forge output
let delegationManagerABI, ecdsaRegistryABI, zkHotdogServiceManagerABI, avsDirectoryABI;

// Function to load ABI from build output files
function loadABI(abiName: string) {
  const possiblePaths = [

    path.resolve(__dirname, `../../foundry/out/${abiName.replace('I', '')}.sol/${abiName}.json`),
    path.resolve(__dirname, `../../foundry/out/${abiName}.sol/${abiName}.json`)
  ];

  for (const abiPath of possiblePaths) {
    try {
      if (fs.existsSync(abiPath)) {
        return JSON.parse(fs.readFileSync(abiPath, 'utf8'));
      }
    } catch (error) {
      console.warn(`Failed to load ABI from ${abiPath}:`, error);
    }
  }

  throw new Error(`Could not find ABI for ${abiName} in build output files`);
}


// Load ABIs - only from build output files
try {
  delegationManagerABI = loadABI('IDelegationManager');
  ecdsaRegistryABI = loadABI('ECDSAStakeRegistry');
  zkHotdogServiceManagerABI = loadABI('ZkHotdogServiceManager');
  avsDirectoryABI = loadABI('IAVSDirectory');
} catch (error) {
  console.error('Failed to load ABIs from build output:', error);
  process.exit(1);
}

// Initialize contract instances
const delegationManager = new ethers.Contract(delegationManagerAddress, delegationManagerABI.abi, wallet);
const zkHotdogServiceManager = new ethers.Contract(zkHotdogServiceManagerAddress, zkHotdogServiceManagerABI.abi, wallet);
const ecdsaRegistryContract = new ethers.Contract(ecdsaStakeRegistryAddress, ecdsaRegistryABI.abi, wallet);
const avsDirectory = new ethers.Contract(avsDirectoryAddress, avsDirectoryABI.abi, wallet);

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
                text: 'Are red spheres located on the ends of measured objects in this image? Please answer only "yes" or "no".'
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

  // Registers as an Operator in EigenLayer.
  try {
    const tx1 = await delegationManager.registerAsOperator({
      __deprecated_earningsReceiver: await wallet.address,
      delegationApprover: "0x0000000000000000000000000000000000000000",
      stakerOptOutWindowBlocks: 0
    }, "");
    await tx1.wait();
    console.log("Operator registered to Core EigenLayer contracts");
  } catch (error) {
    console.error("Error in registering as operator:", error);
  }

  const salt = ethers.hexlify(ethers.randomBytes(32));
  const expiry = Math.floor(Date.now() / 1000) + 3600; // Example expiry, 1 hour from now

  // Define the output structure
  let operatorSignatureWithSaltAndExpiry = {
    signature: "",
    salt: salt,
    expiry: expiry
  };

  // Calculate the digest hash, which is a unique value representing the operator, avs, unique value (salt) and expiration date.
  const operatorDigestHash = await avsDirectory.calculateOperatorAVSRegistrationDigestHash(
    wallet.address,
    await zkHotdogServiceManager.getAddress(),
    salt,
    expiry
  );
  console.log(operatorDigestHash);

  // Sign the digest hash with the operator's private key
  console.log("Signing digest hash with operator's private key");
  const operatorSigningKey = new ethers.SigningKey(process.env.PRIVATE_KEY!);
  const operatorSignedDigestHash = operatorSigningKey.sign(operatorDigestHash);

  // Encode the signature in the required format
  operatorSignatureWithSaltAndExpiry.signature = ethers.Signature.from(operatorSignedDigestHash).serialized;

  console.log("Registering Operator to AVS Registry contract");

  // Register Operator to AVS
  // Per release here: https://github.com/Layr-Labs/eigenlayer-middleware/blob/v0.2.1-mainnet-rewards/src/unaudited/ECDSAStakeRegistry.sol#L49
  const tx2 = await ecdsaRegistryContract.registerOperatorWithSignature(
    operatorSignatureWithSaltAndExpiry,
    wallet.address
  );
  await tx2.wait();
  console.log("Operator registered on AVS successfully");
};
;

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
