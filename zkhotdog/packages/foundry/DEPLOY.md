# ZkHotdog Local Deployment Guide

This guide will walk you through deploying the ZkHotdog contracts to a local Anvil instance.

## Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation) installed
- Node.js and Yarn installed

## Configure Deployment

All configuration is handled through the `.env` file. The default values are set for local development, but you can modify them according to your needs:

```
# Network Configuration
ANVIL_RPC_URL=http://localhost:8545
DEPLOYER_PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 # Default Anvil account #0

# Contract Configuration
ZK_VERIFY_DEPLOY=true # Set to false if you want to use an existing zkVerify contract
ZK_VERIFY_ADDRESS=0x0000000000000000000000000000000000000000 # Only used if ZK_VERIFY_DEPLOY=false
VKEY=0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef # Verification key for ZkHotdog

# EigenLayer Configuration
DEPLOY_EIGENLAYER_CORE=true # Set to false if you want to use existing EigenLayer deployment
EIGENLAYER_AVS_DIRECTORY=0x0000000000000000000000000000000000000000 # Only used if DEPLOY_EIGENLAYER_CORE=false
EIGENLAYER_STAKE_REGISTRY=0x0000000000000000000000000000000000000000 # Only used if DEPLOY_EIGENLAYER_CORE=false
EIGENLAYER_REWARDS_COORDINATOR=0x0000000000000000000000000000000000000000 # Only used if DEPLOY_EIGENLAYER_CORE=false
EIGENLAYER_DELEGATION_MANAGER=0x0000000000000000000000000000000000000000 # Only used if DEPLOY_EIGENLAYER_CORE=false

# Log Configuration
VERBOSE=true
```

## Deployment Steps

1. Navigate to the foundry directory:
   ```bash
   cd zkhotdog/packages/foundry
   ```

2. Make sure the `.env` file is configured correctly.

3. Run the deployment script:
   ```bash
   ./deploy-local.sh
   ```

The script will:
1. Check if an Anvil instance is running, and start one if needed
2. Deploy all contracts to the local Anvil network
3. Display the addresses of all deployed contracts

## Contracts Deployed

The deployment script will deploy the following contracts:

1. **MockZkVerify** - A mock implementation of the zkVerify interface for testing
2. **ZkHotdog NFT** - The main NFT contract that holds hotdog verification information
3. **EigenLayer Core** - The core contracts for EigenLayer integration
4. **ZkHotdogServiceManager** - The service manager that handles verification tasks
5. **ERC20Mock** - A mock ERC20 token for testing with EigenLayer

## After Deployment

After deployment, you'll have a fully functioning ZkHotdog system running on your local Anvil instance. You can:

1. Mint NFTs and create verification tasks in a single transaction
2. Register as an EigenLayer operator
3. Respond to verification tasks
4. Verify tokens through the service manager

## Shutting Down

If you started Anvil using the deployment script, you can shut it down with:
```bash
kill $(cat .anvil.pid)
```

## Troubleshooting

If you encounter issues during deployment:

1. Check that your Anvil instance is running correctly
2. Verify that the `.env` file is properly configured
3. Ensure you have sufficient gas for all deployments (not an issue on local Anvil)
4. Check the Foundry logs for specific error messages