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

int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size) {
    Dav1dSettings settings;
    Dav1dContext *ctx = NULL;
    Dav1dPicture pic;
    const uint8_t *ptr = data;
    int have_seq_hdr = 0;
    int err;

    // Need at least IVF header (32 bytes)
    if (size < 32)
        return 0;

    // Skip IVF header
    ptr += 32;

    // Initialize decoder settings
    dav1d_default_settings(&settings);
    settings.n_threads = 2;
    settings.max_frame_delay = 1;
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

        // Read frame size from IVF frame header
        size_t frame_size = r32le(ptr);
        ptr += 12; // Skip IVF frame header

        // Validate frame size
        if (frame_size > size || ptr > data + size - frame_size)
            break;

        if (!frame_size)
            continue;

        // Wait for sequence header before processing frames
        if (!have_seq_hdr) {
            Dav1dSequenceHeader seq;
            err = dav1d_parse_sequence_header(&seq, ptr, frame_size);
            if (err != 0) {
                ptr += frame_size;
                continue;
            }
            have_seq_hdr = 1;
        }

        // Copy frame data to decoder buffer
        p = dav1d_data_create(&buf, frame_size);
        if (!p)
            goto cleanup;

        memcpy(p, ptr, frame_size);
        ptr += frame_size;

        // Send data and retrieve pictures
        do {
            err = dav1d_send_data(ctx, &buf);
            if (err < 0 && err != DAV1D_ERR(EAGAIN))
                break;

            memset(&pic, 0, sizeof(pic));
            err = dav1d_get_picture(ctx, &pic);
            if (err == 0) {
                dav1d_picture_unref(&pic);
            } else if (err != DAV1D_ERR(EAGAIN)) {
                break;
            }
        } while (buf.sz > 0);

        // Clean up remaining buffer data
        if (buf.sz > 0)
            dav1d_data_unref(&buf);
    }

    // Drain any remaining frames
    do {
        memset(&pic, 0, sizeof(pic));
        err = dav1d_get_picture(ctx, &pic);
        if (err == 0)
            dav1d_picture_unref(&pic);
    } while (err != DAV1D_ERR(EAGAIN));

cleanup:
    dav1d_close(&ctx);
    return 0;
}
