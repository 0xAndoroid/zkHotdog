# zkHotdog Smart Contracts

This package contains the smart contracts for the zkHotdog application, built with Foundry.

## Overview

The zkHotdog smart contracts handle the on-chain verification and attestation of zero-knowledge proofs for physical measurements, leveraging EigenLayer for decentralized verification.

## Key Components

- **zkVerifyRegistry**: Handles registration and verification of zero-knowledge proofs
- **MeasurementNFT**: Issues NFTs representing verified measurements
- **OperatorRegistry**: Manages EigenLayer AVS operators for decentralized verification

## Development Setup

1. Install Foundry:
   ```bash
   curl -L https://foundry.paradigm.xyz | bash
   foundryup
   ```

2. Build the contracts:
   ```bash
   forge build
   ```

3. Run tests:
   ```bash
   forge test
   ```

4. Deploy contracts:
   ```bash
   forge script script/Deploy.s.sol --rpc-url <your_rpc_url> --private-key <your_private_key>
   ```

## Contract Architecture

The zkHotdog contracts implement the following architecture:

1. Users submit measurements through the iOS app
2. Backend generates zero-knowledge proofs
3. Proofs are submitted to zkVerify network
4. EigenLayer operators verify the proofs
5. Attestations are recorded on-chain
6. NFTs are minted representing verified measurements

## Contract Addresses

- **Sepolia Testnet**:
  - zkVerifyRegistry: `0xzkVerifyRegistry`
  - MeasurementNFT: `0xMeasurementNFT`
  - OperatorRegistry: `0xOperatorRegistry`

## Integration with EigenLayer

The contracts integrate with EigenLayer's Actively Validated Service (AVS) system for decentralized verification of zero-knowledge proofs, ensuring the security and trustlessness of the measurement verification process.

## License

These contracts are licensed under MIT.