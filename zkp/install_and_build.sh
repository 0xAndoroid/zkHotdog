#!/bin/bash

# Script to install dependencies and build the TypeScript verification client

# Check if Node.js is installed
if ! command -v node &> /dev/null
then
    echo "Node.js is not installed. Please install Node.js v20+ and try again."
    exit 1
fi

# Check Node.js version (should be 20+)
NODE_VERSION=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
if [ "$NODE_VERSION" -lt 20 ]; then
    echo "Node.js version $NODE_VERSION is too old. Please upgrade to Node.js v20+ and try again."
    exit 1
fi

echo "Installing dependencies..."
npm install

echo "Building TypeScript verification client..."
npm run build

echo "Installation and build completed successfully!"
echo "Before running the application, make sure to set the ZK_VERIFY_SEED_PHRASE environment variable."
echo "Example: export ZK_VERIFY_SEED_PHRASE=\"your twelve word seed phrase here\""