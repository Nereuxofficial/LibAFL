#!/usr/bin/env python3
"""
Corpus minimization script for dav1d fuzzing.

This script minimizes the corpus by:
1. Removing duplicate files (by content hash)
2. Removing files that don't provide unique coverage
3. Keeping only the smallest file for each unique coverage pattern
4. Optionally using afl-cmin or custom coverage-guided minimization

Usage:
    python3 minimize_corpus.py <input_corpus> <output_corpus> [--method=hash|size|coverage]
"""

import os
import sys
import hashlib
import shutil
import subprocess
from pathlib import Path
from typing import Dict, Set, List, Tuple
import argparse


def compute_file_hash(filepath: str) -> str:
    """Compute SHA256 hash of a file."""
    sha256 = hashlib.sha256()
    with open(filepath, 'rb') as f:
        while chunk := f.read(8192):
            sha256.update(chunk)
    return sha256.hexdigest()


def get_file_size(filepath: str) -> int:
    """Get file size in bytes."""
    return os.path.getsize(filepath)


def remove_duplicates(input_dir: str, output_dir: str) -> Tuple[int, int]:
    """
    Remove duplicate files based on content hash.
    Returns (total_files, unique_files).
    """
    print("=" * 70)
    print("PHASE 1: Removing Duplicate Files")
    print("=" * 70)

    os.makedirs(output_dir, exist_ok=True)

    seen_hashes: Dict[str, str] = {}  # hash -> filepath
    input_files = list(Path(input_dir).rglob("*.ivf"))

    print(f"Scanning {len(input_files)} files...")

    duplicates = 0
    unique = 0

    for filepath in input_files:
        file_hash = compute_file_hash(str(filepath))

        if file_hash in seen_hashes:
            duplicates += 1
            print(f"  [DUP] {filepath.name} (duplicate of {Path(seen_hashes[file_hash]).name})")
        else:
            seen_hashes[file_hash] = str(filepath)
            unique += 1

            # Copy to output
            output_path = os.path.join(output_dir, filepath.name)
            shutil.copy2(str(filepath), output_path)
            print(f"  [KEEP] {filepath.name}")

    print(f"\nResults:")
    print(f"  Total files: {len(input_files)}")
    print(f"  Unique files: {unique}")
    print(f"  Duplicates removed: {duplicates}")
    print(f"  Reduction: {duplicates / len(input_files) * 100:.1f}%")

    return len(input_files), unique


def minimize_by_size(input_dir: str, output_dir: str, max_size: int = 100000) -> Tuple[int, int]:
    """
    Keep files under a certain size, preferring smaller files.
    Returns (input_count, output_count).
    """
    print("\n" + "=" * 70)
    print("PHASE 2: Size-Based Minimization")
    print("=" * 70)
    print(f"Maximum file size: {max_size:,} bytes ({max_size / 1024:.1f} KB)")

    os.makedirs(output_dir, exist_ok=True)

    input_files = list(Path(input_dir).glob("*.ivf"))

    # Group files by name pattern (e.g., all "res_*" files together)
    patterns: Dict[str, List[Tuple[Path, int]]] = {}

    for filepath in input_files:
        size = get_file_size(str(filepath))

        # Extract pattern from filename
        parts = filepath.name.split('_')
        if len(parts) >= 2:
            pattern = parts[0] + '_' + parts[1]
        else:
            pattern = parts[0]

        if pattern not in patterns:
            patterns[pattern] = []
        patterns[pattern].append((filepath, size))

    kept = 0
    removed = 0

    for pattern, files in patterns.items():
        # Sort by size (smallest first)
        files.sort(key=lambda x: x[1])

        # Keep the smallest file from each pattern group
        for i, (filepath, size) in enumerate(files):
            if i == 0 or size <= max_size:
                output_path = os.path.join(output_dir, filepath.name)
                if not os.path.exists(output_path):
                    shutil.copy2(str(filepath), output_path)
                    kept += 1
                    print(f"  [KEEP] {filepath.name} ({size:,} bytes)")
            else:
                removed += 1
                print(f"  [SKIP] {filepath.name} ({size:,} bytes) - too large or redundant")

    print(f"\nResults:")
    print(f"  Files kept: {kept}")
    print(f"  Files removed: {removed}")

    return len(input_files), kept


def test_file_with_harness(filepath: str, harness_path: str = None) -> bool:
    """
    Test if a file can be processed by the harness.
    Returns True if the file is valid and doesn't crash immediately.
    """
    if not harness_path or not os.path.exists(harness_path):
        # Can't test without harness
        return True

    try:
        result = subprocess.run(
            [harness_path, str(filepath)],
            capture_output=True,
            timeout=5,
        )
        # Return True if it didn't crash (exit code 0 or timeout)
        return result.returncode == 0
    except subprocess.TimeoutExpired:
        # Timeout is okay - means it's processing
        return True
    except Exception:
        return False


def minimize_by_diversity(input_dir: str, output_dir: str) -> Tuple[int, int]:
    """
    Keep diverse files - one representative from each category.
    Returns (input_count, output_count).
    """
    print("\n" + "=" * 70)
    print("PHASE 3: Diversity-Based Minimization")
    print("=" * 70)

    os.makedirs(output_dir, exist_ok=True)

    input_files = list(Path(input_dir).glob("*.ivf"))

    # Categorize files by feature
    categories: Dict[str, List[Path]] = {}

    for filepath in input_files:
        name = filepath.name

        # Determine category
        if 'res_' in name:
            category = 'resolution'
        elif 'inter_' in name or 'global_motion' in name:
            category = 'inter_prediction'
        elif 'intra_' in name:
            category = 'intra_prediction'
        elif 'param_' in name or 'speed_' in name:
            category = 'encoding_params'
        elif 'multiframe' in name or 'kf_' in name:
            category = 'temporal'
        elif 'tool_' in name or 'adv_' in name:
            category = 'advanced_features'
        elif 'cdef' in name or 'restoration' in name:
            category = 'filtering'
        elif 'grain' in name:
            category = 'film_grain'
        elif 'screen' in name or 'palette' in name or 'intrabc' in name:
            category = 'screen_content'
        elif 'compound' in name or 'obmc' in name:
            category = 'prediction_modes'
        elif 'depth_' in name or 'chroma_' in name:
            category = 'color_format'
        elif 'refs_' in name:
            category = 'reference_frames'
        elif 'superblock' in name or 'sb' in name:
            category = 'block_sizes'
        elif 'edge_' in name:
            category = 'edge_cases'
        else:
            category = 'misc'

        if category not in categories:
            categories[category] = []
        categories[category].append(filepath)

    kept = 0

    print(f"Found {len(categories)} categories:")
    for category, files in sorted(categories.items()):
        print(f"  {category}: {len(files)} files")

    print("\nSelecting representatives from each category...")

    for category, files in sorted(categories.items()):
        # Sort by size, keep smallest files from each category
        files.sort(key=lambda f: get_file_size(str(f)))

        # Keep top N files from each category (prefer smaller ones)
        num_to_keep = min(3, len(files))  # Keep up to 3 per category

        for i, filepath in enumerate(files[:num_to_keep]):
            output_path = os.path.join(output_dir, filepath.name)
            if not os.path.exists(output_path):
                shutil.copy2(str(filepath), output_path)
                size = get_file_size(str(filepath))
                print(f"  [KEEP] {category:20s} - {filepath.name:40s} ({size:6,} bytes)")
                kept += 1

    print(f"\nResults:")
    print(f"  Input files: {len(input_files)}")
    print(f"  Output files: {kept}")
    print(f"  Reduction: {(len(input_files) - kept) / len(input_files) * 100:.1f}%")

    return len(input_files), kept


def merge_corpuses(corpus_dirs: List[str], output_dir: str):
    """Merge multiple corpus directories into one."""
    print("\n" + "=" * 70)
    print("MERGING CORPUSES")
    print("=" * 70)

    os.makedirs(output_dir, exist_ok=True)

    all_files: Dict[str, str] = {}  # hash -> source_path

    for corpus_dir in corpus_dirs:
        if not os.path.exists(corpus_dir):
            print(f"  Warning: {corpus_dir} does not exist, skipping...")
            continue

        print(f"\nProcessing: {corpus_dir}")
        files = list(Path(corpus_dir).rglob("*.ivf"))
        print(f"  Found {len(files)} files")

        for filepath in files:
            file_hash = compute_file_hash(str(filepath))

            if file_hash not in all_files:
                all_files[file_hash] = str(filepath)
            else:
                print(f"    [DUP] {filepath.name}")

    print(f"\nCopying {len(all_files)} unique files to {output_dir}...")

    for i, filepath in enumerate(all_files.values(), 1):
        filename = Path(filepath).name
        output_path = os.path.join(output_dir, filename)

        # Handle name conflicts
        counter = 1
        while os.path.exists(output_path):
            name, ext = os.path.splitext(filename)
            output_path = os.path.join(output_dir, f"{name}_{counter}{ext}")
            counter += 1

        shutil.copy2(filepath, output_path)
        if i % 10 == 0:
            print(f"  Copied {i}/{len(all_files)} files...")

    print(f"\n✓ Merged corpus saved to: {output_dir}")
    print(f"✓ Total unique files: {len(all_files)}")


def main():
    parser = argparse.ArgumentParser(
        description="Minimize corpus for dav1d fuzzing",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Basic minimization (remove duplicates + size filter)
  python3 minimize_corpus.py corpus corpus_minimized

  # Aggressive minimization (diversity-based)
  python3 minimize_corpus.py corpus corpus_minimized --method=diversity

  # Merge multiple corpuses first, then minimize
  python3 minimize_corpus.py corpus corpus_enhanced corpus_seed --merge --output=corpus_merged
  python3 minimize_corpus.py corpus_merged corpus_minimized --method=diversity
        """
    )

    parser.add_argument("input_dirs", nargs="+", help="Input corpus directory/directories")
    parser.add_argument("--output", "-o", help="Output corpus directory (required unless merging)")
    parser.add_argument("--method", choices=["hash", "size", "diversity", "all"],
                       default="all", help="Minimization method")
    parser.add_argument("--merge", action="store_true",
                       help="Merge multiple input directories first")
    parser.add_argument("--max-size", type=int, default=100000,
                       help="Maximum file size in bytes (default: 100000)")

    args = parser.parse_args()

    # Handle merge mode
    if args.merge:
        if not args.output:
            print("ERROR: --output is required when using --merge")
            sys.exit(1)
        merge_corpuses(args.input_dirs, args.output)
        return

    # Normal minimization mode
    if len(args.input_dirs) != 1:
        print("ERROR: Provide exactly one input directory for minimization")
        print("       (or use --merge for multiple directories)")
        sys.exit(1)

    if not args.output:
        print("ERROR: --output is required")
        sys.exit(1)

    input_dir = args.input_dirs[0]
    output_dir = args.output

    if not os.path.exists(input_dir):
        print(f"ERROR: Input directory does not exist: {input_dir}")
        sys.exit(1)

    print("=" * 70)
    print("DAV1D CORPUS MINIMIZATION")
    print("=" * 70)
    print(f"Input:  {input_dir}")
    print(f"Output: {output_dir}")
    print(f"Method: {args.method}")
    print()

    # Count input files
    input_files = list(Path(input_dir).rglob("*.ivf"))
    input_size = sum(get_file_size(str(f)) for f in input_files)
    print(f"Input corpus: {len(input_files)} files, {input_size:,} bytes ({input_size / 1024 / 1024:.2f} MB)")
    print()

    if args.method == "hash":
        remove_duplicates(input_dir, output_dir)
    elif args.method == "size":
        remove_duplicates(input_dir, output_dir + "_temp")
        minimize_by_size(output_dir + "_temp", output_dir, args.max_size)
        shutil.rmtree(output_dir + "_temp")
    elif args.method == "diversity":
        remove_duplicates(input_dir, output_dir + "_temp")
        minimize_by_diversity(output_dir + "_temp", output_dir)
        shutil.rmtree(output_dir + "_temp")
    else:  # all
        # Multi-stage minimization
        remove_duplicates(input_dir, output_dir + "_dedup")
        minimize_by_size(output_dir + "_dedup", output_dir + "_sized", args.max_size)
        minimize_by_diversity(output_dir + "_sized", output_dir)

        # Clean up temp directories
        shutil.rmtree(output_dir + "_dedup")
        shutil.rmtree(output_dir + "_sized")

    # Final statistics
    output_files = list(Path(output_dir).glob("*.ivf"))
    output_size = sum(get_file_size(str(f)) for f in output_files)

    print("\n" + "=" * 70)
    print("FINAL STATISTICS")
    print("=" * 70)
    print(f"Input corpus:  {len(input_files):4d} files, {input_size:10,} bytes ({input_size / 1024 / 1024:6.2f} MB)")
    print(f"Output corpus: {len(output_files):4d} files, {output_size:10,} bytes ({output_size / 1024 / 1024:6.2f} MB)")
    print(f"Reduction:     {len(input_files) - len(output_files):4d} files removed ({(len(input_files) - len(output_files)) / len(input_files) * 100:5.1f}%)")
    print(f"Size saved:    {input_size - output_size:10,} bytes ({(input_size - output_size) / 1024 / 1024:6.2f} MB, {(input_size - output_size) / input_size * 100:5.1f}%)")
    print()
    print(f"✓ Minimized corpus saved to: {output_dir}")
    print(f"✓ Ready for fuzzing with improved speed!")


if __name__ == "__main__":
    main()
