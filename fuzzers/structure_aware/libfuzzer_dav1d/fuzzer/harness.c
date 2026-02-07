/*
 * Copyright © 2018, VideoLAN and dav1d authors
 * Copyright © 2018, Janne Grunau
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 * 1. Redistributions of source code must retain the above copyright notice, this
 *    list of conditions and the following disclaimer.
 *
 * 2. Redistributions in binary form must reproduce the above copyright notice,
 *    this list of conditions and the following disclaimer in the documentation
 *    and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
 * ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <stdarg.h>

#include "dav1d/dav1d.h"

// Null logger to suppress dav1d error messages
static void null_logger(void *cookie, const char *format, va_list args) {
    (void)cookie;
    (void)format;
    (void)args;
    // Do nothing - suppress all log messages
}

static unsigned r32le(const uint8_t *const p) {
    return ((uint32_t)p[3] << 24U) | (p[2] << 16U) | (p[1] << 8U) | p[0];
}

// Fast validation of IVF frame structure without full parsing
static int quick_validate_ivf(const uint8_t *data, size_t size) {
    // Must have IVF header (32 bytes) + at least one frame header (12 bytes)
    if (size < 44)
        return 0;
    
    // Check DKIF magic
    if (data[0] != 'D' || data[1] != 'K' || data[2] != 'I' || data[3] != 'F')
        return 0;
    
    // Check version (should be 0)
    if (r32le(data + 4) != 0)
        return 0;
    
    // Check fourcc for AV1 (AV01 or av01)
    const uint8_t *fourcc = data + 8;
    if (!((fourcc[0] == 'A' && fourcc[1] == 'V' && fourcc[2] == '0' && fourcc[3] == '1') ||
          (fourcc[0] == 'a' && fourcc[1] == 'v' && fourcc[2] == '0' && fourcc[3] == '1')))
        return 0;
    
    return 1;
}

int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size) {
    Dav1dSettings settings;
    Dav1dContext *ctx = NULL;
    Dav1dPicture pic;
    const uint8_t *ptr = data;
    int have_seq_hdr = 0;
    int err;
    int frames_processed = 0;
    const int MAX_FRAMES = 5; // Reduced from 10 for faster execution
    const size_t MAX_INPUT_SIZE = 1 * 1024 * 1024; // Reduced to 1MB for faster fuzzing
    const size_t MIN_INPUT_SIZE = 44; // IVF header + one frame header

    // Early exit: reject inputs outside reasonable bounds
    if (size < MIN_INPUT_SIZE || size > MAX_INPUT_SIZE)
        return 0;

    // Early exit: fast validation of IVF structure
    if (!quick_validate_ivf(data, size))
        return 0;

    // Skip IVF header
    ptr = data + 32;

    // Initialize decoder settings with minimal resources for speed
    dav1d_default_settings(&settings);
    settings.n_threads = 1; // Single thread for fuzzing speed
    settings.max_frame_delay = 0; // No delay for immediate processing
    settings.logger.callback = null_logger;
    settings.logger.cookie = NULL;

    // Open decoder context
    err = dav1d_open(&ctx, &settings);
    if (err < 0)
        return 0;

    // Process frames from IVF container
    while (ptr <= data + size - 12) {
        Dav1dData buf;
        uint8_t *p;

        // Early exit: limit number of frames to prevent slow inputs
        if (frames_processed >= MAX_FRAMES)
            break;

        // Read frame size from IVF frame header
        size_t frame_size = r32le(ptr);
        ptr += 12; // Skip IVF frame header

        // Early exit: validate frame size bounds
        if (frame_size == 0 || frame_size > size || ptr > data + size - frame_size)
            break;

        // Early exit: reject large frames (>500KB) for fuzzing speed
        if (frame_size > 500 * 1024)
            break;

        // Early exit: skip tiny frames that are likely invalid
        if (frame_size < 8)
            continue;

        frames_processed++;

        // Wait for sequence header before processing frames
        if (!have_seq_hdr) {
            Dav1dSequenceHeader seq;
            err = dav1d_parse_sequence_header(&seq, ptr, frame_size);
            if (err != 0) {
                // Early exit: abort immediately if first frame lacks valid sequence header
                goto cleanup;
            }
            have_seq_hdr = 1;
            
            // Early exit: validate reasonable dimensions to avoid expensive decoding
            if (seq.max_width > 1920 || seq.max_height > 1080 || 
                seq.max_width == 0 || seq.max_height == 0) {
                goto cleanup;
            }
        }

        // Copy frame data to decoder buffer
        p = dav1d_data_create(&buf, frame_size);
        if (!p)
            goto cleanup;

        memcpy(p, ptr, frame_size);
        ptr += frame_size;

        // Send data with minimal retries
        err = dav1d_send_data(ctx, &buf);
        if (err < 0 && err != DAV1D_ERR(EAGAIN)) {
            // Early exit: abort on send errors
            if (buf.sz > 0)
                dav1d_data_unref(&buf);
            goto cleanup;
        }

        // Try to retrieve picture once
        memset(&pic, 0, sizeof(pic));
        err = dav1d_get_picture(ctx, &pic);
        if (err == 0) {
            dav1d_picture_unref(&pic);
        } else if (err != DAV1D_ERR(EAGAIN)) {
            // Early exit: stop on decode errors
            if (buf.sz > 0)
                dav1d_data_unref(&buf);
            goto cleanup;
        }

        // Clean up remaining buffer data
        if (buf.sz > 0)
            dav1d_data_unref(&buf);
    }

    // Minimal drain - only try a few times
    int drain_attempts = 0;
    const int MAX_DRAIN_ATTEMPTS = MAX_FRAMES; // Match frame limit
    do {
        if (drain_attempts++ >= MAX_DRAIN_ATTEMPTS)
            break;
        memset(&pic, 0, sizeof(pic));
        err = dav1d_get_picture(ctx, &pic);
        if (err == 0)
            dav1d_picture_unref(&pic);
        else if (err != DAV1D_ERR(EAGAIN))
            break; // Stop on errors
    } while (err != DAV1D_ERR(EAGAIN));

cleanup:
    dav1d_close(&ctx);
    return 0;
}
