# 🌭 zkHotdog

Measure Anything Anywhere—With Cryptographic Proof! 🔍🔐🧮

<h4 align="center">
  <a href="#the-problem-zkhotdog-solves">Problem</a> |
  <a href="#user-interaction-and-data-flow">How It Works</a> |
  <a href="#the-project-architecture-and-development-process">Architecture</a> |
  <a href="#key-differentiators-and-uniqueness-of-the-project">Differentiators</a>
</h4>

## The problem zkHotdog solves
📌 Measurement fraud and disputes cost billions annually
📌 Traditional measurements lack cryptographic verification
📌 No privacy-preserving way to prove measurements

💭 How do you verify real-world measurements without revealing sensitive data?

## User Interaction and Data Flow
zkHotdog enables verifiable measurements with zero-knowledge proofs!
📱 Open the iOS app, measure with AR, submit for verification on-chain.

🔹 Private? Always.
🔹 Verifiable? Absolutely.
🔹 Trustless? By design.

## The project architecture and development process
🏗️ Project Architecture & Development Process
🔧 Core Architecture
zkHotdog is a decentralized measurement verification system powered by zero-knowledge proofs, AR technology, and blockchain attestations for tamper-proof, privacy-preserving measurements.

User Measurement & Verification 📏

AR-powered measurement via iOS app using ARKit/SceneKit
Zero-knowledge proof generation using Circom circuits
AI-assisted verification to ensure proper point placement
On-Chain Attestation & Storage 🔗

Verified measurements attested via zkVerify network
Measurement proofs verified by EigenLayer operators
NFT issuance for proof of verified measurements
Backend Processing & Proof Generation 🔄

Rust-based server for handling measurement requests
Groth16 proving system for efficient zero-knowledge proofs
Image processing for visual verification

🚀 Development Process
Research & Circuit Design 🔍 – Defined measurement parameters and designed ZK circuit
iOS App Development 📱 – Built AR measurement interface with precise coordinate capturing
ZK Circuit Implementation ⚙️ – Created Circom circuit for verifying measurement constraints
Backend & Proof System 🛠️ – Developed Rust server for proof generation and verification
EigenLayer Integration 🔗 – Connected to operator network for decentralized verification
Testing & Optimization 🧪 – Ensured accuracy of AR measurements and proof generation

## Product Integrations
🤖 AI Verification → OpenAI API (GPT-4o)
📏 AR Measurement → Apple ARKit & SceneKit
🔐 Zero-Knowledge Proofs → Circom & Groth16
🧮 Proof Verification → snarkjs & EigenLayer AVS
🔗 On-Chain Attestation → zkVerify network
🌐 Frontend → iOS native app & Next.js web interface
🖥️ Backend → Rust server

## Key differentiators and uniqueness of the project
🌟 Key Differentiators & Uniqueness
🚀 What Makes zkHotdog Unique?
AR-Powered Zero-Knowledge Measurements 📏🔐

zkHotdog combines AR technology with zero-knowledge proofs to create verifiable measurements without revealing raw data.
Unlike conventional measuring tools, zkHotdog provides cryptographic guarantees of measurement integrity.
Decentralized Verification Network 🌐✅

Leverages EigenLayer operators for distributed verification rather than relying on a centralized authority.
Creates a tamper-proof record of measurements that can be verified by anyone.
AI-Enhanced Validation 🤖👁️

Uses GPT-4o to analyze measurement images and ensure anchor points are properly placed.
Significantly reduces user error and enhances measurement accuracy.
On-Chain Attestation with Privacy 🔗🛡️

Issues NFTs representing verified measurements while keeping the underlying data private.
Creates permanent, immutable records of verified measurements for future reference.

🔍 Comparison to Similar Solutions
| Feature | zkHotdog 🌭 | Traditional Tools 📏 | Other AR Apps 📱 | Blockchain Oracles 🔮 |
|---------|------------|-------------------|----------------|---------------------|
| AR Measurements | ✅ Yes | ❌ No | ✅ Yes | ❌ No |
| Zero-Knowledge Proofs | ✅ Yes | ❌ No | ❌ No | ❌ No |
| Decentralized Verification | ✅ Yes | ❌ No | ❌ No | ✅ Yes |
| On-Chain Attestation | ✅ Yes | ❌ No | ❌ No | ✅ Yes |
| Privacy Preservation | ✅ Yes | ✅ Yes | ❌ No | ❌ No |

## Trade-offs and shortcuts while building
⚖️ Trade-offs & Shortcuts While Building
⏳ Development Trade-offs & Quick Fixes
iOS-First Approach Over Cross-Platform 📱

We prioritized a high-quality iOS implementation using ARKit rather than building for multiple platforms.
Future versions will expand to Android using ARCore technology.
Simplified Circuit Design 🔄

The current ZK circuit handles basic measurement verification, but could be expanded to include more complex geometric relationships.
We optimized for proving speed over handling all possible edge cases.
EigenLayer Testing Limitations 🧪

We used a simplified operator registration for hackathon purposes, with plans to expand the staking model for production use.

🔮 Future Optimizations & Enhancements
Multi-Object Measurement ➕

Expand capabilities to verify relationships between multiple measured objects simultaneously.
Create compound proofs that attest to complex spatial relationships.
Supply Chain Verification 📦

Integrate with logistics systems to provide verified measurements for shipping and inventory.
Enable batch verification of multiple items with efficient proof aggregation.
Standardized Measurement Credentials 🏛️

Develop a standardized format for measurement credentials that can be recognized across industries.
Build an ecosystem where zkHotdog measurements are accepted as legal proof of dimension.

We started zkHotdog during the Web3 Measurement Hackathon! 🚀

## Technologies Used

1. **ARKit/SceneKit** - Apple's augmented reality framework for iOS measurements
2. **Circom** - Zero-knowledge circuit programming language
3. **Rust** - Backend server language for proof generation and verification
4. **snarkjs/Groth16** - Zero-knowledge proof system
5. **EigenLayer** - Decentralized operator staking and verification network
6. **zkVerify** - Network for on-chain attestations of zero-knowledge proofs
7. **Next.js** - React framework for web interface
8. **Swift** - iOS native app development
9. **OpenAI API (GPT-4o)** - AI verification of measurement images
10. **Solidity** - Smart contract language for on-chain verification

## Requirements

Before you begin, you need to install the following tools:

- [Node (>= v20.18.3)](https://nodejs.org/en/download/)
- [Rust](https://www.rust-lang.org/tools/install)
- [Yarn](https://yarnpkg.com/getting-started/install)
- [Git](https://git-scm.com/downloads)

## Quickstart

To get started with zkHotdog, follow these steps:

1. Install dependencies:

```bash
cd zkhotdog
yarn install
```

2. Run a local network:

```bash
yarn chain
```

3. Deploy the smart contracts:

```bash
yarn deploy
```

4. Start the frontend:

```bash
yarn start
```

Visit the app at: `http://localhost:3000`

For the backend and ZK proof system, see the [backend README](../zkp/README.md).

## Documentation

For more detailed documentation on each component:

- [Backend & ZK Proofs](../zkp/README.md) - Setting up and running the Rust backend
- [Smart Contracts](./packages/foundry/README.md) - Information on the smart contracts
- [iOS App](../ios/README.md) - How to build and run the iOS measurement app