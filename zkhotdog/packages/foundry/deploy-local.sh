#!/bin/bash

# Colors for better output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Print section header
print_header() {
  echo -e "\n${YELLOW}=== $1 ===${NC}\n"
}

# Check if anvil is running
check_anvil() {
  if ! curl -s -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' http://localhost:8545 > /dev/null; then
    return 1
  else
    return 0
  fi
}

# Load environment variables
source .env

print_header "ZkHotdog Local Deployment"

echo "This script will:"
echo "1. Check if Anvil is running (or start a new instance)"
echo "2. Deploy all contracts to the local Anvil network"
echo ""

# Check if Anvil is running, if not start it
if ! check_anvil; then
  print_header "Starting Anvil"
  echo "Starting a new Anvil instance in the background..."
  # Start anvil in the background
  anvil > anvil.log 2>&1 &
  ANVIL_PID=$!
  
  # Wait for anvil to start
  echo "Waiting for Anvil to start..."
  sleep 3
  
  if ! check_anvil; then
    echo -e "${RED}Failed to start Anvil. Please check anvil.log for details.${NC}"
    exit 1
  fi
  
  echo -e "${GREEN}Anvil started successfully with PID: $ANVIL_PID${NC}"
  echo "To stop Anvil later, run: kill $ANVIL_PID"
  
  # Save PID to file for later cleanup
  echo $ANVIL_PID > .anvil.pid
else
  echo -e "${GREEN}Anvil is already running${NC}"
fi

# Deploy contracts
print_header "Deploying Contracts"
echo "Running deployment script..."
forge script script/DeployAll.s.sol:DeployAll --rpc-url $ANVIL_RPC_URL --broadcast

# Check if deployment was successful
if [ $? -eq 0 ]; then
  echo -e "\n${GREEN}Deployment completed successfully!${NC}"
  
  # Extract contract addresses (this is a simple example - you can enhance it)
  echo -e "\n${YELLOW}Contract addresses can be found in the logs above${NC}"
  
  echo -e "\n${GREEN}Your ZkHotdog application is now ready to use locally!${NC}"
else
  echo -e "\n${RED}Deployment failed. Please check the logs above for errors.${NC}"
fi

echo -e "\n${YELLOW}Note:${NC} Keep Anvil running to interact with your deployed contracts."
echo "If you started Anvil with this script, you can stop it by running: kill \$(cat .anvil.pid)"