# Docker Setup for zkHotdog Backend

This document provides instructions for running the zkHotdog backend using Docker.

## Prerequisites

- Docker and Docker Compose installed on your system
- The zkVerify seed phrase for proof verification

## Quick Start

1. Set your zkVerify seed phrase as an environment variable:

```bash
export ZK_VERIFY_SEED_PHRASE="your seed phrase here"
```

2. Build and start the container:

```bash
docker-compose up --build
```

3. The API will be available at http://localhost:3000

## Configuration

The Docker setup uses the following configuration:

- Port: 3000 (configurable in docker-compose.yml)
- Mounted volumes:
  - `./uploads`: Storage for uploaded images
  - `./proofs`: Storage for generated ZK proofs

## Environment Variables

- `RUST_LOG`: Controls logging level (default: info)
- `ZK_VERIFY_SEED_PHRASE`: Required for verification on the zkVerify network

## Building Without Docker Compose

If you prefer to build and run the Docker image directly:

```bash
# Build the image
docker build -t zkhotdog-backend .

# Run the container
docker run -p 3000:3000 \
  -e ZK_VERIFY_SEED_PHRASE="your seed phrase here" \
  -v $(pwd)/uploads:/app/uploads \
  -v $(pwd)/proofs:/app/proofs \
  zkhotdog-backend
```

## API Endpoints

- `POST /measurements`: Submit a measurement with an image and coordinates
- `GET /status/:id`: Check the status of a proof
- `GET /img/:id`: Retrieve an uploaded image