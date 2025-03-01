# zkHotdog EigenLayer AVS

An EigenLayer Actively Validated Service (AVS) for the zkHotdog NFT project that verifies images of measured objects using LLM vision analysis.

## Overview

This AVS provides verification services for the zkHotdog NFT platform:

1. Registers as an EigenLayer operator and works with the ZkHotdogServiceManager contract
2. Monitors for new verification tasks created when NFTs are minted
3. Analyzes NFT images using OpenAI's Vision API to check if red dots are properly placed at the ends of measured objects
4. Signs and submits verification results back to the blockchain
5. Approved NFTs get a verification badge and additional value

## Components

- **Operator Agent**: Registers with EigenLayer, monitors for tasks, and processes verifications
- **Service Manager Contract**: Manages tasks and operator registrations on-chain
- **Integration with zkHotdog NFT**: Provides verified status for NFTs with valid measurements

## Prerequisites

- Node.js v16+
- Yarn or npm
- OpenAI API key with Vision access
- Ethereum wallet with private key
- Access to EigenLayer contracts (deployed or local testnet)

## Installation

```bash
# Clone the repository
git clone https://github.com/your-repo/zkHotdog.git
cd zkHotdog/zkhotdog/packages/eigen-avs

# Install dependencies
yarn install
```

## Configuration

Copy the `.env.example` file to create your own `.env` file:

```bash
cp .env.example .env
```

Fill in the required environment variables:

- `CHAIN_ID`: The ID of the Ethereum network (5 for Goerli Testnet)
- `OPERATOR_ADDRESS`: Your EigenLayer operator address
- `OPERATOR_ID`: Your EigenLayer operator ID
- `PRIVATE_KEY`: Private key of your Ethereum wallet
- `RPC_URL`: URL of an Ethereum RPC endpoint
- `SERVICE_MANAGER_ADDRESS`: Address of the ZkHotdogServiceManager contract
- `NFT_CONTRACT_ADDRESS`: Address of the zkHotdog NFT contract
- `STAKE_REGISTRY_ADDRESS`: Address of the EigenLayer stake registry
- `DELEGATION_MANAGER_ADDRESS`: Address of the EigenLayer delegation manager
- `AVS_DIRECTORY_ADDRESS`: Address of the EigenLayer AVS directory
- `TEST_IMAGE_URL`: URL for test images
- `OPENAI_API_KEY`: Your OpenAI API key with Vision access

## Usage

### Build the project

```bash
yarn build
```

### Run the operator agent

```bash
yarn start
```

### Register as an operator only

```bash
yarn register
```

## Operator Agent (operator_agent.ts)

The operator agent is responsible for:

- Registering with EigenLayer core contracts
- Registering with the zkHotdog AVS
- Monitoring for new verification tasks
- Processing images with LLM to check for properly placed red dots
- Signing and submitting verification results

The agent automatically:
1. Registers itself as an operator when starting
2. Checks for existing tasks that may need processing
3. Monitors for new tasks in real-time
4. Processes images to determine if they pass verification
5. Signs and submits the verification results to the chain

## Contract Integration

The AVS integrates with the following contracts:

1. **ZkHotdogServiceManager**: Manages verification tasks and operator signatures
2. **ZkHotdog NFT**: Stores verification status and NFT metadata
3. **EigenLayer Core Contracts**: Provides staking, delegation, and AVS registration

## License

MIT