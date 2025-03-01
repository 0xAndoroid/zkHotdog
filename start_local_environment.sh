#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}===== Starting zkHotdog Local Environment =====${NC}"

# Starting directory
BASE_DIR=$(pwd)
FOUNDRY_DIR="$BASE_DIR/zkhotdog/packages/foundry"
EIGEN_AVS_DIR="$BASE_DIR/zkhotdog/packages/eigen-avs"
ZKP_DIR="$BASE_DIR/zkp"

# Copy verification key for contract deployment
echo -e "${GREEN}Copying ZK verification key for contract deployment...${NC}"
if [ -f "$ZKP_DIR/keys/verification_key.json" ]; then
    # Convert verification key to bytes32 format for the contract
    VKEY=$(cat "$ZKP_DIR/keys/verification_key.json" | sha256sum | awk '{print "0x"$1}')
    echo -e "${GREEN}Verification key hash: $VKEY${NC}"
else
    echo -e "${RED}ERROR: Verification key not found at $ZKP_DIR/keys/verification_key.json${NC}"
    echo -e "${RED}Cannot proceed with deployment. Please ensure the verification key exists.${NC}"
    exit 1
fi

# 1. Start anvil in the background
echo -e "${GREEN}Starting Anvil local Ethereum node...${NC}"
anvil > anvil.log 2>&1 &
ANVIL_PID=$!
echo -e "${GREEN}Anvil started with PID: $ANVIL_PID${NC}"

# Wait for anvil to start
sleep 3

# 2. Deploy contracts and keep the process running
echo -e "${GREEN}Deploying contracts...${NC}"
cd "$FOUNDRY_DIR"

# Add environment variables for the deployment
export DEPLOYER_PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
export ANVIL_RPC_URL=http://127.0.0.1:8545
export VERBOSE=true
export ZK_VERIFY_DEPLOY=true
export DEPLOY_EIGENLAYER_CORE=true
export VKEY="$VKEY"

# Run the deployment script in the background
forge script script/DeployAll.s.sol:DeployAll --fork-url "$ANVIL_RPC_URL" --private-key "$DEPLOYER_PRIVATE_KEY" --broadcast > deployment.log 2>&1 &
FORGE_PID=$!
echo -e "${GREEN}Forge deployment started with PID: $FORGE_PID${NC}"

# Wait for deployment to reach a certain point
echo -e "${YELLOW}Waiting for deployment to complete initial phase...${NC}"
while ! grep -q "=== DEPLOYMENT SUMMARY ===" deployment.log; do
  sleep 5
  echo -e "${YELLOW}.${NC}"
done

echo -e "${GREEN}Deployment completed initial phase${NC}"

# Extract contract addresses
echo -e "${GREEN}Extracting contract addresses...${NC}"
SERVICE_MANAGER=$(grep -A 10 "=== DEPLOYMENT SUMMARY ===" deployment.log | grep "ZkHotdogServiceManager" | awk '{print $2}')
NFT_CONTRACT=$(grep -A 10 "=== DEPLOYMENT SUMMARY ===" deployment.log | grep "ZkHotdog NFT" | awk '{print $3}')
STAKE_REGISTRY=$(grep -A 10 "=== DEPLOYMENT SUMMARY ===" deployment.log | grep "StakeRegistry" | awk '{print $2}')
AVS_DIRECTORY=$(grep -A 10 "=== DEPLOYMENT SUMMARY ===" deployment.log | grep "AVS Directory" | awk '{print $3}')
DELEGATION_MANAGER=$(grep -A 10 "=== DEPLOYMENT SUMMARY ===" deployment.log | grep "DelegationManager" | awk '{print $2}')

# 3. Configure and start the EigenLayer AVS operator
echo -e "${GREEN}Configuring EigenLayer AVS operator...${NC}"
cd "$EIGEN_AVS_DIR"

# Assume .env file with OpenAI key is already present

# Start the operator agent
echo -e "${GREEN}Starting EigenLayer AVS operator...${NC}"
cd "$EIGEN_AVS_DIR"
./start_operator.sh

echo -e "${GREEN}Local environment setup complete!${NC}"

# Cleanup function for when script is interrupted
cleanup() {
  echo -e "${YELLOW}Cleaning up...${NC}"
  kill $ANVIL_PID $FORGE_PID 2>/dev/null || true
  echo -e "${GREEN}Done.${NC}"
  exit
}

# Set trap for cleanup
trap cleanup INT TERM

# Keep script running
echo -e "${GREEN}Press Ctrl+C to stop all processes${NC}"
while true; do
  sleep 60
done
