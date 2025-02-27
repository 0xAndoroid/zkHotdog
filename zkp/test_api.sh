#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Create test directory if it doesn't exist
mkdir -p test_data

# Test 1: Create a simple test image
echo -e "${GREEN}Creating test image...${NC}"
convert -size 100x100 xc:white test_data/test_image.jpg

# Test 2: Submit measurement
echo -e "${GREEN}Submitting measurement...${NC}"
START_POINT='{\"x\": 10.0, \"y\": 20.0, \"z\": 30.0}'
END_POINT='{\"x\": 15.0, \"y\": 30.0, \"z\": 40.0}'

# Fix JSON escaping
START_POINT=$(echo $START_POINT | sed 's/\\//g')
END_POINT=$(echo $END_POINT | sed 's/\\//g')

RESPONSE=$(curl -s -X POST http://localhost:3000/measurements \
  -F "image=@test_data/test_image.jpg" \
  -F "startPoint=$START_POINT" \
  -F "endPoint=$END_POINT")

echo $RESPONSE

# Extract measurement ID from response
MEASUREMENT_ID=$(echo $RESPONSE | jq -r '.measurement_id')

if [ -z "$MEASUREMENT_ID" ] || [ "$MEASUREMENT_ID" == "null" ]; then
  echo -e "${RED}Failed to get valid measurement ID${NC}"
  exit 1
fi

echo -e "${GREEN}Got measurement ID: $MEASUREMENT_ID${NC}"

# Test 3: Check status until proof is completed or failed
echo -e "${GREEN}Checking proof status...${NC}"
MAX_ATTEMPTS=30
CURRENT_ATTEMPT=0
STATUS="Pending"

while [ "$STATUS" != "Completed" ] && [ "$STATUS" != "Failed" ] && [ $CURRENT_ATTEMPT -lt $MAX_ATTEMPTS ]; do
  CURRENT_ATTEMPT=$((CURRENT_ATTEMPT + 1))
  echo "Attempt $CURRENT_ATTEMPT: Waiting for proof generation..."
  
  STATUS_RESPONSE=$(curl -s http://localhost:3000/status/$MEASUREMENT_ID)
  STATUS=$(echo $STATUS_RESPONSE | jq -r '.status')
  
  echo "Current status: $STATUS"
  
  if [ "$STATUS" == "Completed" ]; then
    echo -e "${GREEN}Proof generation successful!${NC}"
    break
  elif [ "$STATUS" == "Failed" ]; then
    echo -e "${RED}Proof generation failed.${NC}"
    exit 1
  fi
  
  sleep 2
done

if [ $CURRENT_ATTEMPT -ge $MAX_ATTEMPTS ]; then
  echo -e "${RED}Reached maximum number of attempts. Proof generation took too long.${NC}"
  exit 1
fi

echo -e "${GREEN}All tests passed successfully!${NC}"