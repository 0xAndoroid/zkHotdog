#!/bin/bash

# Script to rebuild the ZK circuit and generate keys
# Usage: ./rebuild_circuit.sh

set -e

# Define directories
CIRCUIT_DIR="circuit"
OUTPUT_DIR="circuit-compiled"
KEYS_DIR="keys"
PTAU_DIR="ptau"

# Create directories if they don't exist
mkdir -p $OUTPUT_DIR
mkdir -p $KEYS_DIR

echo "Step 1: Compiling circuit..."
circom $CIRCUIT_DIR/zkHotdog.circom --wasm --r1cs -o $OUTPUT_DIR

echo "Step 2: Starting Powers of Tau ceremony..."
# Using a smaller ptau (power of 2^6 = 64) since the circuit is very small
# Check if we have a final ptau file, if not generate it
if [ ! -f "$PTAU_DIR/pot6_final.ptau" ]; then
  echo "Generating Powers of Tau (small circuit)..."
  mkdir -p $PTAU_DIR
  npx snarkjs powersoftau new bn128 6 $PTAU_DIR/pot6_0000.ptau -v
  echo "zkHotdog random entropy" | npx snarkjs powersoftau contribute $PTAU_DIR/pot6_0000.ptau $PTAU_DIR/pot6_0001.ptau --name="First contribution" -v -e
  npx snarkjs powersoftau prepare phase2 $PTAU_DIR/pot6_0001.ptau $PTAU_DIR/pot6_final.ptau -v
else
  echo "Using existing Powers of Tau file..."
fi

echo "Step 3: Generating zKey..."
npx snarkjs groth16 setup $OUTPUT_DIR/zkHotdog.r1cs $PTAU_DIR/pot6_final.ptau $KEYS_DIR/zkHotdog.zkey

echo "Step 4: Contribute to phase 2 ceremony..."
echo "zkHotdog phase2 contribution" | npx snarkjs zkey contribute $KEYS_DIR/zkHotdog.zkey $KEYS_DIR/zkHotdog_final.zkey --name="zkHotdog" -v -e

echo "Step 5: Exporting verification key..."
npx snarkjs zkey export verificationkey $KEYS_DIR/zkHotdog_final.zkey $KEYS_DIR/verification_key.json

echo "Circuit rebuilt and keys generated successfully!"
echo "You can now use these keys to generate and verify proofs."