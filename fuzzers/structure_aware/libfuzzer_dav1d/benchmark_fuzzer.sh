#!/usr/bin/env bash
# Benchmark script for LibAFL dav1d fuzzer
# Measures executions per second before and after harness optimizations

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

# Configuration
BENCHMARK_DURATION=${1:-60}  # Default 60 seconds
CORPUS_DIR="corpus"
TEMP_CORPUS="benchmark_corpus"
BENCHMARK_LOG="benchmark_results.log"

print_info "==================================================================="
print_info "LibAFL dav1d Fuzzer Performance Benchmark"
print_info "==================================================================="
print_info "Duration: ${BENCHMARK_DURATION} seconds"
print_info ""

# Check if fuzzer binary exists
if [ ! -f "fuzzer/target/release/libfuzzer_dav1d_concolic" ]; then
    print_error "Fuzzer binary not found. Building..."
    cd fuzzer
    cargo build --release
    cd ..
fi

# Check corpus
if [ ! -d "$CORPUS_DIR" ] || [ -z "$(ls -A $CORPUS_DIR)" ]; then
    print_error "Corpus directory is empty or missing"
    exit 1
fi

CORPUS_SIZE=$(find "$CORPUS_DIR" -type f | wc -l)
print_info "Corpus size: $CORPUS_SIZE files"
print_info ""

# Create temporary corpus for benchmark (to avoid modifying original)
print_info "Creating temporary benchmark corpus..."
rm -rf "$TEMP_CORPUS"
cp -r "$CORPUS_DIR" "$TEMP_CORPUS"

# Function to run benchmark
run_benchmark() {
    local label=$1
    local output_file=$2

    print_info "-------------------------------------------------------------------"
    print_info "Running benchmark: $label"
    print_info "-------------------------------------------------------------------"

    # Create temporary output directories
    local temp_out="benchmark_temp_$$"
    mkdir -p "$temp_out/crashes" "$temp_out/solutions"

    # Run fuzzer for specified duration
    print_info "Fuzzing for ${BENCHMARK_DURATION} seconds..."

    # Use timeout to limit execution time
    # Capture last 50 lines which contain stats
    timeout ${BENCHMARK_DURATION}s ./fuzzer/target/release/libfuzzer_dav1d_concolic \
        "$TEMP_CORPUS" \
        > "$output_file" 2>&1 || true

    # Clean up temp directories
    rm -rf "$temp_out"

    print_success "Benchmark complete: $label"
    print_info ""
}

# Function to parse results
parse_results() {
    local log_file=$1
    local label=$2

    # Extract statistics from the log
    local total_execs=$(grep -oP 'executions: \K\d+' "$log_file" | tail -1)
    local exec_per_sec=$(grep -oP 'exec/sec: \K[0-9.]+' "$log_file" | tail -1)
    local corpus_size=$(grep -oP 'corpus: \K\d+' "$log_file" | tail -1)
    local coverage=$(grep -oP 'edges: \K[0-9.]+%' "$log_file" | tail -1)
    local objectives=$(grep -oP 'objectives: \K\d+' "$log_file" | tail -1)

    # Calculate average exec/sec from multiple samples
    local avg_exec_sec=$(grep -oP 'exec/sec: \K[0-9.]+' "$log_file" | awk '{sum+=$1; count++} END {if(count>0) printf "%.2f", sum/count; else print "0"}')

    # Get peak exec/sec
    local peak_exec_sec=$(grep -oP 'exec/sec: \K[0-9.]+' "$log_file" | sort -n | tail -1)

    echo ""
    echo "=========================================="
    echo "$label - Results"
    echo "=========================================="
    echo "Total Executions:    ${total_execs:-N/A}"
    echo "Final Exec/sec:      ${exec_per_sec:-N/A}"
    echo "Average Exec/sec:    ${avg_exec_sec:-N/A}"
    echo "Peak Exec/sec:       ${peak_exec_sec:-N/A}"
    echo "Final Corpus Size:   ${corpus_size:-N/A}"
    echo "Coverage:            ${coverage:-N/A}"
    echo "Objectives Found:    ${objectives:-0}"
    echo "=========================================="
    echo ""

    # Store results for comparison
    echo "$label|$total_execs|$exec_per_sec|$avg_exec_sec|$peak_exec_sec|$corpus_size|$coverage|$objectives" >> "$BENCHMARK_LOG.tmp"
}

# Function to calculate improvement
calculate_improvement() {
    if [ ! -f "$BENCHMARK_LOG.tmp" ]; then
        print_error "No benchmark results found"
        return
    fi

    # Read results
    local before_line=$(grep "BEFORE" "$BENCHMARK_LOG.tmp")
    local after_line=$(grep "AFTER" "$BENCHMARK_LOG.tmp")

    if [ -z "$before_line" ] || [ -z "$after_line" ]; then
        print_warning "Incomplete benchmark data"
        return
    fi

    # Parse values
    local before_avg=$(echo "$before_line" | cut -d'|' -f4)
    local after_avg=$(echo "$after_line" | cut -d'|' -f4)
    local before_peak=$(echo "$before_line" | cut -d'|' -f5)
    local after_peak=$(echo "$after_line" | cut -d'|' -f5)

    # Calculate improvement percentage
    if [ -n "$before_avg" ] && [ -n "$after_avg" ] && [ "$before_avg" != "0" ]; then
        local improvement=$(echo "scale=2; (($after_avg - $before_avg) / $before_avg) * 100" | bc)
        local peak_improvement=$(echo "scale=2; (($after_peak - $before_peak) / $before_peak) * 100" | bc)

        echo ""
        echo "=========================================="
        echo "PERFORMANCE IMPROVEMENT SUMMARY"
        echo "=========================================="
        echo "Average Exec/sec:"
        echo "  Before:  $before_avg"
        echo "  After:   $after_avg"
        echo "  Change:  ${improvement}%"
        echo ""
        echo "Peak Exec/sec:"
        echo "  Before:  $before_peak"
        echo "  After:   $after_peak"
        echo "  Change:  ${peak_improvement}%"
        echo "=========================================="
        echo ""

        if (( $(echo "$improvement > 0" | bc -l) )); then
            print_success "Performance IMPROVED by ${improvement}%"
        elif (( $(echo "$improvement < 0" | bc -l) )); then
            print_warning "Performance DECREASED by ${improvement}%"
        else
            print_info "Performance unchanged"
        fi
    fi
}

# Main benchmark flow
main() {
    # Clean up old results
    rm -f "$BENCHMARK_LOG" "$BENCHMARK_LOG.tmp"

    print_info "Starting benchmark sequence..."
    print_info ""

    # Check if we should run BEFORE benchmark
    if [ "${SKIP_BEFORE:-0}" = "0" ]; then
        run_benchmark "BEFORE OPTIMIZATION" "benchmark_before.log"
        parse_results "benchmark_before.log" "BEFORE"
    else
        print_warning "Skipping BEFORE benchmark (SKIP_BEFORE=1)"
    fi

    # Check if we should run AFTER benchmark
    if [ "${SKIP_AFTER:-0}" = "0" ]; then
        # Prompt to rebuild with optimizations
        if [ "${SKIP_BEFORE:-0}" = "0" ]; then
            print_warning "Please rebuild the fuzzer with optimized harness now"
            print_info "Run: cd fuzzer && cargo build --release && cd .."
            read -p "Press Enter when ready to benchmark optimized version..."
        fi

        run_benchmark "AFTER OPTIMIZATION" "benchmark_after.log"
        parse_results "benchmark_after.log" "AFTER"
    else
        print_warning "Skipping AFTER benchmark (SKIP_AFTER=1)"
    fi

    # Calculate and display improvement
    calculate_improvement

    # Save full results
    if [ -f "$BENCHMARK_LOG.tmp" ]; then
        mv "$BENCHMARK_LOG.tmp" "$BENCHMARK_LOG"
        print_success "Full results saved to: $BENCHMARK_LOG"
    fi

    # Clean up
    rm -rf "$TEMP_CORPUS"

    print_info ""
    print_success "Benchmark complete!"
    print_info "Detailed logs:"
    print_info "  - benchmark_before.log"
    print_info "  - benchmark_after.log"
    print_info "  - $BENCHMARK_LOG"
}

# Allow running only specific benchmarks
case "${2:-}" in
    before)
        SKIP_AFTER=1
        main
        ;;
    after)
        SKIP_BEFORE=1
        main
        ;;
    *)
        main
        ;;
esac
