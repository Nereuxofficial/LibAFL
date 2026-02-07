#!/usr/bin/env bash
# LibAFL dav1d Fuzzer Management Script
# This script provides convenient commands to manage the fuzzer via docker-compose

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUSTFLAGS="-C target-cpu=native"
cd "$SCRIPT_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored messages
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to show usage
show_usage() {
    cat << EOF
LibAFL dav1d Fuzzer Management Script

Usage: $0 <command> [options]

Commands:
    start               Start the fuzzer in standard mode
    start-concolic      Start the fuzzer in concolic mode
    start-both          Start both standard and concolic fuzzers
    stop                Stop the fuzzer
    stop-all            Stop all running fuzzers
    restart             Restart the fuzzer
    status              Show fuzzer status
    logs                Show fuzzer logs (follow mode)
    logs-tail [n]       Show last n lines of logs (default: 100)
    stats               Show fuzzing statistics
    build               Build the Docker image
    rebuild             Rebuild the Docker image (no cache)
    clean               Stop and remove containers, networks
    clean-all           Stop containers and remove all data (crashes, corpus, etc.)
    shell               Open a shell in the running container
    inspect             Inspect the fuzzer container
    export-crashes      Export crashes to ./exported_crashes/
    help                Show this help message

Examples:
    $0 start                    # Start standard fuzzer
    $0 start-concolic           # Start concolic fuzzer
    $0 logs                     # Watch logs in real-time
    $0 stats                    # Show fuzzing progress
    $0 clean-all                # Remove everything and start fresh

Output Directories:
    ./crashes/          - Crash-inducing inputs (standard mode)
    ./corpus_output/    - Evolved corpus (standard mode)
    ./solutions/        - Solution inputs (standard mode)
    ./crashes_concolic/ - Crashes from concolic mode
    ./corpus_concolic/  - Corpus from concolic mode
    ./solutions_concolic/ - Solutions from concolic mode

EOF
}

# Function to check if docker-compose is available
check_docker_compose() {
    if command -v docker-compose &> /dev/null; then
        DOCKER_COMPOSE="docker-compose"
    elif docker compose version &> /dev/null; then
        DOCKER_COMPOSE="docker compose"
    else
        print_error "docker-compose or 'docker compose' not found. Please install Docker Compose."
        exit 1
    fi
}

# Function to create output directories
create_directories() {
    print_info "Creating output directories..."
    mkdir -p crashes corpus_output solutions
    mkdir -p crashes_concolic corpus_concolic solutions_concolic
    print_success "Output directories created"
}

# Function to start standard fuzzer
start_fuzzer() {
    print_info "Starting LibAFL dav1d fuzzer (standard mode)..."
    create_directories
    $DOCKER_COMPOSE up -d libfuzzer_dav1d
    print_success "Fuzzer started in detached mode"
    print_info "View logs with: $0 logs"
    print_info "Check status with: $0 status"
}

# Function to start concolic fuzzer
start_concolic() {
    print_info "Starting LibAFL dav1d fuzzer (concolic mode)..."
    create_directories
    $DOCKER_COMPOSE --profile concolic up -d libfuzzer_dav1d_concolic
    print_success "Concolic fuzzer started in detached mode"
    print_info "View logs with: $0 logs"
    print_info "Check status with: $0 status"
}

# Function to start both fuzzers
start_both() {
    print_info "Starting both standard and concolic fuzzers..."
    create_directories
    $DOCKER_COMPOSE up -d libfuzzer_dav1d
    $DOCKER_COMPOSE --profile concolic up -d libfuzzer_dav1d_concolic
    print_success "Both fuzzers started in detached mode"
    print_info "View logs with: $0 logs"
    print_info "Check status with: $0 status"
}

# Function to stop fuzzer
stop_fuzzer() {
    print_info "Stopping fuzzer..."
    $DOCKER_COMPOSE stop
    print_success "Fuzzer stopped"
}

# Function to stop all fuzzers
stop_all() {
    print_info "Stopping all fuzzers..."
    $DOCKER_COMPOSE --profile concolic stop
    print_success "All fuzzers stopped"
}

# Function to restart fuzzer
restart_fuzzer() {
    print_info "Restarting fuzzer..."
    $DOCKER_COMPOSE restart
    print_success "Fuzzer restarted"
}

# Function to show status
show_status() {
    print_info "Fuzzer status:"
    $DOCKER_COMPOSE ps
    echo ""
    print_info "Resource usage:"
    $DOCKER_COMPOSE top || true
}

# Function to show logs
show_logs() {
    print_info "Showing fuzzer logs (Ctrl+C to exit)..."
    $DOCKER_COMPOSE logs -f
}

# Function to show tail logs
show_logs_tail() {
    local lines="${1:-100}"
    print_info "Showing last $lines lines of logs..."
    $DOCKER_COMPOSE logs --tail="$lines"
}

# Function to show stats
show_stats() {
    print_info "Fuzzing statistics:"
    echo ""

    if [ -d "crashes" ]; then
        local crash_count=$(find crashes -type f 2>/dev/null | wc -l)
        echo -e "${GREEN}Standard Mode:${NC}"
        echo "  Crashes found: $crash_count"
        if [ -d "corpus_output" ]; then
            local corpus_count=$(find corpus_output -type f 2>/dev/null | wc -l)
            echo "  Corpus size: $corpus_count"
        fi
        if [ -d "solutions" ]; then
            local solution_count=$(find solutions -type f 2>/dev/null | wc -l)
            echo "  Solutions: $solution_count"
        fi
    fi

    echo ""

    if [ -d "crashes_concolic" ]; then
        local crash_count=$(find crashes_concolic -type f 2>/dev/null | wc -l)
        echo -e "${YELLOW}Concolic Mode:${NC}"
        echo "  Crashes found: $crash_count"
        if [ -d "corpus_concolic" ]; then
            local corpus_count=$(find corpus_concolic -type f 2>/dev/null | wc -l)
            echo "  Corpus size: $corpus_count"
        fi
        if [ -d "solutions_concolic" ]; then
            local solution_count=$(find solutions_concolic -type f 2>/dev/null | wc -l)
            echo "  Solutions: $solution_count"
        fi
    fi

    echo ""
    print_info "Container stats:"
    docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}" \
        $(docker ps --filter "name=libfuzzer_dav1d" -q 2>/dev/null) 2>/dev/null || echo "No running containers"
}

# Function to build image
build_image() {
    print_info "Building Docker image..."
    $DOCKER_COMPOSE build
    print_success "Docker image built successfully"
}

# Function to rebuild image
rebuild_image() {
    print_info "Rebuilding Docker image (no cache)..."
    $DOCKER_COMPOSE build --no-cache
    print_success "Docker image rebuilt successfully"
}

# Function to clean up
clean() {
    print_warning "Stopping containers and cleaning up..."
    $DOCKER_COMPOSE --profile concolic down
    print_success "Cleanup complete"
    print_info "Output directories preserved: crashes/, corpus_output/, solutions/"
}

# Function to clean all including data
clean_all() {
    print_warning "This will remove all containers and data (crashes, corpus, solutions)!"
    read -p "Are you sure? (yes/no): " confirm
    if [ "$confirm" = "yes" ]; then
        print_info "Stopping containers..."
        $DOCKER_COMPOSE --profile concolic down -v
        print_info "Removing output directories..."
        rm -rf crashes/ crashes_concolic/
        rm -rf corpus_output/ corpus_concolic/
        rm -rf solutions/ solutions_concolic/
        print_success "All data removed"
    else
        print_info "Aborted"
    fi
}

# Function to open shell
open_shell() {
    print_info "Opening shell in fuzzer container..."
    if $DOCKER_COMPOSE ps | grep -q "libfuzzer_dav1d.*Up"; then
        $DOCKER_COMPOSE exec libfuzzer_dav1d /bin/bash
    else
        print_error "Fuzzer container is not running. Start it first with: $0 start"
        exit 1
    fi
}

# Function to inspect container
inspect_container() {
    print_info "Inspecting fuzzer container..."
    docker inspect libfuzzer_dav1d 2>/dev/null || print_error "Container not found"
}

# Function to export crashes
export_crashes() {
    print_info "Exporting crashes..."
    local export_dir="./exported_crashes/$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$export_dir"

    if [ -d "crashes" ] && [ "$(ls -A crashes 2>/dev/null)" ]; then
        cp -r crashes "$export_dir/standard/"
        print_success "Standard mode crashes exported to: $export_dir/standard/"
    fi

    if [ -d "crashes_concolic" ] && [ "$(ls -A crashes_concolic 2>/dev/null)" ]; then
        cp -r crashes_concolic "$export_dir/concolic/"
        print_success "Concolic mode crashes exported to: $export_dir/concolic/"
    fi

    if [ ! -d "$export_dir/standard" ] && [ ! -d "$export_dir/concolic" ]; then
        print_warning "No crashes found to export"
        rmdir "$export_dir"
    else
        print_success "Crashes exported to: $export_dir"
    fi
}

# Main script logic
main() {
    check_docker_compose

    if [ $# -eq 0 ]; then
        show_usage
        exit 0
    fi

    case "$1" in
        start)
            start_fuzzer
            ;;
        start-concolic)
            start_concolic
            ;;
        start-both)
            start_both
            ;;
        stop)
            stop_fuzzer
            ;;
        stop-all)
            stop_all
            ;;
        restart)
            restart_fuzzer
            ;;
        status)
            show_status
            ;;
        logs)
            show_logs
            ;;
        logs-tail)
            show_logs_tail "$2"
            ;;
        stats)
            show_stats
            ;;
        build)
            build_image
            ;;
        rebuild)
            rebuild_image
            ;;
        clean)
            clean
            ;;
        clean-all)
            clean_all
            ;;
        shell)
            open_shell
            ;;
        inspect)
            inspect_container
            ;;
        export-crashes)
            export_crashes
            ;;
        help|--help|-h)
            show_usage
            ;;
        *)
            print_error "Unknown command: $1"
            echo ""
            show_usage
            exit 1
            ;;
    esac
}

main "$@"
