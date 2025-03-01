# zkHotdog Backend 🌭

This project implements a backend server for the zkHotdog application, which verifies physical measurements using zero-knowledge proofs and submits them to the zkVerify network for on-chain attestation.

## Setup

1. Make sure you have Node.js v20+ and Rust installed
2. Install required Node packages:
   ```
   npm install -g snarkjs
   npm install  # Install TypeScript client dependencies
   npm run build  # Build the TypeScript verification client
   ```
3. Install ImageMagick for the test scripts (to generate test images):
   ```
   # macOS:
   brew install imagemagick
   
   # Linux:
   sudo apt-get install imagemagick
   ```
4. Build the Rust backend:
   ```
   cargo build
   ```
   
5. Configure the zkVerify network integration by setting environment variables:
   ```
   export ZK_VERIFY_SEED_PHRASE="your twelve word seed phrase here"
   ```

## Circuit Setup

The Circom circuit has been compiled, but you need to generate proving and verification keys:

```bash
# Generate Powers of Tau
npx snarkjs powersoftau new bn128 8 ptau/pot8_0000.ptau -v
npx snarkjs powersoftau contribute ptau/pot8_0000.ptau ptau/pot8_0001.ptau --name="First contribution" -v -e="random text"
npx snarkjs powersoftau prepare phase2 ptau/pot8_0001.ptau ptau/pot8_final.ptau -v

# Generate proving and verification keys
npx snarkjs groth16 setup circuit-compiled/zkHotdog.r1cs ptau/pot8_final.ptau keys/zkHotdog.zkey
npx snarkjs zkey contribute keys/zkHotdog.zkey keys/zkHotdog_final.zkey -n="First contribution" -e="random entropy"
npx snarkjs zkey export verificationkey keys/zkHotdog_final.zkey keys/verification_key.json
```

## Running the Server

Start the backend server:

```bash
cargo run
```

The server will listen on port 3000.

## Testing

Two test scripts are provided:

1. `test_proof.sh` - Tests the proof generation and verification directly
2. `test_api.sh` - Tests the complete API flow

To run the test scripts:

```bash
# Test proof generation
./test_proof.sh

# Test API (make sure the server is running)
./test_api.sh
```

## API Endpoints

- `POST /measurements` - Submit a new measurement
  - Accepts multipart form data with:
    - `image`: The image file
    - `startPoint`: JSON object with x, y, z coordinates
    - `endPoint`: JSON object with x, y, z coordinates
  - Returns a measurement ID and status URL

- `GET /status/:id` - Check the status of a measurement
  - Returns the current status of the proof generation and verification
  - Status values include:
    - `Pending`: Measurement received, not yet processed
    - `Processing`: Proof is being generated or verified on zkVerify network
    - `Completed`: Proof has been successfully verified on zkVerify network
    - `Failed`: Proof generation or verification failed

## zkVerify Network Integration

The backend integrates with the zkVerify network to submit and verify the generated zero-knowledge proofs. After a proof is generated, it is automatically submitted to the zkVerify network using the TypeScript client in `src/verify_client.ts`.

This process involves:

1. Generating the ZK proof locally using Circom/snarkjs
2. Submitting the proof to the zkVerify network using the zkverifyjs library
3. Monitoring the status of the verification on the blockchain
4. Updating the measurement status based on the verification result

The TypeScript client supports:
- Sending proofs to the zkVerify network
- Listening for transaction events 
- Waiting for transaction finalization
- Receiving attestation confirmations

## Technologies Used

The zkHotdog backend is built using the following key technologies:

1. **Rust** - High-performance backend server language
2. **Circom** - Zero-knowledge circuit programming language
3. **snarkjs/Groth16** - Zero-knowledge proof generation and verification system
4. **EigenLayer** - Decentralized operator staking and verification
5. **zkVerify** - Network for on-chain attestations of zero-knowledge proofs
6. **Axum** - Rust web framework for handling API requests
7. **Tokio** - Asynchronous runtime for Rust
8. **OpenAI API** - For AI verification of images and measurement points
9. **TypeScript** - For the verification client interface
10. **ethers.js** - For blockchain interactions