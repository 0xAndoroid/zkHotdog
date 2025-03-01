#!/usr/bin/env node
/**
 * This script checks deployment files and contract ABIs
 * and prepares the environment for the operator agent
 */
const fs = require('fs');
const path = require('path');
const { ethers } = require('ethers');
require('dotenv').config();

// Get chainId from env or use default
const chainId = process.env.CHAIN_ID || '31337';

// Create directories
const dirs = [
  path.resolve(__dirname, '../foundry/deployments/zk-hotdog'),
  path.resolve(__dirname, '../foundry/deployments/core')
];

console.log("Checking and creating directories:");
dirs.forEach(dir => {
  if (!fs.existsSync(dir)) {
    console.log(`- Creating: ${dir}`);
    fs.mkdirSync(dir, { recursive: true });
  } else {
    console.log(`- Exists: ${dir}`);
  }
});

// Check ABI files (without copying)
const abiFiles = [
  '../foundry/out/IDelegationManager.sol/IDelegationManager.json',
  '../foundry/out/ECDSAStakeRegistry.sol/ECDSAStakeRegistry.json',
  '../foundry/out/ZkHotdogServiceManager.sol/ZkHotdogServiceManager.json',
  '../foundry/out/IAVSDirectory.sol/IAVSDirectory.json'
];

console.log("\nChecking ABI files:");
let abisExist = true;
abiFiles.forEach(file => {
  const srcPath = path.resolve(__dirname, file);
  
  if (fs.existsSync(srcPath)) {
    console.log(`- ABI exists: ${file}`);
  } else {
    console.log(`- Missing ABI: ${file}`);
    abisExist = false;
  }
});

if (!abisExist) {
  console.log("\nNot all ABIs are available. You need to compile contracts first:");
  console.log("cd ../foundry && forge build");
}

// Check deployment files
const deploymentFiles = [
  { path: `../foundry/deployments/zk-hotdog/${chainId}.json`, name: 'AVS Deployment' },
  { path: `../foundry/deployments/core/${chainId}.json`, name: 'Core Deployment' }
];

console.log("\nChecking deployment files:");
let deploymentFilesExist = true;
deploymentFiles.forEach(file => {
  const filePath = path.resolve(__dirname, file.path);
  if (fs.existsSync(filePath)) {
    console.log(`- ${file.name} exists: ${file.path}`);
  } else {
    console.log(`- ${file.name} missing: ${file.path}`);
    deploymentFilesExist = false;
  }
});

if (!deploymentFilesExist) {
  console.log("\nDeployment files missing. Run the deployment script:");
  console.log("cd ../foundry && forge script script/DeployAll.s.sol:DeployAll --rpc-url $RPC_URL --private-key $DEPLOYER_PRIVATE_KEY --broadcast");
}

// Check deployed contracts if .env has the addresses
async function checkDeployedContracts() {
  if (!process.env.RPC_URL || !process.env.PRIVATE_KEY) {
    console.log("\nMissing RPC_URL or PRIVATE_KEY in .env, skipping contract check");
    return;
  }

  try {
    // Setup connection
    const provider = new ethers.JsonRpcProvider(process.env.RPC_URL);
    const wallet = new ethers.Wallet(process.env.PRIVATE_KEY, provider);
    const operatorAddress = await wallet.getAddress();
    
    console.log("\nChecking deployed contracts:");
    console.log("Connected to network with chain ID:", (await provider.getNetwork()).chainId);
    console.log("Using operator address:", operatorAddress);
    
    // Determine addresses either from files or env vars
    let delegationManagerAddress, avsDirectoryAddress;
    let zkHotdogServiceManagerAddress, ecdsaStakeRegistryAddress;
    
    try {
      // Try reading from deployment files first
      const coreDeploymentPath = path.resolve(__dirname, `../foundry/deployments/core/${chainId}.json`);
      const avsDeploymentPath = path.resolve(__dirname, `../foundry/deployments/zk-hotdog/${chainId}.json`);
      
      if (fs.existsSync(coreDeploymentPath) && fs.existsSync(avsDeploymentPath)) {
        const coreDeployment = JSON.parse(fs.readFileSync(coreDeploymentPath, 'utf8'));
        const avsDeployment = JSON.parse(fs.readFileSync(avsDeploymentPath, 'utf8'));
        
        delegationManagerAddress = coreDeployment.addresses?.delegation;
        avsDirectoryAddress = coreDeployment.addresses?.avsDirectory;
        zkHotdogServiceManagerAddress = avsDeployment.addresses?.zkHotdogServiceManager;
        ecdsaStakeRegistryAddress = avsDeployment.addresses?.stakeRegistry;
        
        console.log("Using addresses from deployment files");
      }
    } catch (error) {
      console.log("Error reading deployment files:", error.message);
    }
    
    // Fall back to env vars if needed
    delegationManagerAddress = delegationManagerAddress || process.env.DELEGATION_MANAGER_ADDRESS;
    avsDirectoryAddress = avsDirectoryAddress || process.env.AVS_DIRECTORY_ADDRESS;
    zkHotdogServiceManagerAddress = zkHotdogServiceManagerAddress || process.env.SERVICE_MANAGER_ADDRESS;
    ecdsaStakeRegistryAddress = ecdsaStakeRegistryAddress || process.env.STAKE_REGISTRY_ADDRESS;
    
    console.log("\nContract addresses:");
    console.log("- Delegation Manager:", delegationManagerAddress);
    console.log("- AVS Directory:", avsDirectoryAddress);
    console.log("- ZkHotdog Service Manager:", zkHotdogServiceManagerAddress);
    console.log("- ECDSA Stake Registry:", ecdsaStakeRegistryAddress);
    
    // Check if code exists at these addresses
    console.log("\nChecking contract code:");
    for (const [name, address] of [
      ["Delegation Manager", delegationManagerAddress],
      ["AVS Directory", avsDirectoryAddress],
      ["ZkHotdog Service Manager", zkHotdogServiceManagerAddress],
      ["ECDSA Stake Registry", ecdsaStakeRegistryAddress]
    ]) {
      if (!address) {
        console.log(`${name}: Address not provided`);
        continue;
      }
      
      try {
        const code = await provider.getCode(address);
        console.log(`${name}: ${code === '0x' ? 'NO CODE FOUND' : 'Code exists'}`);
      } catch (error) {
        console.log(`${name}: Error checking code - ${error.message}`);
      }
    }
    
    // Minimal ABI for DelegationManager
    const delegationManagerABI = [
      "function isOperator(address operator) external view returns (bool)",
      "function isDelegated(address delegator) external view returns (bool)"
    ];
    
    if (delegationManagerAddress) {
      try {
        // Create contract instance
        const delegationManager = new ethers.Contract(
          delegationManagerAddress,
          delegationManagerABI,
          wallet
        );
        
        // Check if operator is already registered
        console.log("\nChecking operator status:");
        const isOperator = await delegationManager.isOperator(operatorAddress);
        console.log(`Is address ${operatorAddress} an operator? ${isOperator}`);
        
        // Check if operator is delegated to someone
        const isDelegated = await delegationManager.isDelegated(operatorAddress);
        console.log(`Is address ${operatorAddress} delegated to someone? ${isDelegated}`);
      } catch (error) {
        console.error("Error checking delegation manager:", error.message);
      }
    }
  } catch (error) {
    console.error("\nError connecting to provider:", error.message);
  }
}

// Run the main function
checkDeployedContracts()
  .then(() => process.exit(0))
  .catch(error => {
    console.error(error);
    process.exit(1);
  });
