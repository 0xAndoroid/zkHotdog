# zkHotdog Backend

This project implements a backend server for the zkHotdog application, which verifies hotdog measurements using zero-knowledge proofs.

## Setup

1. Make sure you have Node.js and Rust installed
2. Install required Node packages:
   ```
   npm install -g snarkjs
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
  - Returns the current status of the proof generation