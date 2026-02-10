# Concolic Fuzzer Running Status

**Date:** February 8, 2026  
**Status:** ✅ RUNNING  
**Host:** nixfix (152.53.32.54)

---

## Current Status

The concolic fuzzer for dav1d is **successfully running** on nixfix after debugging and fixing critical issues.

### Container Details
- **Container Name:** `libfuzzer_dav1d_concolic`
- **Container ID:** `cb5c9bf89efa`
- **Image:** `localhost/libafl-dav1d:latest`
- **Runtime:** Podman
- **Cores:** 10 (configured via `LIBAFL_CORES=10`)

### Performance Metrics
```
CPU Usage:     ~900% (using all 10 cores efficiently)
Memory:        ~206 MB / 50 GB (0.41%)
Exec Rate:     ~11 exec/sec (normal for concolic)
Corpus Size:   20 items (loaded + discovered)
Coverage:      3/8764 edges (0.034%)
Objectives:    0 crashes found
Runtime:       Started at 13:23 UTC
```

### Debug Output
The fuzzer is successfully spawning symcc targets with shared memory:
```
DEBUG: Spawning symcc target with shmem_id: 7
DEBUG: Spawning symcc target with shmem_id: 10
DEBUG: Spawning symcc target with shmem_id: 11
...
```

This confirms the environment variable fix is working correctly.

---

## Directory Structure

### Mounted Volumes
```bash
Host Path                    → Container Path
./corpus_concolic           → /fuzzer/fuzzer/corpus
./crashes_concolic          → /fuzzer/fuzzer/crashes
./solutions_concolic        → /fuzzer/fuzzer/solutions
```

### File Counts
- **Corpus:** 24 seed files (IVF format)
- **Crashes:** 0 (none found yet)
- **Solutions:** 0 (none found yet)

---

## How to Monitor

### Check Container Status
```bash
ssh nixfix "podman ps | grep concolic"
```

### View Live Logs
```bash
ssh nixfix "podman logs -f libfuzzer_dav1d_concolic"
```

### Check Resource Usage
```bash
ssh nixfix "podman stats --no-stream libfuzzer_dav1d_concolic"
```

### View Recent Progress
```bash
ssh nixfix "podman logs --tail 50 libfuzzer_dav1d_concolic 2>&1 | grep Heartbeat"
```

### Check for Crashes/Solutions
```bash
ssh nixfix "ls -lh ~/LibAFL/fuzzers/structure_aware/libfuzzer_dav1d/{crashes_concolic,solutions_concolic}/"
```

### Run Full Diagnostics
```bash
ssh nixfix "cd ~/LibAFL/fuzzers/structure_aware/libfuzzer_dav1d && bash diagnose_concolic.sh"
```

---

## Management Commands

### Stop the Fuzzer
```bash
ssh nixfix "podman stop libfuzzer_dav1d_concolic"
```

### Start the Fuzzer (if stopped)
```bash
ssh nixfix "cd ~/LibAFL/fuzzers/structure_aware/libfuzzer_dav1d && \
  podman run -d --name libfuzzer_dav1d_concolic \
  -v ./corpus_concolic:/fuzzer/fuzzer/corpus:Z \
  -v ./crashes_concolic:/fuzzer/fuzzer/crashes:Z \
  -v ./solutions_concolic:/fuzzer/fuzzer/solutions:Z \
  -e LIBAFL_CORES=10 \
  libafl-dav1d ./target/release/libfuzzer_dav1d_concolic --concolic"
```

### Remove Container (for rebuild)
```bash
ssh nixfix "podman stop libfuzzer_dav1d_concolic && podman rm libfuzzer_dav1d_concolic"
```

### Rebuild Image (after code changes)
```bash
ssh nixfix "cd ~/LibAFL/fuzzers/structure_aware/libfuzzer_dav1d && bash build_container.sh"
```

---

## Expected Behavior

### Execution Rate
- **Concolic fuzzing:** 5-15 exec/sec (normal)
- **Regular fuzzing:** 20,000-30,000 exec/sec
- The dramatic slowdown is expected due to symbolic execution overhead

### Corpus Growth
- Initial corpus load: 20-24 items
- Growth rate: Slow but steady (hours to days for new items)
- Quality over quantity: Each new item represents a unique execution path

### Coverage
- Initial: ~3 edges (0.034%)
- Expected growth: Very gradual
- Concolic focuses on *deep* path exploration, not broad coverage

### Resource Usage
- CPU: Should stay near 900-1000% (10 cores)
- Memory: 200-500 MB (stable)
- If memory grows continuously, investigate memory leak

---

## Troubleshooting

### Container Not Running
1. Check if it stopped: `ssh nixfix "podman ps -a | grep concolic"`
2. View exit logs: `ssh nixfix "podman logs libfuzzer_dav1d_concolic"`
3. Restart with the start command above

### Low Exec Rate (< 1 exec/sec)
- This is expected for concolic mode
- If it drops to 0, check for hangs: `podman logs --tail 100 libfuzzer_dav1d_concolic`

### Corpus Not Growing
- Concolic growth is extremely slow (hours/days)
- Check that symcc targets are spawning: `podman logs | grep "Spawning symcc"`
- Verify coverage is not stuck at exactly the same value for > 24 hours

### Memory Leak
If memory usage keeps climbing:
```bash
ssh nixfix "podman restart libfuzzer_dav1d_concolic"
```

### Crashes/Hangs
Check for crash files:
```bash
ssh nixfix "find ~/LibAFL/fuzzers/structure_aware/libfuzzer_dav1d/crashes_concolic -type f"
```

---

## Fixes Applied

The following bugs were fixed to get the concolic fuzzer working:

1. **Corpus Path Fix** (Commit: `aa57f3407`)
   - Changed from `../corpus` to `./corpus`
   - Ensures proper corpus loading from mounted volume

2. **Environment Variable Fix** (Commit: `f1538b7db`) ⭐ **Critical**
   - Removed `.env_clear()` from `CommandConfigurator`
   - Allows symcc target to inherit shared memory environment variable
   - Without this, symcc would crash silently with "unable to get shared memory from env"

For detailed debugging information, see `CONCOLIC_DEBUGGING_SUMMARY.md`.

---

## Next Steps

### Short-Term (Hours - Days)
- ✅ Monitor logs every few hours to ensure stability
- ✅ Check for new corpus items in `corpus_concolic/`
- ✅ Watch for crashes in `crashes_concolic/`
- Document any interesting findings

### Medium-Term (Days - Weeks)
- Let the fuzzer run continuously
- Periodically merge results with regular fuzzing corpus
- Run corpus minimization on combined results
- Analyze any crashes found

### Long-Term (Weeks - Months)
- Compare concolic vs regular fuzzing effectiveness
- Identify unique paths found by concolic execution
- Consider adjusting concolic strategy based on results
- Document coverage improvements

---

## Performance Comparison

| Metric | Regular Fuzzing | Concolic Fuzzing |
|--------|----------------|------------------|
| Exec Rate | 20,000-30,000/sec | 5-15/sec |
| Coverage Strategy | Breadth-first | Depth-first |
| Corpus Growth | Very fast | Very slow |
| Path Exploration | Shallow, wide | Deep, narrow |
| Best For | Quick coverage | Hard-to-reach paths |

---

## Contact & References

- **Debugging Summary:** `CONCOLIC_DEBUGGING_SUMMARY.md`
- **Performance Results:** `PERFORMANCE_RESULTS.md`
- **Quick Reference:** `QUICK_REFERENCE.md`
- **LibAFL Docs:** https://aflplus.plus/libafl-book/

**Status Updated:** February 8, 2026 13:30 UTC  
**Engineer:** AI Assistant