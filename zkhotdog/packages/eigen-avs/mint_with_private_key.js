// Script to mint a zkHotdog NFT using a private key
// Usage: node mint_with_private_key.js <privateKey> <proofUuid>

const { ethers } = require('ethers');
const dotenv = require('dotenv');
const path = require('path');
const axios = require('axios');

// Load environment variables from .env file
dotenv.config({ path: path.resolve(__dirname, '../../.env.local') });
dotenv.config({ path: path.resolve(__dirname, './.env') });

// NFT Contract ABI for attestation-based minting
const zkHotdogAbi = [
  {
    inputs: [
      { internalType: "string", name: "imageUrl", type: "string" },
      { internalType: "uint256", name: "lengthInCm", type: "uint256" },
      { internalType: "uint256", name: "_attestationId", type: "uint256" },
      { internalType: "bytes32[]", name: "_merklePath", type: "bytes32[]" },
      { internalType: "uint256", name: "_leafCount", type: "uint256" },
      { internalType: "uint256", name: "_index", type: "uint256" },
    ],
    name: "mintWithAttestation",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
];

// Get environment variables
const ZK_HOTDOG_CONTRACT_ADDRESS = process.env.NEXT_PUBLIC_ZK_HOTDOG_CONTRACT_ADDRESS || "0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512";
const API_BASE_URL = process.env.NEXT_PUBLIC_API_BASE_URL || "http://localhost:3001";
const RPC_URL = process.env.NEXT_PUBLIC_RPC_URL || "http://localhost:8545";

// Extended ABI to include HotdogMinted event
const zkHotdogFullAbi = [
  ...zkHotdogAbi,
  {
    anonymous: false,
    inputs: [
      { indexed: true, internalType: "address", name: "to", type: "address" },
      { indexed: true, internalType: "uint256", name: "tokenId", type: "uint256" },
      { indexed: false, internalType: "string", name: "imageUrl", type: "string" },
      { indexed: false, internalType: "uint256", name: "lengthInCm", type: "uint256" }
    ],
    name: "HotdogMinted",
    type: "event"
  }
];

async function main() {
  try {
    // Get command line arguments
    const args = process.argv.slice(2);
    
    if (args.length < 2) {
      console.error('Usage: node mint_with_private_key.js <privateKey> <proofUuid>');
      process.exit(1);
    }
    
    const privateKey = args[0];
    const proofUuid = args[1];
    
    console.log(`Using contract address: ${ZK_HOTDOG_CONTRACT_ADDRESS}`);
    console.log(`Using API base URL: ${API_BASE_URL}`);
    console.log(`Using RPC URL: ${RPC_URL}`);
    
    // Validate contract address
    if (!ZK_HOTDOG_CONTRACT_ADDRESS || ZK_HOTDOG_CONTRACT_ADDRESS === "0x0000000000000000000000000000000000000000") {
      console.error("ZK_HOTDOG_CONTRACT_ADDRESS not configured correctly");
      process.exit(1);
    }
    
    // Create provider and wallet
    const provider = new ethers.JsonRpcProvider(RPC_URL);
    const wallet = new ethers.Wallet(privateKey, provider);
    console.log(`Using wallet address: ${wallet.address}`);
    
    // Check if wallet has ETH
    const balance = await provider.getBalance(wallet.address);
    console.log(`Wallet balance: ${ethers.formatEther(balance)} ETH`);
    
    if (balance === 0n) {
      console.error("Wallet has no ETH to pay for gas. Please fund the wallet first.");
      process.exit(1);
    }
    
    // Check contract details
    try {
      const code = await provider.getCode(ZK_HOTDOG_CONTRACT_ADDRESS);
      if (code === '0x') {
        console.error(`No contract deployed at ${ZK_HOTDOG_CONTRACT_ADDRESS}`);
        process.exit(1);
      }
      console.log(`Contract exists at ${ZK_HOTDOG_CONTRACT_ADDRESS} (code length: ${(code.length - 2) / 2} bytes)`);
      
      // Create a read-only contract instance for checking
      const readContract = new ethers.Contract(ZK_HOTDOG_CONTRACT_ADDRESS, [
        "function zkVerify() view returns (address)",
        "function serviceManager() view returns (address)"
      ], provider);
      
      // Check contract configuration
      try {
        const zkVerifyAddress = await readContract.zkVerify();
        console.log(`ZkVerify address: ${zkVerifyAddress}`);
        
        const serviceManagerAddress = await readContract.serviceManager();
        console.log(`ServiceManager address: ${serviceManagerAddress}`);
        
        if (serviceManagerAddress === '0x0000000000000000000000000000000000000000') {
          console.log("\n⚠️ WARNING: serviceManager is not set in the contract!");
          console.log("This transaction may revert because the ServiceManager is required for NFT minting.\n");
        }
      } catch (err) {
        console.log("Could not check contract configuration:", err.message);
      }
    } catch (err) {
      console.error("Error checking contract:", err.message);
    }
    
    // Fetch proof status from the backend
    console.log(`Fetching proof status for UUID: ${proofUuid}...`);
    const response = await axios.get(`${API_BASE_URL}/status/${proofUuid}`);
    const measurement = response.data;
    
    if (!measurement) {
      console.error('Measurement not found');
      process.exit(1);
    }
    
    console.log(`Measurement status: ${measurement.status}`);
    
    // Validate proof status
    if (measurement.status !== "Completed") {
      console.error('Cannot mint: Proof is not completed yet');
      process.exit(1);
    }
    
    // Validate attestation data
    if (!measurement.attestation) {
      console.error('Attestation data missing. Cannot mint without verification.');
      process.exit(1);
    }
    
    // Calculate length in cm based on the 3D points
    const dx = measurement.end_point.x - measurement.start_point.x;
    const dy = measurement.end_point.y - measurement.start_point.y;
    const dz = measurement.end_point.z - measurement.start_point.z;
    const lengthInCm = Math.floor(dx * dx + dy * dy + dz * dz); // Convert to cm
    
    // Create image URL by referencing the backend
    const imageUrl = `${API_BASE_URL}/img/${measurement.id}`;
    
    // Get attestation data
    const { attestationId, merklePath, leafCount, index } = measurement.attestation;
    
    if (!Array.isArray(merklePath) || merklePath.length === 0) {
      console.error('Invalid merkle path data in attestation');
      process.exit(1);
    }
    
    // Validate each merkle path is properly formatted as hex
    const merklePathBytes32 = merklePath.map(path => {
      if (typeof path !== "string" || !path.startsWith("0x")) {
        throw new Error(`Invalid merkle path format: ${path}`);
      }
      return path;
    });
    
    console.log('Minting parameters:');
    console.log(`- Image URL: ${imageUrl}`);
    console.log(`- Length (cm): ${lengthInCm}`);
    console.log(`- Attestation ID: ${attestationId}`);
    console.log(`- Merkle Path (count): ${merklePathBytes32.length}`);
    console.log(`- Leaf Count: ${leafCount}`);
    console.log(`- Index: ${index}`);
    
    // Create contract instance
    const contract = new ethers.Contract(ZK_HOTDOG_CONTRACT_ADDRESS, zkHotdogAbi, wallet);
    
    // Get current gas price
    const gasPrice = await provider.getFeeData();
    
    console.log('Sending transaction...');
    // Try to call static first to check for errors
    try {
      await contract.mintWithAttestation.staticCall(
        imageUrl,
        BigInt(lengthInCm),
        BigInt(attestationId),
        merklePathBytes32,
        BigInt(leafCount),
        BigInt(index)
      );
      console.log("Static call successful - transaction should succeed");
    } catch (staticError) {
      console.error("Static call failed with error:", staticError?.message || staticError);
      
      // Get detailed error data if available
      if (staticError.data) {
        try {
          // Use custom error decoding if possible
          const errorData = staticError.data;
          console.log("\nDetailed error data:", errorData);
        } catch (decodeError) {
          console.log("Could not decode error data:", staticError.data);
        }
      }
      
      // Check error message for clues
      const errorMsg = staticError?.message || String(staticError);
      
      if (errorMsg.includes("Invalid attestation proof")) {
        console.log("\n⚠️ ERROR: The attestation proof verification failed. This could mean the proof data is incorrect.");
      } else if (errorMsg.includes("Token already verified")) {
        console.log("\n⚠️ ERROR: This token has already been verified.");
      } else if (errorMsg.includes("ownerOf")) {
        console.log("\n⚠️ ERROR: Problem with token ownership check. The token ID might not exist yet.");
      }
      
      console.log("\nAttempting transaction anyway...");
    }
    
    // Try debug trace to get more detailed information
    try {
      console.log("Attempting debug trace of transaction...");
      
      // Create a low-level transaction object for debugging
      const txData = await contract.mintWithAttestation.populateTransaction(
        imageUrl,
        BigInt(lengthInCm),
        BigInt(attestationId),
        merklePathBytes32,
        BigInt(leafCount),
        BigInt(index)
      );
      
      // Try to get debug trace using eth_call with extra parameters (hardhat/anvil feature)
      const debugResult = await provider.send("eth_call", [
        {
          from: wallet.address,
          to: txData.to, 
          data: txData.data,
          gas: "0x" + (3000000).toString(16)
        },
        "latest",
        { 
          disableMaxFeePerGas: true,
          debug: true,
          disableEstimate: true
        }
      ]);
      
      console.log("Debug call result:", debugResult);
    } catch (debugError) {
      console.log("Debug trace failed or not supported:", debugError.message);
    }
    
    console.log("Proceeding with actual transaction...");
    
    // Execute the minting transaction
    const tx = await contract.mintWithAttestation(
      imageUrl,
      BigInt(lengthInCm),
      BigInt(attestationId),
      merklePathBytes32,
      BigInt(leafCount),
      BigInt(index),
      {
        gasLimit: 3000000, // Increased gas limit
        maxFeePerGas: gasPrice.maxFeePerGas,
        maxPriorityFeePerGas: gasPrice.maxPriorityFeePerGas
      }
    );
    
    console.log(`Transaction submitted: ${tx.hash}`);
    console.log('Waiting for transaction confirmation...');
    
    // Wait for the transaction to be mined
    const receipt = await tx.wait();
    
    console.log(`Transaction confirmed in block ${receipt.blockNumber}`);
    console.log(`Gas used: ${receipt.gasUsed.toString()}`);
    
    // Find the HotdogMinted event
    const contractInterface = new ethers.Interface(zkHotdogFullAbi);
    const hotdogMintedEvent = receipt.logs
      .map(log => {
        try {
          return contractInterface.parseLog({ topics: log.topics, data: log.data });
        } catch (e) {
          return null;
        }
      })
      .filter(Boolean)
      .find(log => log.name === 'HotdogMinted');
    
    if (hotdogMintedEvent) {
      console.log(`NFT minted successfully with token ID: ${hotdogMintedEvent.args.tokenId}`);
    } else {
      console.log('NFT minted successfully, but could not parse token ID from event logs');
    }
    
  } catch (error) {
    console.error('Error during minting:', error.message || error);
    
    if (error.data) {
      console.log('\nDetailed error data:', error.data);
    }
    
    if (error.receipt) {
      console.log('\nTransaction receipt:');
      console.log('- Status:', error.receipt.status);
      console.log('- Gas used:', error.receipt.gasUsed.toString());
      console.log('- Block number:', error.receipt.blockNumber);
    }
    
    // Check for common error patterns
    const errorMsg = error.message || String(error);
    
    if (errorMsg.includes("execution reverted")) {
      console.log("\nTransaction reverted by the contract. This might be because:");
      console.log("1. The verification proof data is incorrect or invalid");
      console.log("2. The service manager might not be properly configured to handle the task creation");
      console.log("3. The contract might have insufficient permissions");
      console.log("\nCheck contract logs for more details.");
    }
    
    process.exit(1);
  }
}

main();
