FROM rust:1.76 as builder

WORKDIR /app

# Copy Cargo configuration files
COPY Cargo.toml ./

# Create a dummy source file to build dependencies
RUN mkdir src && echo 'fn main() { println!("Dummy"); }' > src/main.rs

# Build dependencies (this will be cached)
RUN cargo build --release

# Now copy the real source code
COPY src ./src/

# Build the actual application
RUN touch src/main.rs && cargo build --release

# Stage 2: TypeScript build
FROM node:20 as ts-builder

WORKDIR /app

# Copy package.json and install dependencies
COPY package.json package-lock.json* ./
RUN npm ci

# Copy TypeScript files and compile
COPY tsconfig.json ./
COPY src/*.ts ./src/
RUN npm run build

# Stage 3: Final image
FROM debian:bullseye-slim

WORKDIR /app

# Install necessary packages for runtime
RUN apt-get update && apt-get install -y \
    ca-certificates \
    libssl-dev \
    nodejs \
    npm \
    && rm -rf /var/lib/apt/lists/*

# Install additional Node packages
RUN npm install -g snarkjs

# Copy compiled Rust binary from builder
COPY --from=builder /app/target/release/backend /usr/local/bin/backend

# Copy TypeScript dist files
COPY --from=ts-builder /app/dist ./dist

# Copy necessary files for proof verification
COPY circuit-compiled/ ./circuit-compiled/
COPY keys/ ./keys/

# Create directories for runtime data
RUN mkdir -p uploads proofs

# Set environment variables
ENV RUST_LOG=info
ENV PORT=3000

# Expose the port your application will run on
EXPOSE 3000

# Command to run the application
CMD ["backend"]