# zkHotdog Project Guidelines

## Environment Variables
- **NextJS**:
  - Copy `.env.example` to `.env.local` in the `zkhotdog/packages/nextjs` directory
  - Update the values in `.env.local` with your configuration:
    - `NEXT_PUBLIC_ZK_HOTDOG_CONTRACT_ADDRESS`: Address of the deployed ZkHotdog contract
    - `NEXT_PUBLIC_API_BASE_URL`: Base URL of the backend API (default: `http://localhost:3000`)
    - `NEXT_PUBLIC_ALCHEMY_API_KEY`: Your Alchemy API key for Web3 interactions
    - `NEXT_PUBLIC_WALLET_CONNECT_PROJECT_ID`: Your WalletConnect project ID

## Build & Run Commands
- **Backend**:
  - Build: `cargo build`
  - Run: `cargo run` 
  - Check: `cargo check`
  - Format: `cargo fmt`
  - Lint: `cargo clippy`
  - Test: `cargo test`

- **Circuit**:
  - Compile circuit: `npx circom circuit/zkHotdog.circom --wasm --r1cs -o circuit-compiled`
  - Generate proof: `npx snarkjs groth16 prove keys/zkHotdog_final.zkey path/to/witness.wtns proof.json public.json`

- **Frontend (NextJS)**:
  - Start: `yarn start` or `cd zkhotdog && yarn start`
  - Build: `yarn next:build`
  - Lint: `yarn next:lint`
  - Format: `yarn next:format`
  - Type check: `yarn next:check-types`

## Code Style Guidelines
- **Rust**: 4-space indentation, snake_case for variables/functions, CamelCase for types
- **TypeScript/JavaScript**: Follow Prettier config, use strong typing with TypeScript
- **Circom**: 2-space indentation, camelCase for variables and component names
- **Error Handling**: Use Result/Option types in Rust, proper async/await error handling in JS/TS
- **Comments**: Document public APIs and non-obvious logic (especially in ZK circuit code)
- **Imports**: Group by standard lib, external dependencies, then internal modules