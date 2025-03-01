#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}Starting zkHotdog AVS Operator Setup...${NC}"

# Check if node and yarn are installed
if ! command -v node &> /dev/null || ! command -v yarn &> /dev/null; then
    echo -e "${RED}Node.js and Yarn are required. Please install them first.${NC}"
    exit 1
fi

# Check if .env file exists, create from example if not
if [ ! -f .env ]; then
    echo -e "${YELLOW}No .env file found. Creating from .env.example...${NC}"
    if [ -f .env.example ]; then
        cp .env.example .env
    else
        echo "RPC_URL=http://localhost:8545
PRIVATE_KEY=your-private-key-here
CHAIN_ID=31337
OPENAI_API_KEY=your-openai-api-key-here
NFT_CONTRACT_ADDRESS=
SERVICE_MANAGER_ADDRESS=
STAKE_REGISTRY_ADDRESS=
DELEGATION_MANAGER_ADDRESS=
AVS_DIRECTORY_ADDRESS=" > .env
    fi
    echo -e "${YELLOW}Please edit the .env file with your actual configuration values.${NC}"
    echo -e "${YELLOW}Press enter to continue once you've updated the .env file or Ctrl+C to exit...${NC}"
    read
fi

# Install dependencies if node_modules doesn't exist
if [ ! -d "node_modules" ]; then
    echo -e "${GREEN}Installing dependencies...${NC}"
    yarn install
fi

# Create directories for deployment files
echo -e "${GREEN}Setting up directories...${NC}"
mkdir -p ../foundry/deployments/zk-hotdog
mkdir -p ../foundry/deployments/core

# Check for contract ABI files and deployment files
echo -e "${GREEN}Checking contract ABIs and deployment files...${NC}"
node check_deployment.js

# Compile TS files
echo -e "${GREEN}Compiling TypeScript files...${NC}"
npx tsc --project tsconfig.json

# Run the operator agent
echo -e "${GREEN}Running the operator agent...${NC}"
if [ -f dist/operator_agent.js ]; then
    node dist/operator_agent.js
else
    echo -e "${RED}Compilation failed. operator_agent.js not found in dist directory.${NC}"
    exit 1
fi

# The script will only reach here if the Node.js process exits
echo -e "${RED}Operator agent has stopped.${NC}"
