const { ethers } = require('ethers');
require('dotenv').config();

async function main() {
  console.log("Starting EigenLayer operator registration...");

  // Setup connection
  const provider = new ethers.JsonRpcProvider(process.env.RPC_URL);
  const wallet = new ethers.Wallet(process.env.PRIVATE_KEY, provider);
  const operatorAddress = wallet.address;
  
  console.log(`Operator address: ${operatorAddress}`);

  // DelegationManager address from environment or deployment files
  const delegationManagerAddress = process.env.DELEGATION_MANAGER_ADDRESS;
  console.log(`DelegationManager address: ${delegationManagerAddress}`);

  // Minimal DelegationManager ABI 
  const delegationManagerABI = [
    "function registerAsOperator((address, address, uint256), string) external",
    "function isOperator(address) external view returns (bool)"
  ];

  // Create contract instance
  const delegationManager = new ethers.Contract(
    delegationManagerAddress,
    delegationManagerABI,
    wallet
  );

  try {
    // Check if already registered
    const isOperator = await delegationManager.isOperator(operatorAddress);
    console.log(`Is already registered as operator? ${isOperator}`);
    
    if (isOperator) {
      console.log("Already registered as operator. Nothing to do.");
      return;
    }

    // Register as operator
    console.log("Registering as operator...");
    const tx = await delegationManager.registerAsOperator(
      [
        operatorAddress, // earnings receiver (deprecated but required)
        "0x0000000000000000000000000000000000000000", // delegation approver (zero address for unrestricted)
        0 // staker opt out window blocks
      ],
      "" // metadata URI (empty string)
    );
    
    console.log(`Transaction sent: ${tx.hash}`);
    const receipt = await tx.wait();
    console.log(`Transaction confirmed in block ${receipt.blockNumber}`);
    console.log("Successfully registered as operator in EigenLayer!");
  } catch (error) {
    console.error("Error during registration:", error);
    if (error.reason) {
      console.error("Reason:", error.reason);
    }
  }
}

// Run the main function
main()
  .then(() => process.exit(0))
  .catch(error => {
    console.error("Unhandled error:", error);
    process.exit(1);
  });