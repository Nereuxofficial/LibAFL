#!/usr/bin/env bash
# Container build helper script for LibAFL dav1d fuzzer
# Auto-detects Podman or Docker and builds the image from the correct directory

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIBAFL_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[⚠]${NC} $1"
}

print_step() {
    echo -e "${CYAN}▶${NC} $1"
}

echo "╔════════════════════════════════════════════════════════════════════╗"
echo "║        LibAFL dav1d Fuzzer - Container Build Helper               ║"
echo "╚════════════════════════════════════════════════════════════════════╝"
echo

# Detect container runtime (Podman or Docker)
CONTAINER_CMD=""
if command -v podman &> /dev/null; then
    CONTAINER_CMD="podman"
    print_success "Detected Podman: $(podman --version)"
elif command -v docker &> /dev/null; then
    CONTAINER_CMD="docker"
    print_success "Detected Docker: $(docker --version)"
else
    print_error "Neither Podman nor Docker found!"
    echo
    echo "Please install one of:"
    echo "  - Podman: sudo apt install podman (recommended for rootless)"
    echo "  - Docker: sudo apt install docker.io"
    exit 1
fi
echo

print_info "Script directory: $SCRIPT_DIR"
print_info "LibAFL root: $LIBAFL_ROOT"
print_info "Container runtime: $CONTAINER_CMD"
echo

# Check if we're in the right place
if [ ! -f "$LIBAFL_ROOT/Cargo.toml" ]; then
    print_error "Cannot find LibAFL root directory!"
    print_error "Expected Cargo.toml at: $LIBAFL_ROOT/Cargo.toml"
    exit 1
fi

if [ ! -f "$SCRIPT_DIR/Dockerfile" ]; then
    print_error "Cannot find Dockerfile at: $SCRIPT_DIR/Dockerfile"
    exit 1
fi

print_success "Found LibAFL root directory"
print_success "Found Dockerfile"
echo

# Change to LibAFL root
cd "$LIBAFL_ROOT"
print_info "Changed to LibAFL root: $(pwd)"
echo

# Build the container image
IMAGE_NAME="${1:-libafl-dav1d}"
print_step "Building container image: $IMAGE_NAME"
print_info "Build context: $(pwd)"
print_info "Dockerfile: fuzzers/structure_aware/libfuzzer_dav1d/Dockerfile"
echo

print_warning "This may take 10-20 minutes depending on your system..."
echo

# Run container build
$CONTAINER_CMD build \
    -f fuzzers/structure_aware/libfuzzer_dav1d/Dockerfile \
    -t "$IMAGE_NAME" \
    .

if [ $? -eq 0 ]; then
    echo
    echo "╔════════════════════════════════════════════════════════════════════╗"
    echo "║                    BUILD SUCCESSFUL!                               ║"
    echo "╚════════════════════════════════════════════════════════════════════╝"
    echo
    print_success "Container image built: $IMAGE_NAME"
    echo
    echo "═══════════════════════════════════════════════════════════════════"
    echo "  NEXT STEPS"
    echo "═══════════════════════════════════════════════════════════════════"
    echo
    echo "1. Run interactively:"
    echo "   $CONTAINER_CMD run -it $IMAGE_NAME"
    echo
    echo "2. Run in background with volume mounts:"
    echo "   cd fuzzers/structure_aware/libfuzzer_dav1d"
    echo "   $CONTAINER_CMD run -d --name libfuzzer_dav1d \\"
    echo "     -v \$(pwd)/crashes:/fuzzer/fuzzer/crashes \\"
    echo "     -v \$(pwd)/corpus_output:/fuzzer/fuzzer/corpus \\"
    echo "     -v \$(pwd)/solutions:/fuzzer/fuzzer/solutions \\"
    echo "     $IMAGE_NAME"
    echo
    echo "3. Run with Podman-compose (if installed):"
    echo "   cd fuzzers/structure_aware/libfuzzer_dav1d"
    echo "   podman-compose up -d"
    echo
    echo "4. View running containers:"
    echo "   $CONTAINER_CMD ps"
    echo
    echo "5. View logs:"
    echo "   $CONTAINER_CMD logs -f libfuzzer_dav1d"
    echo
    echo "6. Stop and remove:"
    echo "   $CONTAINER_CMD stop libfuzzer_dav1d"
    echo "   $CONTAINER_CMD rm libfuzzer_dav1d"
    echo
    echo "═══════════════════════════════════════════════════════════════════"
    echo
else
    echo
    print_error "Container build failed!"
    echo
    echo "Common issues:"
    echo "  1. Not enough disk space (need ~2GB)"
    echo "  2. Network issues downloading dependencies"
    echo "  3. Insufficient memory (need ~4GB RAM)"
    echo
    echo "For rootless Podman issues, try:"
    echo "  - Check subuid/subgid: cat /etc/subuid /etc/subgid"
    echo "  - Reset Podman: podman system reset --force"
    echo "  - Run with sudo (not recommended): sudo $CONTAINER_CMD build ..."
    echo
    exit 1
fi
