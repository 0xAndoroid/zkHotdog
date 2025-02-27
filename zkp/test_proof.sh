#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Create test directory if it doesn't exist
mkdir -p test_data

# Test 1: Create a test input file
echo -e "${GREEN}Creating test input file...${NC}"
cat > test_data/input.json << EOL
{
  "point1": [10, 20, 30],
  "point2": [15, 30, 40],
  "distance_mm": 15
}
EOL

echo -e "${GREEN}Test input file created.${NC}"

# Test directory
TEST_DIR="test_data/proof_test"
mkdir -p $TEST_DIR

# Circuit paths
CIRCUIT_WASM="circuit-compiled/zkHotdog_js/zkHotdog.wasm"
PROVING_KEY="keys/zkHotdog_final.zkey"
INPUT_PATH="test_data/input.json"
WITNESS_PATH="$TEST_DIR/witness.wtns"
PROOF_PATH="$TEST_DIR/proof.json"
PUBLIC_PATH="$TEST_DIR/public.json"

# Test 2: Generate witness
echo -e "${GREEN}Generating witness...${NC}"
node circuit-compiled/zkHotdog_js/generate_witness.js circuit-compiled/zkHotdog_js/zkHotdog.wasm "$INPUT_PATH" "$WITNESS_PATH"

# Test 3: Generate proof
echo -e "${GREEN}Generating proof...${NC}"
npx snarkjs groth16 prove "$PROVING_KEY" "$WITNESS_PATH" "$PROOF_PATH" "$PUBLIC_PATH"

# Test 4: Verify the proof
echo -e "${GREEN}Verifying proof...${NC}"
npx snarkjs groth16 verify keys/verification_key.json "$PUBLIC_PATH" "$PROOF_PATH"

echo -e "${GREEN}All tests passed successfully!${NC}"