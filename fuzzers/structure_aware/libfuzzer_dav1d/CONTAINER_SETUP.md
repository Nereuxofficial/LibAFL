# Container Setup Guide (Podman/Docker)

## Problem Solved

The original Docker build command failed with:
```
Error: COPY Cargo.toml: no such file or directory
```

**Root cause**: The Dockerfile needs to be built from the LibAFL **root directory**, not from the `libfuzzer_dav1d` directory.

## Solution: Build Helper Script

Created `build_container.sh` that:
1. ✅ Auto-detects Podman or Docker
2. ✅ Changes to the correct directory (LibAFL root)
3. ✅ Builds with proper context
4. ✅ Shows clear next steps

---

## Quick Start

### Build the Image

```bash
# Simply run the build script
./build_container.sh

# Or with custom name
./build_container.sh my-custom-name
```

### Run with Podman (Recommended)

```bash
# Run in background with volume mounts
podman run -d --name libfuzzer_dav1d \
  --cpus=4 --memory=4g \
  -v $(pwd)/crashes:/fuzzer/fuzzer/crashes:Z \
  -v $(pwd)/corpus_output:/fuzzer/fuzzer/corpus:Z \
  -v $(pwd)/solutions:/fuzzer/fuzzer/solutions:Z \
  libafl-dav1d

# View logs
podman logs -f libfuzzer_dav1d

# Check status
podman ps

# Stop
podman stop libfuzzer_dav1d
```

**Important**: Use `:Z` flag for SELinux systems (Fedora, RHEL, CentOS).

### Run with Docker

```bash
# Run in background with volume mounts
docker run -d --name libfuzzer_dav1d \
  --cpus=4 --memory=4g \
  -v $(pwd)/crashes:/fuzzer/fuzzer/crashes \
  -v $(pwd)/corpus_output:/fuzzer/fuzzer/corpus \
  -v $(pwd)/solutions:/fuzzer/fuzzer/solutions \
  libafl-dav1d

# View logs
docker logs -f libfuzzer_dav1d

# Stop
docker stop libfuzzer_dav1d
```

---

## Why Use the Build Script?

### ❌ Don't Do This:
```bash
# WRONG - builds from wrong directory
cd fuzzers/structure_aware/libfuzzer_dav1d
podman build -t libafl-dav1d .
# Error: COPY Cargo.toml: no such file or directory ❌
```

### ✅ Do This Instead:
```bash
# CORRECT - uses build script
cd fuzzers/structure_aware/libfuzzer_dav1d
./build_container.sh
# Success! ✅
```

---

## Podman vs Docker

Both work equally well for this fuzzer:

| Feature | Podman | Docker |
|---------|--------|--------|
| **Security** | Rootless by default | Requires configuration |
| **Daemon** | Daemonless | Requires dockerd |
| **SELinux** | Native support (use `:Z`) | May need configuration |
| **Commands** | `podman run/ps/logs` | `docker run/ps/logs` |
| **Performance** | ✅ Same | ✅ Same |
| **Recommendation** | ✅ Preferred | ✅ Works great |

---

## Documentation

- **PODMAN_GUIDE.md** - Complete Podman usage guide (17 KB)
- **README.md** - General fuzzer documentation
- **build_container.sh** - Build helper script

---

## Troubleshooting

### "Cannot connect to docker daemon"
→ You're using Podman! Use `podman` commands or create an alias:
```bash
alias docker=podman
```

### "permission denied" with volumes
→ Add `:Z` flag for SELinux:
```bash
-v $(pwd)/crashes:/fuzzer/fuzzer/crashes:Z
```

### Build fails with "COPY" errors
→ Use the build script:
```bash
./build_container.sh
```

### Out of disk space
→ Clean up old images:
```bash
podman system prune -a
# or
docker system prune -a
```

---

## Next Steps

1. ✅ Build image: `./build_container.sh`
2. ✅ Run fuzzer: `podman run -d ...` (see examples above)
3. ✅ Monitor: `podman logs -f libfuzzer_dav1d`
4. ✅ Check crashes: `ls -lh crashes/`

**The fuzzer will start immediately and begin finding bugs!** 🐛🔍

---

*For more details, see PODMAN_GUIDE.md*
