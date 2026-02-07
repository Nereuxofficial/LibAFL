#!/usr/bin/env bash
# Comprehensive workflow script to improve fuzzer corpus coverage and speed
# This script automates:
# 1. Generating enhanced corpus with advanced AV1 features
# 2. Merging with existing corpus and seed corpus
# 3. Minimizing corpus to remove redundancy
# 4. Analyzing final coverage

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

print_header() {
    echo -e "${MAGENTA}╔════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}║${NC} $1${MAGENTA}${NC}"
    echo -e "${MAGENTA}╚════════════════════════════════════════════════════════════════════╝${NC}"
}

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[⚠]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

print_step() {
    echo -e "${CYAN}▶${NC} $1"
}

# Function to check prerequisites
check_prerequisites() {
    print_header "CHECKING PREREQUISITES"

    local missing=0

    # Check for Python3
    if ! command -v python3 &> /dev/null; then
        print_error "python3 not found"
        missing=1
    else
        print_success "python3 found: $(python3 --version)"
    fi

    # Check for aomenc
    if ! command -v aomenc &> /dev/null; then
        print_error "aomenc not found"
        print_info "Install with: sudo apt install libaom-tools (Ubuntu/Debian)"
        missing=1
    else
        print_success "aomenc found: $(aomenc --help | head -1 | cut -d' ' -f1-2)"
    fi

    # Check for required scripts
    if [ ! -f "generate_corpus.py" ]; then
        print_error "generate_corpus.py not found"
        missing=1
    else
        print_success "generate_corpus.py found"
    fi

    if [ ! -f "generate_enhanced_corpus.py" ]; then
        print_error "generate_enhanced_corpus.py not found"
        missing=1
    else
        print_success "generate_enhanced_corpus.py found"
    fi

    if [ ! -f "minimize_corpus.py" ]; then
        print_error "minimize_corpus.py not found"
        missing=1
    else
        print_success "minimize_corpus.py found"
    fi

    if [ $missing -eq 1 ]; then
        print_error "Missing prerequisites. Please install required tools."
        exit 1
    fi

    echo
}

# Function to backup existing corpus
backup_corpus() {
    print_header "BACKING UP EXISTING CORPUS"

    if [ -d "corpus" ] && [ "$(ls -A corpus 2>/dev/null)" ]; then
        local backup_dir="corpus_backup_$(date +%Y%m%d_%H%M%S)"
        print_step "Creating backup: $backup_dir"
        cp -r corpus "$backup_dir"
        print_success "Backup created: $backup_dir"
    else
        print_info "No existing corpus to backup"
    fi

    echo
}

# Function to extract seed corpus
extract_seed_corpus() {
    print_header "EXTRACTING SEED CORPUS"

    if [ -f "dec_fuzzer_seed_corpus.zip" ]; then
        if [ -d "corpus_seed" ]; then
            print_info "Seed corpus already extracted"
        else
            print_step "Extracting seed corpus from dec_fuzzer_seed_corpus.zip"
            unzip -q dec_fuzzer_seed_corpus.zip -d corpus_seed
            local num_files=$(find corpus_seed -type f -name "*.ivf" | wc -l)
            print_success "Extracted $num_files seed files"
        fi
    else
        print_warning "dec_fuzzer_seed_corpus.zip not found, skipping seed corpus"
    fi

    echo
}

# Function to generate basic corpus
generate_basic_corpus() {
    print_header "GENERATING BASIC CORPUS"

    if [ ! -d "corpus" ] || [ -z "$(ls -A corpus 2>/dev/null)" ]; then
        print_step "Generating basic corpus with various AV1 features"
        python3 generate_corpus.py corpus
        local num_files=$(find corpus -type f -name "*.ivf" 2>/dev/null | wc -l)
        print_success "Generated $num_files basic corpus files"
    else
        print_info "Basic corpus already exists ($(find corpus -type f -name "*.ivf" 2>/dev/null | wc -l) files)"
    fi

    echo
}

# Function to generate enhanced corpus
generate_enhanced_corpus() {
    print_header "GENERATING ENHANCED CORPUS (Advanced AV1 Features)"

    print_step "Creating corpus with advanced features for maximum coverage"
    print_info "This targets:"
    echo "  • CDEF filtering with multiple strengths"
    echo "  • Loop restoration filters (Wiener & Self-Guided)"
    echo "  • Film grain synthesis"
    echo "  • Global motion (rotation, zoom, translation)"
    echo "  • Screen content coding (palette mode, intra block copy)"
    echo "  • Multiple reference frames (up to 7)"
    echo "  • Large superblocks (128x128)"
    echo "  • Delta quantizer and loop filter"
    echo "  • Compound prediction modes & OBMC"
    echo "  • Various transform types"
    echo "  • Different keyframe patterns"
    echo "  • High bit depths (10-bit, 12-bit) & chroma formats"
    echo

    print_step "Generating enhanced corpus..."
    python3 generate_enhanced_corpus.py corpus_enhanced

    local num_files=$(find corpus_enhanced -type f -name "*.ivf" 2>/dev/null | wc -l)
    print_success "Generated $num_files enhanced corpus files"

    echo
}

# Function to merge all corpuses
merge_corpuses() {
    print_header "MERGING ALL CORPUSES"

    local dirs_to_merge=""
    local total_input=0

    # Check which corpus directories exist
    if [ -d "corpus" ]; then
        local count=$(find corpus -type f -name "*.ivf" 2>/dev/null | wc -l)
        if [ $count -gt 0 ]; then
            dirs_to_merge="$dirs_to_merge corpus"
            total_input=$((total_input + count))
            print_info "Basic corpus: $count files"
        fi
    fi

    if [ -d "corpus_enhanced" ]; then
        local count=$(find corpus_enhanced -type f -name "*.ivf" 2>/dev/null | wc -l)
        if [ $count -gt 0 ]; then
            dirs_to_merge="$dirs_to_merge corpus_enhanced"
            total_input=$((total_input + count))
            print_info "Enhanced corpus: $count files"
        fi
    fi

    if [ -d "corpus_seed" ]; then
        local count=$(find corpus_seed -type f -name "*.ivf" 2>/dev/null | wc -l)
        if [ $count -gt 0 ]; then
            dirs_to_merge="$dirs_to_merge corpus_seed"
            total_input=$((total_input + count))
            print_info "Seed corpus: $count files"
        fi
    fi

    if [ -z "$dirs_to_merge" ]; then
        print_error "No corpus directories found to merge"
        exit 1
    fi

    print_step "Merging $total_input total files from: $dirs_to_merge"
    python3 minimize_corpus.py $dirs_to_merge --merge --output=corpus_merged

    local merged_count=$(find corpus_merged -type f -name "*.ivf" 2>/dev/null | wc -l)
    print_success "Merged corpus: $merged_count unique files"
    print_info "Removed $((total_input - merged_count)) duplicate files"

    echo
}

# Function to minimize corpus
minimize_corpus() {
    print_header "MINIMIZING CORPUS"

    print_step "Running intelligent minimization to reduce redundancy"
    print_info "This will:"
    echo "  • Remove duplicate files (by content hash)"
    echo "  • Remove oversized files"
    echo "  • Keep diverse representatives from each feature category"
    echo "  • Optimize for fast fuzzing execution"
    echo

    print_step "Minimizing merged corpus..."
    python3 minimize_corpus.py corpus_merged --output=corpus_final --method=diversity --max-size=100000

    local final_count=$(find corpus_final -type f -name "*.ivf" 2>/dev/null | wc -l)
    print_success "Final minimized corpus: $final_count files"

    echo
}

# Function to analyze corpus
analyze_corpus() {
    print_header "CORPUS ANALYSIS"

    print_step "Analyzing final corpus coverage..."

    python3 << 'EOF'
import os
from pathlib import Path

def get_dir_stats(dir_path):
    if not os.path.exists(dir_path):
        return 0, 0
    files = list(Path(dir_path).rglob("*.ivf"))
    total_size = sum(os.path.getsize(f) for f in files)
    return len(files), total_size

def analyze_features(dir_path):
    if not os.path.exists(dir_path):
        return {}

    features = {
        'Inter-frame prediction': 0,
        'Intra prediction': 0,
        'High bit depth (10/12-bit)': 0,
        'Tiles': 0,
        'Warped motion': 0,
        'Chroma formats (444/422)': 0,
        'Multi-frame sequences': 0,
        'CDEF filtering': 0,
        'Loop restoration': 0,
        'Film grain': 0,
        'Global motion': 0,
        'Screen content coding': 0,
        'Compound prediction': 0,
        'OBMC': 0,
        'Multiple reference frames': 0,
        'Large superblocks': 0,
        'Advanced transforms': 0,
        'Delta-Q/Delta-LF': 0,
    }

    files = list(Path(dir_path).rglob("*.ivf"))

    for f in files:
        name = f.name.lower()
        if 'inter_' in name or 'moving_' in name:
            features['Inter-frame prediction'] += 1
        if 'intra_' in name:
            features['Intra prediction'] += 1
        if '10bit' in name or '12bit' in name:
            features['High bit depth (10/12-bit)'] += 1
        if 'tile' in name:
            features['Tiles'] += 1
        if 'warped' in name:
            features['Warped motion'] += 1
        if 'chroma' in name or '444' in name or '422' in name:
            features['Chroma formats (444/422)'] += 1
        if 'multiframe' in name or 'kf_' in name:
            features['Multi-frame sequences'] += 1
        if 'cdef' in name:
            features['CDEF filtering'] += 1
        if 'restoration' in name or 'wiener' in name or 'sgrproj' in name:
            features['Loop restoration'] += 1
        if 'grain' in name:
            features['Film grain'] += 1
        if 'global_motion' in name or 'rotating' in name or 'zooming' in name:
            features['Global motion'] += 1
        if 'screen' in name or 'palette' in name or 'intrabc' in name:
            features['Screen content coding'] += 1
        if 'compound' in name:
            features['Compound prediction'] += 1
        if 'obmc' in name:
            features['OBMC'] += 1
        if 'refs_' in name or 'ref' in name:
            features['Multiple reference frames'] += 1
        if 'superblock' in name or 'sb128' in name or 'sb64' in name:
            features['Large superblocks'] += 1
        if 'tx_' in name or 'transform' in name:
            features['Advanced transforms'] += 1
        if 'delta' in name:
            features['Delta-Q/Delta-LF'] += 1

    return features

# Compare corpuses
print("\n📊 Corpus Statistics:")
print("─" * 70)

dirs = [
    ('Original Basic', 'corpus'),
    ('Enhanced', 'corpus_enhanced'),
    ('Seed', 'corpus_seed'),
    ('Merged', 'corpus_merged'),
    ('Final Minimized', 'corpus_final'),
]

for name, dir_path in dirs:
    count, size = get_dir_stats(dir_path)
    if count > 0:
        print(f"{name:20s}: {count:4d} files, {size:10,} bytes ({size/1024/1024:6.2f} MB)")

print("\n🎯 Feature Coverage in Final Corpus:")
print("─" * 70)

features = analyze_features('corpus_final')
for feature, count in sorted(features.items()):
    if count > 0:
        print(f"  ✓ {feature:35s}: {count:3d} files")
    else:
        print(f"  ○ {feature:35s}: {count:3d} files")

print("\n💡 Coverage Summary:")
covered = sum(1 for c in features.values() if c > 0)
total = len(features)
coverage_pct = (covered / total * 100) if total > 0 else 0
print(f"  Covered features: {covered}/{total} ({coverage_pct:.1f}%)")
print(f"  Total test files: {get_dir_stats('corpus_final')[0]}")
EOF

    echo
}

# Function to update corpus for fuzzing
update_fuzzing_corpus() {
    print_header "UPDATING FUZZING CORPUS"

    print_step "Replacing old corpus with optimized version"

    # Backup old corpus if it exists
    if [ -d "corpus" ] && [ "$(ls -A corpus 2>/dev/null)" ]; then
        local backup_dir="corpus_old_$(date +%Y%m%d_%H%M%S)"
        mv corpus "$backup_dir"
        print_info "Old corpus moved to: $backup_dir"
    fi

    # Copy final corpus to corpus directory
    cp -r corpus_final corpus
    print_success "Fuzzing corpus updated with optimized files"

    # Also update the minimized corpus directory
    if [ -d "corpus_minimized" ]; then
        rm -rf corpus_minimized
    fi
    cp -r corpus_final corpus_minimized
    print_success "corpus_minimized directory updated"

    echo
}

# Function to cleanup temporary files
cleanup() {
    print_header "CLEANUP"

    print_step "Removing temporary directories..."

    local removed=0
    for dir in corpus_merged corpus_enhanced_temp; do
        if [ -d "$dir" ]; then
            rm -rf "$dir"
            print_info "Removed: $dir"
            removed=1
        fi
    done

    if [ $removed -eq 0 ]; then
        print_info "No temporary directories to clean up"
    fi

    echo
}

# Function to show recommendations
show_recommendations() {
    print_header "RECOMMENDATIONS"

    echo -e "${GREEN}✓ Corpus optimization complete!${NC}"
    echo
    echo "Next steps:"
    echo
    echo "1. Start fuzzing with the optimized corpus:"
    echo -e "   ${CYAN}./fuzzer.sh start${NC}"
    echo
    echo "2. Monitor fuzzing progress:"
    echo -e "   ${CYAN}./fuzzer.sh stats${NC}"
    echo
    echo "3. Check for crashes:"
    echo -e "   ${CYAN}ls -lh fuzzer/crashes/${NC}"
    echo
    echo "4. For even better results, you can:"
    echo "   • Run fuzzing for 24-48 hours to let it discover new paths"
    echo "   • Periodically run this script to re-minimize the corpus"
    echo "   • Use concolic mode for deeper path exploration:"
    echo -e "     ${CYAN}./fuzzer.sh start-concolic${NC}"
    echo
    echo "5. After fuzzing, minimize the evolved corpus:"
    echo -e "   ${CYAN}python3 minimize_corpus.py fuzzer/corpus corpus_minimized --method=diversity${NC}"
    echo
}

# Main workflow
main() {
    print_header "DAV1D FUZZER CORPUS IMPROVEMENT WORKFLOW"
    echo
    echo "This script will:"
    echo "  1. Check prerequisites"
    echo "  2. Generate enhanced corpus with advanced AV1 features"
    echo "  3. Merge with existing corpus and seed corpus"
    echo "  4. Minimize corpus to remove redundancy"
    echo "  5. Update fuzzing directories"
    echo
    read -p "Continue? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Aborted by user"
        exit 0
    fi
    echo

    # Execute workflow steps
    check_prerequisites
    backup_corpus
    extract_seed_corpus
    generate_basic_corpus
    generate_enhanced_corpus
    merge_corpuses
    minimize_corpus
    analyze_corpus
    update_fuzzing_corpus
    cleanup
    show_recommendations

    print_header "✓ WORKFLOW COMPLETE"
    echo
    print_success "Corpus has been optimized for maximum coverage and fast execution!"
    echo
}

# Run main workflow
main
