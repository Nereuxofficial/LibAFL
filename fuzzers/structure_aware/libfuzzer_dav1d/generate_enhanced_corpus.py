#!/usr/bin/env python3
"""
Enhanced corpus generator for dav1d fuzzing with advanced AV1 features.

This script generates AV1 bitstreams targeting specific features to maximize
code coverage in the dav1d decoder, using only supported aomenc options.
"""

import os
import struct
import subprocess
import sys
import tempfile
from typing import List, Tuple
import random


def create_yuv_frame(width: int, height: int, pattern: str = "solid", frame_num: int = 0) -> bytes:
    """Create a single YUV420 frame with specified pattern."""
    y_size = width * height
    uv_width = (width + 1) // 2
    uv_height = (height + 1) // 2
    uv_size = uv_width * uv_height

    # Y plane patterns
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
    elif pattern == "diagonal":
        y_plane = bytearray()
        for y in range(height):
            for x in range(width):
                val = 255 if ((x + y) // 8) % 2 == 0 else 0
                y_plane.append(val)
        y_plane = bytes(y_plane)
    elif pattern == "moving_square":
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
        y_plane = bytearray()
        shift = (frame_num * 10) % 256
        for y in range(height):
            for x in range(width):
                val = ((x + shift) % 256)
                y_plane.append(val)
        y_plane = bytes(y_plane)
    elif pattern == "noise":
        # High frequency noise pattern to trigger various intra modes
        random.seed(frame_num + 42)
        y_plane = bytes([random.randint(0, 255) for _ in range(y_size)])
    elif pattern == "text_like":
        # Sharp edges like text for screen content coding
        y_plane = bytearray()
        for y in range(height):
            for x in range(width):
                # Create text-like sharp patterns
                if (x % 16 < 8 and y % 16 < 12):
                    val = 255
                else:
                    val = 0
                y_plane.append(val)
        y_plane = bytes(y_plane)
    elif pattern == "rotating":
        # Rotating pattern for global motion
        import math
        angle = frame_num * 0.1
        y_plane = bytearray()
        cx, cy = width // 2, height // 2
        for y in range(height):
            for x in range(width):
                dx = x - cx
                dy = y - cy
                rx = dx * math.cos(angle) - dy * math.sin(angle)
                val = int((rx + cx) / width * 255) % 256
                y_plane.append(val)
        y_plane = bytes(y_plane)
    elif pattern == "zooming":
        # Zooming pattern
        scale = 1.0 + frame_num * 0.05
        y_plane = bytearray()
        cx, cy = width // 2, height // 2
        for y in range(height):
            for x in range(width):
                sx = int(cx + (x - cx) / scale)
                sy = int(cy + (y - cy) / scale)
                if 0 <= sx < width and 0 <= sy < height:
                    val = int((sx / width) * 255)
                else:
                    val = 128
                y_plane.append(val)
        y_plane = bytes(y_plane)
    elif pattern == "blocks":
        # Large blocks of different intensities
        y_plane = bytearray()
        for y in range(height):
            for x in range(width):
                block_x = (x // 64) % 4
                block_y = (y // 64) % 4
                val = (block_x * 64 + block_y * 64) % 256
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
    """Encode YUV data to AV1 using aomenc."""
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

        result = subprocess.run(cmd, capture_output=True, text=True, timeout=60)
        success = result.returncode == 0 and os.path.exists(output_path)

        if not success:
            print(f"    ⚠ Error encoding: {result.stderr[:200]}")

        return success

    except subprocess.TimeoutExpired:
        print(f"    ⚠ Timeout encoding {output_path}")
        return False
    except Exception as e:
        print(f"    ⚠ Exception encoding {output_path}: {e}")
        return False
    finally:
        if os.path.exists(yuv_temp):
            os.unlink(yuv_temp)


def generate_enhanced_corpus(output_dir: str):
    """Generate enhanced corpus targeting advanced AV1 features."""

    os.makedirs(output_dir, exist_ok=True)

    print("=" * 70)
    print("ENHANCED AV1 CORPUS GENERATOR FOR MAXIMUM COVERAGE")
    print("=" * 70)
    print(f"Output directory: {output_dir}/")
    print()

    file_count = 0

    # ===== SECTION 1: CDEF Filtering =====
    print("=" * 70)
    print("SECTION 1: CDEF Filtering Variations")
    print("=" * 70)

    width, height = 256, 256
    cdef_tests = [
        (["--enable-cdef=0"], "cdef_disabled", "CDEF disabled"),
        (["--enable-cdef=1"], "cdef_enabled", "CDEF enabled (default)"),
        (["--enable-cdef=2"], "cdef_nonref", "CDEF for non-reference frames only"),
        (["--enable-cdef=3"], "cdef_adaptive", "CDEF adaptive based on qindex"),
    ]

    for params, name, desc in cdef_tests:
        file_count += 1
        filename = f"adv_{name}.ivf"
        output_path = os.path.join(output_dir, filename)
        print(f"  [{file_count:3d}] {filename:45s} - {desc}")

        yuv_data = create_yuv_frame(width, height, "checkerboard")
        encode_to_av1(yuv_data, width, height, output_path, frames=1, extra_params=params)

    # ===== SECTION 2: Loop Restoration Filters =====
    print(f"\n{'=' * 70}")
    print("SECTION 2: Loop Restoration")
    print("=" * 70)

    restoration_tests = [
        (["--enable-restoration=0"], "restoration_disabled", "Loop restoration disabled"),
        (["--enable-restoration=1"], "restoration_enabled", "Loop restoration enabled"),
    ]

    for params, name, desc in restoration_tests:
        file_count += 1
        filename = f"adv_{name}.ivf"
        output_path = os.path.join(output_dir, filename)
        print(f"  [{file_count:3d}] {filename:45s} - {desc}")

        yuv_data = create_yuv_frame(width, height, "noise")
        encode_to_av1(yuv_data, width, height, output_path, frames=1, extra_params=params)

    # ===== SECTION 3: Film Grain Synthesis =====
    print(f"\n{'=' * 70}")
    print("SECTION 3: Film Grain Synthesis")
    print("=" * 70)

    grain_tests = [
        (["--film-grain-test=8"], "grain_low", "Low grain level (test-8)"),
        (["--film-grain-test=12"], "grain_medium", "Medium grain level (test-12)"),
        (["--film-grain-test=16"], "grain_high", "High grain level (test-16)"),
    ]

    for params, name, desc in grain_tests:
        file_count += 1
        filename = f"adv_{name}.ivf"
        output_path = os.path.join(output_dir, filename)
        print(f"  [{file_count:3d}] {filename:45s} - {desc}")

        yuv_data = create_yuv_frame(width, height, "gradient")
        encode_to_av1(yuv_data, width, height, output_path, frames=1,
                     extra_params=params, cpu_used=6)

    # ===== SECTION 4: Global Motion =====
    print(f"\n{'=' * 70}")
    print("SECTION 4: Global Motion & Complex Motion")
    print("=" * 70)

    global_motion_tests = [
        ("rotating", 10, "Rotation (global motion)"),
        ("zooming", 10, "Zoom (global motion)"),
        ("moving_gradient", 10, "Translation"),
    ]

    for pattern, num_frames, desc in global_motion_tests:
        file_count += 1
        filename = f"adv_global_motion_{pattern}.ivf"
        output_path = os.path.join(output_dir, filename)
        print(f"  [{file_count:3d}] {filename:45s} - {desc}")

        yuv_data = create_yuv_sequence(256, 256, num_frames, pattern)
        encode_to_av1(yuv_data, 256, 256, output_path, frames=num_frames,
                     extra_params=[], cpu_used=6)

    # ===== SECTION 5: Screen Content Coding =====
    print(f"\n{'=' * 70}")
    print("SECTION 5: Screen Content Coding Tools")
    print("=" * 70)

    screen_tests = [
        (["--enable-palette=1"], "text_like", "palette_enabled", "Palette mode enabled"),
        (["--enable-palette=0"], "text_like", "palette_disabled", "Palette mode disabled"),
        (["--enable-intrabc=1"], "text_like", "intrabc_enabled", "Intra block copy enabled"),
        (["--enable-intrabc=0"], "text_like", "intrabc_disabled", "Intra block copy disabled"),
        (["--enable-palette=1", "--enable-intrabc=1"], "text_like", "screen_all",
         "All screen tools enabled"),
    ]

    for params, pattern, name, desc in screen_tests:
        file_count += 1
        filename = f"adv_screen_{name}.ivf"
        output_path = os.path.join(output_dir, filename)
        print(f"  [{file_count:3d}] {filename:45s} - {desc}")

        yuv_data = create_yuv_frame(320, 240, pattern)
        encode_to_av1(yuv_data, 320, 240, output_path, frames=1, extra_params=params)

    # ===== SECTION 6: Reference Frames =====
    print(f"\n{'=' * 70}")
    print("SECTION 6: Reference Frame Management")
    print("=" * 70)

    ref_tests = [
        (3, "ref3", "3 reference frames"),
        (5, "ref5", "5 reference frames"),
        (7, "ref7", "7 reference frames (max)"),
    ]

    for num_refs, name, desc in ref_tests:
        file_count += 1
        filename = f"adv_refs_{name}.ivf"
        output_path = os.path.join(output_dir, filename)
        print(f"  [{file_count:3d}] {filename:45s} - {desc}")

        yuv_data = create_yuv_sequence(256, 256, 15, "moving_square")
        encode_to_av1(yuv_data, 256, 256, output_path, frames=15,
                     extra_params=[f"--lag-in-frames={num_refs}"], cpu_used=7)

    # ===== SECTION 7: Superblock Sizes =====
    print(f"\n{'=' * 70}")
    print("SECTION 7: Superblock Sizes")
    print("=" * 70)

    sb_tests = [
        (64, "sb64", "64x64 superblocks"),
        (128, "sb128", "128x128 superblocks (default)"),
    ]

    for sb_size, name, desc in sb_tests:
        file_count += 1
        filename = f"adv_superblock_{name}.ivf"
        output_path = os.path.join(output_dir, filename)
        print(f"  [{file_count:3d}] {filename:45s} - {desc}")

        # Use larger resolution to fully exercise large blocks
        yuv_data = create_yuv_frame(512, 512, "blocks")
        encode_to_av1(yuv_data, 512, 512, output_path, frames=1,
                     extra_params=[f"--sb-size={sb_size}"])

    # ===== SECTION 8: Quantization Modes =====
    print(f"\n{'=' * 70}")
    print("SECTION 8: Quantization and Quality Settings")
    print("=" * 70)

    quant_tests = [
        (["--end-usage=q", "--cq-level=10"], "highq", "Very high quality (low Q)"),
        (["--end-usage=q", "--cq-level=30"], "medq", "Medium quality"),
        (["--end-usage=q", "--cq-level=50"], "lowq", "Low quality (high Q)"),
        (["--aq-mode=0"], "aq_none", "No adaptive quantization"),
        (["--aq-mode=1"], "aq_variance", "Variance-based AQ"),
        (["--aq-mode=2"], "aq_complexity", "Complexity-based AQ"),
        (["--aq-mode=3"], "aq_cyclic", "Cyclic refresh AQ"),
    ]

    for params, name, desc in quant_tests:
        file_count += 1
        filename = f"adv_quant_{name}.ivf"
        output_path = os.path.join(output_dir, filename)
        print(f"  [{file_count:3d}] {filename:45s} - {desc}")

        yuv_data = create_yuv_frame(384, 384, "checkerboard")
        encode_to_av1(yuv_data, 384, 384, output_path, frames=1, extra_params=params)

    # ===== SECTION 9: Tiling =====
    print(f"\n{'=' * 70}")
    print("SECTION 9: Tiling Configurations")
    print("=" * 70)

    tile_tests = [
        (["--tile-columns=0", "--tile-rows=0"], "tile_1x1", "Single tile"),
        (["--tile-columns=1", "--tile-rows=1"], "tile_2x2", "4 tiles (2x2)"),
        (["--tile-columns=2", "--tile-rows=1"], "tile_4x2", "8 tiles (4x2)"),
        (["--tile-columns=2", "--tile-rows=2"], "tile_4x4", "16 tiles (4x4)"),
    ]

    for params, name, desc in tile_tests:
        file_count += 1
        filename = f"adv_{name}.ivf"
        output_path = os.path.join(output_dir, filename)
        print(f"  [{file_count:3d}] {filename:45s} - {desc}")

        yuv_data = create_yuv_frame(512, 512, "gradient")
        encode_to_av1(yuv_data, 512, 512, output_path, frames=1, extra_params=params)

    # ===== SECTION 10: Keyframe Patterns =====
    print(f"\n{'=' * 70}")
    print("SECTION 10: Keyframe Patterns")
    print("=" * 70)

    keyframe_tests = [
        (1, 30, "kf_all_keyframes", "All keyframes (kf-max-dist=1)"),
        (5, 30, "kf_keyframe_every_5", "Keyframe every 5 frames"),
        (10, 30, "kf_keyframe_every_10", "Keyframe every 10 frames"),
        (30, 30, "kf_no_keyframes", "No intermediate keyframes"),
    ]

    for kf_interval, num_frames, name, desc in keyframe_tests:
        file_count += 1
        filename = f"adv_{name}.ivf"
        output_path = os.path.join(output_dir, filename)
        print(f"  [{file_count:3d}] {filename:45s} - {desc}")

        yuv_data = create_yuv_sequence(256, 256, num_frames, "moving_gradient")
        encode_to_av1(yuv_data, 256, 256, output_path, frames=num_frames,
                     extra_params=[f"--kf-max-dist={kf_interval}"])

    # ===== SECTION 11: Color Depth and Chroma Formats =====
    print(f"\n{'=' * 70}")
    print("SECTION 11: Color Depth and Chroma Subsampling")
    print("=" * 70)

    color_tests = [
        (["--bit-depth=10"], "10bit", "10-bit color depth"),
        (["--bit-depth=12"], "12bit", "12-bit color depth"),
        (["--i422"], "chroma_422", "4:2:2 chroma subsampling"),
        (["--i444"], "chroma_444", "4:4:4 chroma subsampling"),
    ]

    for params, name, desc in color_tests:
        file_count += 1
        filename = f"adv_depth_{name}.ivf"
        output_path = os.path.join(output_dir, filename)
        print(f"  [{file_count:3d}] {filename:45s} - {desc}")

        yuv_data = create_yuv_frame(256, 256, "gradient")
        encode_to_av1(yuv_data, 256, 256, output_path, frames=1, extra_params=params)

    # ===== SECTION 12: Various Resolutions =====
    print(f"\n{'=' * 70}")
    print("SECTION 12: Resolution and Aspect Ratio Variations")
    print("=" * 70)

    resolution_tests = [
        (128, 64, "vertical_rect", "Vertical rectangle 128x64"),
        (64, 128, "horizontal_rect", "Horizontal rectangle 64x128"),
        (1024, 512, "wide", "Wide aspect 1024x512"),
        (512, 1024, "tall", "Tall aspect 512x1024"),
        (854, 480, "480p", "480p resolution"),
        (1920, 1080, "1080p", "1080p Full HD"),
    ]

    for w, h, name, desc in resolution_tests:
        file_count += 1
        filename = f"adv_res_{name}_{w}x{h}.ivf"
        output_path = os.path.join(output_dir, filename)
        print(f"  [{file_count:3d}] {filename:45s} - {desc}")

        yuv_data = create_yuv_frame(w, h, "gradient")
        cpu = 9 if w * h > 1000000 else 8
        encode_to_av1(yuv_data, w, h, output_path, frames=1, cpu_used=cpu)

    # ===== SECTION 13: Speed and Performance Settings =====
    print(f"\n{'=' * 70}")
    print("SECTION 13: Encoder Speed Settings")
    print("=" * 70)

    speed_tests = [
        (0, "speed_0", "CPU-used 0 (slowest, best quality)"),
        (4, "speed_4", "CPU-used 4 (medium)"),
        (8, "speed_8", "CPU-used 8 (fast, default)"),
        (10, "speed_10", "CPU-used 10 (fastest, realtime)"),
    ]

    for cpu_used_val, name, desc in speed_tests:
        file_count += 1
        filename = f"adv_{name}.ivf"
        output_path = os.path.join(output_dir, filename)
        print(f"  [{file_count:3d}] {filename:45s} - {desc}")

        yuv_data = create_yuv_frame(256, 256, "gradient")
        encode_to_av1(yuv_data, 256, 256, output_path, frames=1, cpu_used=cpu_used_val)

    # ===== SECTION 14: Complex Multi-Frame Scenarios =====
    print(f"\n{'=' * 70}")
    print("SECTION 14: Complex Multi-Frame Sequences")
    print("=" * 70)

    multiframe_tests = [
        ("moving_square", 20, "long_inter", "Long sequence 20 frames"),
        ("rotating", 15, "rotating_motion", "Rotational motion 15 frames"),
        ("zooming", 15, "zoom_motion", "Zoom motion 15 frames"),
        ("noise", 10, "noise_sequence", "Noisy sequence 10 frames"),
    ]

    for pattern, frames, name, desc in multiframe_tests:
        file_count += 1
        filename = f"adv_multi_{name}.ivf"
        output_path = os.path.join(output_dir, filename)
        print(f"  [{file_count:3d}] {filename:45s} - {desc}")

        yuv_data = create_yuv_sequence(320, 240, frames, pattern)
        encode_to_av1(yuv_data, 320, 240, output_path, frames=frames, cpu_used=7)

    # Calculate statistics
    print(f"\n{'=' * 70}")
    print("ENHANCED CORPUS GENERATION COMPLETE")
    print("=" * 70)

    actual_files = [f for f in os.listdir(output_dir) if f.endswith(".ivf")]
    total_size = sum(os.path.getsize(os.path.join(output_dir, f)) for f in actual_files)

    print(f"\n✓ Generated {len(actual_files)} enhanced AV1 files")
    print(f"✓ Total corpus size: {total_size:,} bytes ({total_size / 1024 / 1024:.2f} MB)")
    print(f"✓ Output directory: {output_dir}/")
    print(f"\nThese files target advanced AV1 features for maximum code coverage:")
    print("  • CDEF filtering (enabled/disabled/adaptive)")
    print("  • Loop restoration filters")
    print("  • Film grain synthesis (multiple levels)")
    print("  • Global motion (rotation, zoom, translation)")
    print("  • Screen content coding (palette mode, intra block copy)")
    print("  • Multiple reference frames (3-7 refs)")
    print("  • Large superblocks (64x64, 128x128)")
    print("  • Adaptive quantization modes")
    print("  • Various tiling configurations")
    print("  • Different keyframe patterns")
    print("  • High bit depths (10-bit, 12-bit)")
    print("  • Various chroma subsampling formats (420, 422, 444)")
    print("  • Edge-case resolutions and aspect ratios")
    print("  • Different encoder speed settings")
    print("  • Complex multi-frame motion sequences")


if __name__ == "__main__":
    # Check if aomenc is available
    if subprocess.run(["which", "aomenc"], capture_output=True).returncode != 0:
        print("ERROR: aomenc not found!")
        print("Please install libaom-tools:")
        print("  Ubuntu/Debian: sudo apt install libaom-tools")
        print("  Fedora: sudo dnf install libaom-utils")
        print("  macOS: brew install aom")
        sys.exit(1)

    output_dir = sys.argv[1] if len(sys.argv) > 1 else "./corpus_enhanced"
    generate_enhanced_corpus(output_dir)
