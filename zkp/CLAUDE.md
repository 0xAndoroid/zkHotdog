# zkHotdog Project Guidelines

## Build & Run Commands
- Build: `cargo build`
- Run: `cargo run`
- Check: `cargo check`
- Format: `cargo fmt`
- Lint: `cargo clippy`
- Release build: `cargo build --release`
- Run circuit compilation: `npx circom circuit/zkHotdog.circom --wasm --r1cs -o circuit-compiled`

## Code Style Guidelines
- **Imports**: Group imports by crate, with std imports first, then external crates, then internal modules
- **Formatting**: Follow standard Rust formatting via rustfmt (4-space indentation)
- **Error Handling**: Use Result for error propagation, with meaningful error messages
- **Variable Names**: Use snake_case for variables and functions, CamelCase for types/structs/enums
- **Comments**: Document public APIs, complex functions, and non-obvious logic
- **Types**: Use strong typing; prefer Option over null values
- **Mutability**: Keep mutability scoped and minimal
- **Async**: Use .await directly rather than wrapping in spawn where possible
- **Circom**: Use 2-space indentation in .circom files

## Project Structure
- `/circuit`: Contains Circom circuit definitions
- `/circuit-compiled`: Contains compiled circuit artifacts
- `/src`: Rust backend service code
- `/uploads`: Storage for uploaded images
- `/proofs`: Storage for generated ZK proofs