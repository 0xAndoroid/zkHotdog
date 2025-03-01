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
const provider = new ethers.JsonRpcProvider(process.env.RPC_URL!, undefined, { polling: true, pollingInterval: 500 });
const wallet = new ethers.Wallet(process.env.PRIVATE_KEY!, provider);
// Use chainId from env or default to 31337 (Anvil/Hardhat)
const chainId = Number(process.env.CHAIN_ID || '31337');

// Check for Cloudinary credentials
if (!process.env.CLOUDINARY_API_KEY || !process.env.CLOUDINARY_API_SECRET || !process.env.CLOUDINARY_CLOUD_NAME) {
  console.warn("⚠️ Some Cloudinary credentials not found in environment variables. Will fall back to base64 encoding for images.");
}

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
 * Upload an image to Cloudinary using API Key and Secret
 * @param imageBuffer Buffer containing the image data
 * @returns Promise resolving to the hosted image URL
 */
async function uploadImageToCloudinary(imageBuffer: Buffer): Promise<string> {
  try {
    // Required Cloudinary parameters
    const cloudName = process.env.CLOUDINARY_CLOUD_NAME;
    const apiKey = process.env.CLOUDINARY_API_KEY;
    const apiSecret = process.env.CLOUDINARY_API_SECRET;

    if (!cloudName || !apiKey || !apiSecret) {
      throw new Error('Missing Cloudinary credentials');
    }

    // Create a timestamp for the signature
    const timestamp = Math.floor(Date.now() / 1000).toString();

    // Create a unique file name to avoid collisions
    const fileName = `zkhotdog_${Date.now()}`;

    // For secure uploads with API secret we need to create a signature
    // The signature is a SHA-1 hash of the upload parameters and the API secret
    const crypto = require('crypto');
    const signatureString = `public_id=${fileName}&timestamp=${timestamp}${apiSecret}`;
    const signature = crypto.createHash('sha1').update(signatureString).digest('hex');

    // Prepare form data for the upload
    const formData = new FormData();
    formData.append('file', new Blob([imageBuffer]), 'image.jpg');
    formData.append('api_key', apiKey);
    formData.append('timestamp', timestamp);
    formData.append('public_id', fileName);
    formData.append('signature', signature);

    // Upload to Cloudinary
    const response = await axios.post(
      `https://api.cloudinary.com/v1_1/${cloudName}/image/upload`,
      formData,
      {
        headers: {
          'Content-Type': 'multipart/form-data'
        }
      }
    );

    if (response.data && response.data.secure_url) {
      console.log(`Image uploaded successfully to: ${response.data.secure_url}`);
      return response.data.secure_url;
    } else {
      throw new Error('Failed to get image URL from Cloudinary response');
    }
  } catch (error) {
    console.error('Error uploading image to Cloudinary:', error);
    throw error;
  }
}

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

    // Try to upload to Cloudinary if credentials are available
    let imageUrlForLLM = imageUrl;

    if (process.env.CLOUDINARY_API_KEY && process.env.CLOUDINARY_API_SECRET && process.env.CLOUDINARY_CLOUD_NAME) {
      try {
        // Upload to Cloudinary
        imageUrlForLLM = await uploadImageToCloudinary(Buffer.from(imageResponse.data));
        console.log(`Image hosted at: ${imageUrlForLLM}`);
      } catch (uploadError) {
        console.warn(`Failed to upload image to Cloudinary, falling back to base64: ${uploadError}`);
        // Fallback to base64 if upload fails
        imageUrlForLLM = `data:image/jpeg;base64,${Buffer.from(imageResponse.data).toString('base64')}`;
      }
    } else {
      // Fallback to base64 if Cloudinary is not configured
      console.log("Using base64 encoding for image (Cloudinary not configured)");
      imageUrlForLLM = `data:image/jpeg;base64,${Buffer.from(imageResponse.data).toString('base64')}`;
    }

    // Call LLM API with the hosted image URL or base64
    const response = await axios.post(
      'https://api.openai.com/v1/chat/completions',
      {
        model: 'gpt-4o',
        messages: [
          {
            role: 'user',
            content: [
              {
                type: 'text',
                text: 'Are red and green spheres located on the ends of measured objects in this image? This is a measurement verification request, please be very accurate. Please answer only "yes" or "no".'
              },
              {
                type: 'image_url',
                image_url: {
                  url: imageUrlForLLM
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

    return answer.includes('yes');
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
const signAndRespondToTask = async (taskIndex: number, tokenId: number, url: string, taskBlock: number) => {
  try {
    console.log(`Processing task ${taskIndex} for token ID ${tokenId}`);

    // Analyze the image
    const isValid = await analyzeImageWithLLM(url);
    console.log(`Verification result: ${isValid ? 'PASSED' : 'FAILED'}`);

    // Sign the message directly (ethers.js will prepend the Ethereum signed message prefix)
    const signature = await wallet.signMessage(ethers.getBytes(ethers.solidityPackedKeccak256(["string", "string", "string", "string"], ["ZkHotdog Verification Task:", tokenId.toString(), url, isValid ? "true" : "false"])));

    const operators = [await wallet.getAddress()];
    const signatures = [signature];
    const signedTask = ethers.AbiCoder.defaultAbiCoder().encode(
        ["address[]", "bytes[]", "uint32"],
        [operators, signatures, ethers.toBigInt(await provider.getBlockNumber()-1)]
    );
    
    console.log(`Signing and responding to task ${taskIndex}`);

    // Create the task object matching the struct in the contract
    const task = {
      tokenId: tokenId,
      imageUrl: url,
      taskCreatedBlock: taskBlock
    };

    // Submit response
    const tx = await zkHotdogServiceManager.respondToTask(
      task,
      taskIndex,
      isValid,
      signedTask
    );
    console.log("Responded to task pending");

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
  const expiry = Math.floor(Date.now() / 1000) + 360000; // Example expiry, 1 hour from now

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

  let filter = zkHotdogServiceManager.filters.NewTaskCreated();

  zkHotdogServiceManager.on(filter, async (event: any) => {
    let [taskIndex, [tokenId, url, taskBlock]] = event.args;
    await signAndRespondToTask(taskIndex, tokenId, url, taskBlock);
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
        // Get the task hash
        const taskHash = await zkHotdogServiceManager.allTaskHashes(i);

        // Only process tasks that haven't been responded to yet
        const hasResponded = (await zkHotdogServiceManager.allTaskResponses(wallet.address, i)).length > 0;
        if (hasResponded) {
          console.log(`Already responded to task ${i}, skipping...`);
          continue;
        }

        // Check if we can get task info from past events
        const filter = zkHotdogServiceManager.filters.NewTaskCreated(i);
        const events = await zkHotdogServiceManager.queryFilter(filter);

        if (events.length === 0) {
          console.log(`No event data found for task ${i}, skipping...`);
          continue;
        }

        // Extract task data from event - handling different event formats
        let taskData;
        const event = events[0];

        // Check if it's EventLog (has args) or Log (decoded manually)
        if ('args' in event && event.args) {
          taskData = event.args.task;
        } else {
          // Parse from the raw event data if args is not available
          const iface = zkHotdogServiceManager.interface;
          const parsedLog = iface.parseLog({
            topics: event.topics,
            data: event.data
          });
          taskData = parsedLog?.args?.task;
        }

        if (!taskData) {
          console.log(`Could not extract task data from event ${i}, skipping...`);
          continue;
        }

        await signAndRespondToTask(i, taskData.tokenId, taskData.imageUrl, taskData.taskCreatedBlock);
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
