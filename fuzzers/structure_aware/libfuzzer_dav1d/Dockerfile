FROM rust:1.91.0

# Avoid timezone prompts
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=UTC

# Set RUSTFLAGS for native CPU optimization
ENV RUSTFLAGS="-C target-cpu=native"

# Install dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    clang \
    git \
    meson \
    ninja-build \
    nasm \
    python3 \
    python3-pip \
    aom-tools \
    pkg-config \
    cmake \
    llvm \
    libz3-dev \
    && rm -rf /var/lib/apt/lists/*

# Install just
RUN cargo install just

# Set working directory
WORKDIR /fuzzer

# Copy workspace root files for cargo workspace
COPY Cargo.toml /workspace/

# Copy all crates for workspace dependencies
COPY crates /workspace/crates

# Copy the fuzzer project files
COPY fuzzers/structure_aware/libfuzzer_dav1d/Justfile .
COPY fuzzers/structure_aware/libfuzzer_dav1d/generate_corpus.py .
COPY fuzzers/structure_aware/libfuzzer_dav1d/fuzzer/ fuzzer/
COPY fuzzers/structure_aware/libfuzzer_dav1d/runtime/ runtime/

# Update runtime and fuzzer Cargo.toml to use workspace path
RUN sed -i 's|path = "../../../../crates/libafl_concolic/symcc_runtime"|path = "/workspace/crates/libafl_concolic/symcc_runtime"|g' runtime/Cargo.toml && \
    sed -i 's|path = "../../../../crates/|path = "/workspace/crates/|g' fuzzer/Cargo.toml

# Build dav1d library
RUN just build-dav1d

# Generate corpus
RUN python3 generate_corpus.py corpus

# Build runtime
RUN just build-runtime

# Build fuzzer
RUN just build-fuzzer

# Set entrypoint
WORKDIR /fuzzer/fuzzer
CMD ["./target/release/libfuzzer_dav1d_concolic"]
