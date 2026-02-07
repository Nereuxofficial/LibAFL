# LibAFL dav1d Fuzzer

Hybrid fuzzer for the dav1d AV1 decoder using LibAFL and SymCC.

## Quick Start with Docker Compose (Recommended)

```bash
# Navigate to the fuzzer directory
cd fuzzers/structure_aware/libfuzzer_dav1d

# Start the fuzzer in detached mode
docker-compose up -d

# View logs
docker-compose logs -f

# Stop the fuzzer
docker-compose down

# Start with concolic execution mode
docker-compose --profile concolic up -d libfuzzer_dav1d_concolic

# Check status
docker-compose ps
```

The docker-compose setup automatically:
- Builds the image from the LibAFL root directory
- Mounts `./crashes`, `./corpus_output`, and `./solutions` directories
- Restarts the fuzzer if it crashes
- Manages resource limits

### Output Directories
After running `docker-compose up -d`, results will be saved to:
- **./crashes/** - Crash-inducing inputs
- **./corpus_output/** - Evolved corpus
- **./solutions/** - Solution inputs

For concolic mode, outputs go to `./crashes_concolic/`, `./corpus_concolic/`, and `./solutions_concolic/`.

## Quick Start with Docker (Alternative)

```bash
# Build the Docker image (must be run from LibAFL root directory)
cd /path/to/LibAFL
docker build -f fuzzers/structure_aware/libfuzzer_dav1d/Dockerfile -t libafl-dav1d .

# Run the fuzzer interactively
docker run -it libafl-dav1d

# Run with custom options (concolic mode)
docker run -it libafl-dav1d ./target/release/libfuzzer_dav1d_concolic --concolic

# Run in detached mode with crash folder mounted (RECOMMENDED)
# This saves crashes even after the container is destroyed
docker run -d --name libfuzzer_dav1d \
  -v $(pwd)/crashes:/fuzzer/fuzzer/crashes \
  libafl-dav1d

# Run with all output directories mounted (crashes, corpus, solutions)
docker run -d --name libfuzzer_dav1d \
  -v $(pwd)/crashes:/fuzzer/fuzzer/crashes \
  -v $(pwd)/corpus_output:/fuzzer/fuzzer/corpus \
  -v $(pwd)/solutions:/fuzzer/fuzzer/solutions \
  libafl-dav1d

# Run with resource limits
docker run -d --name libfuzzer_dav1d \
  --cpus="4" \
  --memory="4g" \
  -v $(pwd)/crashes:/fuzzer/fuzzer/crashes \
  -v $(pwd)/corpus_output:/fuzzer/fuzzer/corpus \
  -v $(pwd)/solutions:/fuzzer/fuzzer/solutions \
  libafl-dav1d

# Run in concolic mode with mounted volumes
docker run -d --name libfuzzer_dav1d_concolic \
  -v $(pwd)/crashes_concolic:/fuzzer/fuzzer/crashes \
  -v $(pwd)/corpus_concolic:/fuzzer/fuzzer/corpus \
  -v $(pwd)/solutions_concolic:/fuzzer/fuzzer/solutions \
  libafl-dav1d ./target/release/libfuzzer_dav1d_concolic --concolic

# Monitor logs from detached container
docker logs -f libfuzzer_dav1d

# Stop and remove container (data persists in mounted volumes)
docker stop libfuzzer_dav1d
docker rm libfuzzer_dav1d

# Restart with same data
docker run -d --name libfuzzer_dav1d \
  -v $(pwd)/crashes:/fuzzer/fuzzer/crashes \
  -v $(pwd)/corpus_output:/fuzzer/fuzzer/corpus \
  -v $(pwd)/solutions:/fuzzer/fuzzer/solutions \
  libafl-dav1d
```

### Docker Run Options Explained

- `-d`: Run in detached mode (background)
- `--name libfuzzer_dav1d`: Give the container a friendly name
- `-v $(pwd)/crashes:/fuzzer/fuzzer/crashes`: Mount local `crashes/` directory to container
  - **Important**: This persists crashes even after `docker rm`
  - Creates the directory if it doesn't exist
- `--cpus="4"`: Limit to 4 CPU cores
- `--memory="4g"`: Limit to 4GB of RAM
- `--restart=unless-stopped`: Automatically restart container if it crashes
- `-it`: Interactive mode with terminal (for foreground execution)
- `./target/release/libfuzzer_dav1d_concolic`: Pre-built binary (faster startup than `cargo run`)

### Complete Example Workflow Without Docker Compose

```bash
# 1. Build the image from LibAFL root
cd /path/to/LibAFL
docker build -f fuzzers/structure_aware/libfuzzer_dav1d/Dockerfile -t libafl-dav1d .

# 2. Create output directories
mkdir -p crashes corpus_output solutions

# 3. Start fuzzing in detached mode with all volumes mounted
docker run -d --name libfuzzer_dav1d \
  --restart=unless-stopped \
  --cpus="4" \
  --memory="4g" \
  -v $(pwd)/crashes:/fuzzer/fuzzer/crashes \
  -v $(pwd)/corpus_output:/fuzzer/fuzzer/corpus \
  -v $(pwd)/solutions:/fuzzer/fuzzer/solutions \
  libafl-dav1d

# 4. Monitor progress
docker logs -f libfuzzer_dav1d

# 5. Check for crashes (even while running)
ls -lh crashes/

# 6. Stop fuzzing
docker stop libfuzzer_dav1d

# 7. Remove container (crashes are safe in mounted volume)
docker rm libfuzzer_dav1d

# 8. View results
ls -lh crashes/
echo "Total crashes: $(find crashes -type f | wc -l)"
```

## Manual Setup

### Prerequisites

```bash
# Ubuntu/Debian
sudo apt install clang meson ninja-build nasm libaom-tools python3

# Install Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# Install just
cargo install just
```

### Build and Run

```bash
# Build everything
just build

# Generate corpus
python3 generate_corpus.py corpus

# Run fuzzer
cd fuzzer && cargo run --release
```

## Usage

### Standard Fuzzing
```bash
cd fuzzer
# Using pre-built binary (recommended)
./target/release/libfuzzer_dav1d_concolic

# Or rebuild and run
cargo run --release
```

### Concolic Mode
```bash
cd fuzzer
# Using pre-built binary (recommended)
./target/release/libfuzzer_dav1d_concolic --concolic

# Or rebuild and run
cargo run --release -- --concolic
```

### Corpus Generation
```bash
# Generate default corpus
python3 generate_corpus.py corpus

# Generate to custom directory
python3 generate_corpus.py /path/to/corpus
```

The corpus includes:
- Various resolutions and block sizes
- Inter-frame prediction (motion vectors)
- Different encoding parameters
- Multi-frame sequences
- 10-bit and 12-bit color depths
- Different chroma formats
- AV1-specific features (warped motion, etc.)

## Output

- Crashes saved to: `fuzzer/crashes/`
- Corpus files in: `corpus/`
- Coverage: ~56% line coverage with generated corpus

## Docker Details

### Performance Optimization

The Docker image is optimized for **instant startup** by using pre-built binaries:

- **Build time**: Fuzzer is compiled during image creation (`docker build`)
- **Run time**: Pre-built binary executes immediately (no compilation)
- **Command**: `./target/release/libfuzzer_dav1d_concolic` instead of `cargo run --release`

**Benefits:**
- ✅ **Instant startup** - Container starts fuzzing immediately
- ✅ **Lower memory usage** - No cargo overhead during execution
- ✅ **Consistent performance** - Same optimized binary every run
- ✅ **Faster restarts** - Quick recovery from crashes

This means when you run `docker-compose up -d`, fuzzing begins within seconds, not minutes.

### Docker Compose Configuration

The `docker-compose.yml` file provides two services:

1. **libfuzzer_dav1d** (default): Standard fuzzing mode
   - Starts with: `docker-compose up -d`
   - Outputs to: `./crashes/`, `./corpus_output/`, `./solutions/`

2. **libfuzzer_dav1d_concolic**: Concolic execution mode (requires `--profile concolic`)
   - Starts with: `docker-compose --profile concolic up -d libfuzzer_dav1d_concolic`
   - Outputs to: `./crashes_concolic/`, `./corpus_concolic/`, `./solutions_concolic/`

Both services:
- Automatically build from the LibAFL root directory
- Mount output directories for persistence
- Set resource limits (4 CPU cores, 4GB RAM max)
- Restart on failure unless manually stopped
- Can be customized via environment variables

**Important**: The docker-compose build context is set to `../../..` (LibAFL root) because it needs access to the `crates/` directory for dependencies.

### Dockerfile Build Process

The Dockerfile:
1. Uses rust:1.91.0 (Debian-based) as the base image
2. Installs all dependencies (clang, meson, nasm, aomenc, etc.)
3. Copies necessary crates for symcc_runtime dependency
4. Builds dav1d library with coverage instrumentation
5. Generates AV1 corpus with aomenc
6. Builds the concolic runtime
7. Builds the fuzzer in release mode
8. Runs the pre-built binary directly (fast startup)

### Manual Docker Build

If not using docker-compose:

```bash
cd /path/to/LibAFL
docker build -f fuzzers/structure_aware/libfuzzer_dav1d/Dockerfile -t libafl-dav1d .
```

## Troubleshooting

### Docker Compose

#### Build fails
Make sure you have enough disk space and memory. The build requires ~2GB.

```bash
# Clean up old containers and rebuild
docker-compose down
docker-compose build --no-cache
```

#### Container keeps restarting
Check the logs for errors:
```bash
docker-compose logs -f
```

#### Permission issues with mounted volumes
The fuzzer runs as root inside the container. To fix permissions:
```bash
sudo chown -R $(id -u):$(id -g) crashes/ corpus_output/ solutions/
```

Or modify docker-compose.yml to add:
```yaml
user: "${UID}:${GID}"
```

#### View container status
```bash
docker-compose ps
docker-compose top
```

#### Stop and remove all containers
```bash
docker-compose down
# Or to also remove volumes:
docker-compose down -v
```

### Manual Docker

#### No crashes directory
```bash
mkdir -p fuzzer/crashes
```

#### Permission issues in Docker
```bash
docker run -it --user $(id -u):$(id -g) -v $(pwd)/crashes:/fuzzer/fuzzer/crashes libafl-dav1d
```

## Architecture

- **harness.c**: LibFuzzer-compatible harness for in-process fuzzing
- **harness_symcc.c**: Standalone harness for SymCC concolic execution  
- **main.rs**: LibAFL fuzzer orchestration
- **generate_corpus.py**: Corpus generator using aomenc

The fuzzer targets the dav1d decoder's block-level decoding functions with a focus on inter-frame prediction, motion compensation, and AV1-specific features.
