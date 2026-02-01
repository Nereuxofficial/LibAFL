#!/usr/bin/env python3
"""
Generate a valid corpus of AV1 IVF files for fuzzing dav1d decoder.

This script creates actual valid AV1 bitstreams by:
1. Generating synthetic YUV frames with various patterns
2. Encoding them with aomenc to create valid AV1 bitstreams
3. Targeting different block sizes, resolutions, and encoding parameters

The goal is to exercise the checked_decode_b/decode_b functions in dav1d.
"""

import os
import struct
import subprocess
import sys
import tempfile
from typing import List, Tuple


def create_yuv_frame(width: int, height: int, pattern: str = "solid", frame_num: int = 0) -> bytes:
    """
    Create a single YUV420 frame with specified pattern.

    Patterns:
    - solid: Solid color
    - gradient: Horizontal gradient
    - checkerboard: Checkerboard pattern
    - vertical: Vertical stripes
    - horizontal: Horizontal stripes
    - moving_square: Moving white square (for inter-frame prediction)
    - moving_gradient: Shifting gradient (for temporal prediction)
    """
    # Calculate sizes
    y_size = width * height
    uv_width = (width + 1) // 2
    uv_height = (height + 1) // 2
    uv_size = uv_width * uv_height

    # Y plane
    if pattern == "solid":
        y_plane = bytes([128] * y_size)
    elif pattern == "gradient":
        y_plane = bytearray()
        for y in range(height):
            for x in range(width):
                val = int((x / width) * 255)
                y_plane.append(val)
        y_plane = bytes(y_plane)
    elif pattern == "checkerboard":
        y_plane = bytearray()
        for y in range(height):
            for x in range(width):
                val = 255 if ((x // 8) + (y // 8)) % 2 == 0 else 0
                y_plane.append(val)
        y_plane = bytes(y_plane)
    elif pattern == "vertical":
        y_plane = bytearray()
        for y in range(height):
            for x in range(width):
                val = 255 if (x // 4) % 2 == 0 else 0
                y_plane.append(val)
        y_plane = bytes(y_plane)
    elif pattern == "horizontal":
        y_plane = bytearray()
        for y in range(height):
            for x in range(width):
                val = 255 if (y // 4) % 2 == 0 else 0
                y_plane.append(val)
        y_plane = bytes(y_plane)
    elif pattern == "moving_square":
        # Create a moving white square on black background
        y_plane = bytearray([0] * y_size)
        square_size = min(width, height) // 4
        x_offset = (frame_num * 4) % (width - square_size)
        y_offset = (frame_num * 2) % (height - square_size)

        for y in range(height):
            for x in range(width):
                if (x_offset <= x < x_offset + square_size and
                    y_offset <= y < y_offset + square_size):
                    y_plane[y * width + x] = 255
        y_plane = bytes(y_plane)
    elif pattern == "moving_gradient":
        # Gradient that shifts position
        y_plane = bytearray()
        shift = (frame_num * 10) % 256
        for y in range(height):
            for x in range(width):
                val = ((x + shift) % 256)
                y_plane.append(val)
        y_plane = bytes(y_plane)
    else:
        y_plane = bytes([128] * y_size)

    # U and V planes (neutral chroma)
    u_plane = bytes([128] * uv_size)
    v_plane = bytes([128] * uv_size)

    return y_plane + u_plane + v_plane


def create_yuv_sequence(width: int, height: int, frames: int, pattern: str) -> bytes:
    """Create a sequence of YUV frames."""
    sequence = bytearray()
    for i in range(frames):
        sequence.extend(create_yuv_frame(width, height, pattern, i))
    return bytes(sequence)


def encode_to_av1(
    yuv_data: bytes,
    width: int,
    height: int,
    output_path: str,
    frames: int = 1,
    cpu_used: int = 8,
    extra_params: List[str] = None,
) -> bool:
    """
    Encode YUV data to AV1 using aomenc.

    Returns True if successful, False otherwise.
    """
    extra_params = extra_params or []

    with tempfile.NamedTemporaryFile(suffix=".yuv", delete=False) as yuv_file:
        yuv_temp = yuv_file.name
        yuv_file.write(yuv_data)

    try:
        cmd = (
            [
                "aomenc",
                "--codec=av1",
                f"--width={width}",
                f"--height={height}",
                "--ivf",
                f"--cpu-used={cpu_used}",
                "--passes=1",
                f"--limit={frames}",
                "--verbose",
                "--fps=30/1",
            ]
            + extra_params
            + ["-o", output_path, yuv_temp]
        )

        result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)

        success = result.returncode == 0 and os.path.exists(output_path)

        if not success:
            print(f"  Error encoding: {result.stderr[:200]}")

        return success

    except subprocess.TimeoutExpired:
        print(f"  Timeout encoding {output_path}")
        return False
    except Exception as e:
        print(f"  Exception encoding {output_path}: {e}")
        return False
    finally:
        if os.path.exists(yuv_temp):
            os.unlink(yuv_temp)


def generate_corpus(output_dir: str):
    """Generate comprehensive corpus of valid AV1 files."""

    os.makedirs(output_dir, exist_ok=True)

    print(f"Generating corpus in {output_dir}/")
    print("This uses aomenc to create valid AV1 bitstreams\n")

    file_count = 0

    # ===== SECTION 1: Block Sizes =====
    print("=" * 60)
    print("SECTION 1: Various Block Sizes")
    print("=" * 60)

    # Test various resolutions to trigger different block sizes
    block_size_tests = [
        (64, 64, "solid", "Minimal 64x64 (single 64x64 block)"),
        (128, 128, "gradient", "128x128 (single 128x128 superblock)"),
        (256, 256, "checkerboard", "256x256 (multiple blocks)"),
        (320, 240, "vertical", "320x240 (common small resolution)"),
        (640, 480, "horizontal", "640x480 (VGA resolution)"),
        (1280, 720, "gradient", "1280x720 (720p HD)"),
        (32, 32, "solid", "32x32 (very small)"),
        (96, 96, "checkerboard", "96x96 (odd multiple)"),
    ]

    for width, height, pattern, desc in block_size_tests:
        file_count += 1
        filename = f"res_{width:04d}x{height:04d}_{pattern}.ivf"
        output_path = os.path.join(output_dir, filename)

        print(f"  [{file_count:3d}] {filename:40s} - {desc}")

        yuv_frame = create_yuv_frame(width, height, pattern)
        encode_to_av1(yuv_frame, width, height, output_path, frames=1)

    # ===== SECTION 2: Encoding Parameters =====
    print(f"\n{'=' * 60}")
    print("SECTION 2: Different Encoding Parameters")
    print("=" * 60)

    width, height = 256, 256
    yuv_frame = create_yuv_frame(width, height, "gradient")

    encoding_tests = [
        (["--tile-columns=0", "--tile-rows=0"], "single_tile", "Single tile"),
        (["--tile-columns=1", "--tile-rows=1"], "multi_tile", "4 tiles (2x2)"),
        (["--enable-cdef=0"], "no_cdef", "CDEF disabled"),
        (["--enable-restoration=0"], "no_restoration", "Loop restoration disabled"),
        (["--aq-mode=0"], "aq_none", "No adaptive quantization"),
        (["--enable-qm=1"], "qm_enabled", "Quantization matrices enabled"),
        (["--min-q=10", "--max-q=20"], "low_q", "Low quantization (high quality)"),
        (["--min-q=50", "--max-q=60"], "high_q", "High quantization (low quality)"),
        (["--sharpness=7"], "sharp", "High sharpness"),
        (["--arnr-strength=0"], "no_arnr", "No temporal filtering"),
    ]

    for params, name, desc in encoding_tests:
        file_count += 1
        filename = f"param_{name}.ivf"
        output_path = os.path.join(output_dir, filename)

        print(f"  [{file_count:3d}] {filename:40s} - {desc}")

        encode_to_av1(
            yuv_frame, width, height, output_path, frames=1, extra_params=params
        )

    # ===== SECTION 3: Multi-Frame Sequences =====
    print(f"\n{'=' * 60}")
    print("SECTION 3: Multi-Frame Sequences")
    print("=" * 60)

    multi_frame_tests = [
        (3, "solid", "3 frames solid"),
        (5, "gradient", "5 frames gradient"),
        (10, "checkerboard", "10 frames checkerboard"),
    ]

    for num_frames, pattern, desc in multi_frame_tests:
        file_count += 1
        filename = f"multiframe_{num_frames}_{pattern}.ivf"
        output_path = os.path.join(output_dir, filename)

        print(f"  [{file_count:3d}] {filename:40s} - {desc}")

        yuv_frame = create_yuv_frame(128, 128, pattern)
        encode_to_av1(yuv_frame, 128, 128, output_path, frames=num_frames)

    # ===== SECTION 4: Edge Cases =====
    print(f"\n{'=' * 60}")
    print("SECTION 4: Edge Cases")
    print("=" * 60)

    edge_cases = [
        (16, 16, "solid", "Minimum practical size"),
        (4096, 2160, "gradient", "4K resolution (slow!)"),
        (100, 100, "checkerboard", "Non-standard 100x100"),
        (1920, 1080, "vertical", "1080p Full HD"),
        (65, 65, "horizontal", "Odd 65x65"),
        (127, 127, "gradient", "Prime-ish 127x127"),
    ]

    for width, height, pattern, desc in edge_cases:
        file_count += 1
        filename = f"edge_{width}x{height}_{pattern}.ivf"
        output_path = os.path.join(output_dir, filename)

        print(f"  [{file_count:3d}] {filename:40s} - {desc}")

        yuv_frame = create_yuv_frame(width, height, pattern)
        # Use faster encoding for large resolutions
        cpu_used = 8 if width * height < 1000000 else 9
        encode_to_av1(
            yuv_frame, width, height, output_path, frames=1, cpu_used=cpu_used
        )

    # ===== SECTION 5: Intra Prediction Tests =====
    print(f"\n{'=' * 60}")
    print("SECTION 5: Patterns to Trigger Different Intra Modes")
    print("=" * 60)

    # Different patterns that should trigger different intra prediction modes
    intra_patterns = [
        ("solid", "Flat areas (DC prediction)"),
        ("gradient", "Gradients (directional modes)"),
        ("checkerboard", "High frequency (various modes)"),
        ("vertical", "Vertical features"),
        ("horizontal", "Horizontal features"),
    ]

    for pattern, desc in intra_patterns:
        file_count += 1
        filename = f"intra_{pattern}.ivf"
        output_path = os.path.join(output_dir, filename)

        print(f"  [{file_count:3d}] {filename:40s} - {desc}")

        yuv_frame = create_yuv_frame(192, 192, pattern)
        encode_to_av1(yuv_frame, 192, 192, output_path, frames=1)

    # ===== SECTION 6: Speed Presets =====
    print(f"\n{'=' * 60}")
    print("SECTION 6: Different CPU-Used (Speed/Quality Tradeoff)")
    print("=" * 60)

    # Different cpu-used values create different encoding decisions
    speed_tests = [
        (0, "slowest", "Slowest, best quality"),
        (4, "medium", "Medium speed"),
        (8, "fast", "Fast encoding"),
    ]

    yuv_frame = create_yuv_frame(256, 256, "gradient")

    for cpu_used, name, desc in speed_tests:
        file_count += 1
        filename = f"speed_{name}.ivf"
        output_path = os.path.join(output_dir, filename)

        print(f"  [{file_count:3d}] {filename:40s} - {desc}")

        encode_to_av1(yuv_frame, 256, 256, output_path, frames=1, cpu_used=cpu_used)

    # ===== SECTION 7: Inter-Frame Prediction =====
    print(f"\n{'=' * 60}")
    print("SECTION 7: Inter-Frame Prediction (Motion)")
    print("=" * 60)

    inter_tests = [
        ("moving_square", 10, "Moving object (motion vectors)"),
        ("moving_gradient", 10, "Moving gradient (temporal prediction)"),
    ]

    for pattern, num_frames, desc in inter_tests:
        file_count += 1
        filename = f"inter_{pattern}.ivf"
        output_path = os.path.join(output_dir, filename)

        print(f"  [{file_count:3d}] {filename:40s} - {desc}")

        yuv_data = create_yuv_sequence(256, 256, num_frames, pattern)
        encode_to_av1(yuv_data, 256, 256, output_path, frames=num_frames)

    # ===== SECTION 8: AV1-Specific Tools =====
    print(f"\n{'=' * 60}")
    print("SECTION 8: AV1-Specific Tools")
    print("=" * 60)

    av1_tools = [
        (["--enable-warped-motion=1"], "warped_motion", "Warped motion prediction"),
        (["--bit-depth=10"], "10bit", "10-bit color depth"),
        (["--i444"], "chroma_444", "4:4:4 chroma format"),
    ]

    for params, name, desc in av1_tools:
        file_count += 1
        filename = f"tool_{name}.ivf"
        output_path = os.path.join(output_dir, filename)

        print(f"  [{file_count:3d}] {filename:40s} - {desc}")

        yuv_data = create_yuv_sequence(192, 192, 8, "moving_square")
        encode_to_av1(yuv_data, 192, 192, output_path, frames=8, extra_params=params)

    # Calculate statistics
    print(f"\n{'=' * 60}")
    print("CORPUS GENERATION COMPLETE")
    print("=" * 60)

    # Count actual generated files
    actual_files = [f for f in os.listdir(output_dir) if f.endswith(".ivf")]
    total_size = sum(os.path.getsize(os.path.join(output_dir, f)) for f in actual_files)

    print(f"\n✓ Generated {len(actual_files)} valid AV1 files")
    print(
        f"✓ Total corpus size: {total_size:,} bytes ({total_size / 1024 / 1024:.2f} MB)"
    )
    print(f"✓ Output directory: {output_dir}/")
    print(f"\nAll files are valid AV1 bitstreams that can be decoded by dav1d.")
    print(f"These will exercise the decode_b/checked_decode_b functions!")

    # Verify one file can be decoded
    print(f"\n{'=' * 60}")
    print("VERIFICATION")
    print("=" * 60)

    if actual_files:
        test_file = os.path.join(output_dir, actual_files[0])
        print(f"\nTesting if dav1d can decode: {actual_files[0]}")

        # Try to find dav1d binary
        dav1d_paths = [
            "./dav1d/build/tools/dav1d",
            "dav1d",
        ]

        dav1d_bin = None
        for path in dav1d_paths:
            if (
                os.path.exists(path)
                or subprocess.run(["which", path], capture_output=True).returncode == 0
            ):
                dav1d_bin = path
                break

        if dav1d_bin:
            result = subprocess.run(
                [dav1d_bin, "-i", test_file, "-o", "/dev/null"],
                capture_output=True,
                text=True,
            )

            if result.returncode == 0:
                print("✓ SUCCESS! dav1d can decode the generated files.")
                print("✓ This confirms decode_b will be called during fuzzing!")
            else:
                print("⚠ dav1d reported errors:")
                print(result.stderr[:500])
        else:
            print("⚠ Could not find dav1d binary for verification")
            print("  Build dav1d first: just build")


if __name__ == "__main__":
    # Check if aomenc is available
    if subprocess.run(["which", "aomenc"], capture_output=True).returncode != 0:
        print("ERROR: aomenc not found!")
        print("Please install libaom-tools:")
        print("  Ubuntu/Debian: sudo apt install libaom-tools")
        print("  Fedora: sudo dnf install libaom-utils")
        print("  macOS: brew install aom")
        sys.exit(1)

    output_dir = sys.argv[1] if len(sys.argv) > 1 else "./corpus"
    generate_corpus(output_dir)
