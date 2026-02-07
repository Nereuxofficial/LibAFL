# Podman Usage Guide for LibAFL dav1d Fuzzer

This guide covers using Podman (instead of Docker) to run the LibAFL dav1d fuzzer.

## Why Podman?

Podman is a daemonless, rootless container engine that's API-compatible with Docker:
- ✅ **Rootless** - Run containers without root privileges
- ✅ **Daemonless** - No background daemon required
- ✅ **Drop-in replacement** - Compatible with Docker commands
- ✅ **Systemd integration** - Better service management
- ✅ **Security** - More secure default configuration

## Quick Start

### 1. Build the Container Image

```bash
# From the libfuzzer_dav1d directory
./build_container.sh

# Or specify a custom image name
./build_container.sh my-fuzzer-image
```

The script auto-detects Podman and builds from the correct directory.

### 2. Run the Fuzzer

```bash
# Run interactively
podman run -it libafl-dav1d

# Run in background with volume mounts
cd fuzzers/structure_aware/libfuzzer_dav1d
podman run -d --name libfuzzer_dav1d \
  -v $(pwd)/crashes:/fuzzer/fuzzer/crashes:Z \
  -v $(pwd)/corpus_output:/fuzzer/fuzzer/corpus:Z \
  -v $(pwd)/solutions:/fuzzer/fuzzer/solutions:Z \
  libafl-dav1d

# Note: `:Z` is important for SELinux systems (Fedora, RHEL, etc.)
```

### 3. Manage the Container

```bash
# View running containers
podman ps

# View all containers (including stopped)
podman ps -a

# View logs
podman logs -f libfuzzer_dav1d

# Stop container
podman stop libfuzzer_dav1d

# Start stopped container
podman start libfuzzer_dav1d

# Remove container
podman rm libfuzzer_dav1d

# View resource usage
podman stats libfuzzer_dav1d
```

## Podman vs Docker Commands

Podman commands are nearly identical to Docker:

| Docker | Podman | Notes |
|--------|--------|-------|
| `docker build` | `podman build` | Same syntax |
| `docker run` | `podman run` | Add `:Z` for SELinux |
| `docker ps` | `podman ps` | Identical |
| `docker logs` | `podman logs` | Identical |
| `docker-compose` | `podman-compose` | Requires separate install |

## Using Podman-Compose

If you have `podman-compose` installed, you can use docker-compose.yml:

### Install Podman-Compose

```bash
# Ubuntu/Debian
sudo apt install podman-compose

# Fedora
sudo dnf install podman-compose

# Or via pip
pip3 install --user podman-compose
```

### Run with Podman-Compose

```bash
# Start fuzzer
podman-compose up -d

# View logs
podman-compose logs -f

# Stop fuzzer
podman-compose down

# Start concolic mode
podman-compose --profile concolic up -d
```

**Note**: The existing `docker-compose.yml` works with `podman-compose` without modifications!

## Rootless Podman Setup

Podman runs rootless by default, but you may need to configure user namespaces:

### Check Configuration

```bash
# Check if subuid/subgid are configured
cat /etc/subuid | grep $USER
cat /etc/subgid | grep $USER

# Should show something like:
# username:100000:65536
```

### Fix User Namespace Issues

If you get permission errors:

```bash
# Add user namespaces
echo "$USER:100000:65536" | sudo tee -a /etc/subuid
echo "$USER:100000:65536" | sudo tee -a /etc/subgid

# Restart user session or run:
podman system migrate
```

## Volume Mounts with SELinux

On SELinux-enabled systems (Fedora, RHEL, CentOS), use `:Z` or `:z` flags:

```bash
# Private label (exclusive to this container) - RECOMMENDED
-v $(pwd)/crashes:/fuzzer/fuzzer/crashes:Z

# Shared label (shared between containers)
-v $(pwd)/crashes:/fuzzer/fuzzer/crashes:z

# Disable SELinux for this mount (not recommended)
-v $(pwd)/crashes:/fuzzer/fuzzer/crashes:U
```

**Use `:Z` (uppercase) for this fuzzer** - ensures proper isolation.

## Running Multiple Fuzzers

Podman makes it easy to run multiple isolated fuzzers:

```bash
# Fuzzer 1
podman run -d --name fuzzer1 \
  -v $(pwd)/fuzzer1_crashes:/fuzzer/fuzzer/crashes:Z \
  -v $(pwd)/fuzzer1_corpus:/fuzzer/fuzzer/corpus:Z \
  libafl-dav1d

# Fuzzer 2
podman run -d --name fuzzer2 \
  -v $(pwd)/fuzzer2_crashes:/fuzzer/fuzzer/crashes:Z \
  -v $(pwd)/fuzzer2_corpus:/fuzzer/fuzzer/corpus:Z \
  libafl-dav1d

# Fuzzer 3 (concolic mode)
podman run -d --name fuzzer3 \
  -v $(pwd)/fuzzer3_crashes:/fuzzer/fuzzer/crashes:Z \
  -v $(pwd)/fuzzer3_corpus:/fuzzer/fuzzer/corpus:Z \
  libafl-dav1d ./target/release/libfuzzer_dav1d_concolic --concolic

# Monitor all
podman stats fuzzer1 fuzzer2 fuzzer3
```

## Resource Limits

Set CPU and memory limits:

```bash
podman run -d --name libfuzzer_dav1d \
  --cpus=4 \
  --memory=4g \
  --memory-swap=4g \
  -v $(pwd)/crashes:/fuzzer/fuzzer/crashes:Z \
  libafl-dav1d
```

## Systemd Integration

Run fuzzer as a systemd service (rootless):

### Create Service File

```bash
mkdir -p ~/.config/systemd/user/
```

Create `~/.config/systemd/user/libfuzzer-dav1d.service`:

```ini
[Unit]
Description=LibAFL dav1d Fuzzer
After=network.target

[Service]
Type=simple
ExecStartPre=/usr/bin/podman rm -f libfuzzer_dav1d || true
ExecStart=/usr/bin/podman run --name libfuzzer_dav1d \
  --cpus=4 --memory=4g \
  -v %h/fuzzer/crashes:/fuzzer/fuzzer/crashes:Z \
  -v %h/fuzzer/corpus:/fuzzer/fuzzer/corpus:Z \
  -v %h/fuzzer/solutions:/fuzzer/fuzzer/solutions:Z \
  libafl-dav1d
ExecStop=/usr/bin/podman stop -t 10 libfuzzer_dav1d
Restart=always
RestartSec=10

[Install]
WantedBy=default.target
```

### Manage Service

```bash
# Reload systemd
systemctl --user daemon-reload

# Enable service (start on boot)
systemctl --user enable libfuzzer-dav1d

# Start service
systemctl --user start libfuzzer-dav1d

# Check status
systemctl --user status libfuzzer-dav1d

# View logs
journalctl --user -u libfuzzer-dav1d -f

# Stop service
systemctl --user stop libfuzzer-dav1d

# Disable service
systemctl --user disable libfuzzer-dav1d
```

### Enable Lingering (keep running when logged out)

```bash
loginctl enable-linger $USER
```

## Troubleshooting

### Issue: "permission denied" mounting volumes

**Solution**: Use `:Z` flag and check SELinux:

```bash
# Check SELinux status
getenforce

# If Enforcing, use :Z flag
podman run -v $(pwd)/crashes:/fuzzer/fuzzer/crashes:Z ...

# Or temporarily disable SELinux (not recommended)
sudo setenforce 0
```

### Issue: "no such file or directory" for subuid/subgid

**Solution**: Configure user namespaces:

```bash
# Add entries
echo "$USER:100000:65536" | sudo tee -a /etc/subuid
echo "$USER:100000:65536" | sudo tee -a /etc/subgid

# Migrate Podman
podman system migrate

# Restart user session
logout / login
```

### Issue: "cannot connect to Podman socket"

**Solution**: Start Podman socket (if needed):

```bash
# Start socket
systemctl --user start podman.socket

# Enable socket
systemctl --user enable podman.socket

# Check status
systemctl --user status podman.socket
```

### Issue: Build fails with "COPY" errors

**Solution**: Use the build script (builds from correct directory):

```bash
# Don't run from libfuzzer_dav1d directory:
# podman build -t libafl-dav1d .  ❌

# Use the helper script instead:
./build_container.sh  ✅
```

### Issue: Out of disk space

**Solution**: Clean up Podman storage:

```bash
# Remove unused images
podman image prune -a

# Remove unused containers
podman container prune

# Remove all unused data
podman system prune -a

# Check disk usage
podman system df
```

### Issue: Container runs but no output

**Solution**: Check logs and run interactively:

```bash
# View logs
podman logs libfuzzer_dav1d

# Run interactively to see output
podman run -it --rm libafl-dav1d

# Execute shell in running container
podman exec -it libfuzzer_dav1d /bin/bash
```

## Performance Tips

### 1. Use Overlay Storage Driver

Edit `~/.config/containers/storage.conf`:

```ini
[storage]
driver = "overlay"
```

### 2. Disable Logging (for speed)

```bash
podman run -d \
  --log-driver=none \
  --name libfuzzer_dav1d \
  libafl-dav1d
```

### 3. Use tmpfs for Temporary Data

```bash
podman run -d \
  --tmpfs /tmp:rw,size=1g,mode=1777 \
  --name libfuzzer_dav1d \
  libafl-dav1d
```

### 4. Pin to Specific CPUs

```bash
podman run -d \
  --cpuset-cpus=0-3 \
  --name libfuzzer_dav1d \
  libafl-dav1d
```

## Comparison: Podman vs Docker for Fuzzing

| Feature | Podman | Docker | Winner |
|---------|--------|--------|--------|
| Rootless | ✅ Native | ⚠️ Experimental | Podman |
| Security | ✅ Better defaults | ⚠️ Needs config | Podman |
| Daemon | ✅ Daemonless | ❌ Requires daemon | Podman |
| Systemd | ✅ Native | ⚠️ Workarounds | Podman |
| Performance | ✅ Comparable | ✅ Comparable | Tie |
| Ecosystem | ⚠️ Smaller | ✅ Larger | Docker |
| Compatibility | ✅ Drop-in replacement | N/A | Podman |

**Recommendation**: Use Podman for security and rootless operation. Both work equally well for fuzzing.

## Migration from Docker

Already using Docker? Switch to Podman:

```bash
# Install Podman
sudo apt install podman  # Ubuntu/Debian
sudo dnf install podman  # Fedora

# Stop Docker daemon (optional)
sudo systemctl stop docker
sudo systemctl disable docker

# Alias docker to podman (optional)
echo "alias docker=podman" >> ~/.bashrc
source ~/.bashrc

# Now all docker commands work with podman!
docker ps
docker run -it libafl-dav1d
```

**All existing Docker commands work with Podman!**

## Advanced: Podman Pod for Multi-Container Setup

Run fuzzer + monitoring in a pod:

```bash
# Create pod
podman pod create --name fuzzer-pod -p 8080:8080

# Run fuzzer in pod
podman run -d --pod fuzzer-pod \
  --name fuzzer \
  -v $(pwd)/crashes:/fuzzer/fuzzer/crashes:Z \
  libafl-dav1d

# Run monitoring in pod (example: simple HTTP server)
podman run -d --pod fuzzer-pod \
  --name monitor \
  -v $(pwd)/crashes:/crashes:Z,ro \
  python:3.11 python3 -m http.server 8080 -d /crashes

# Access monitoring at http://localhost:8080
# Both containers share the network namespace
```

## References

- [Podman Official Documentation](https://docs.podman.io/)
- [Podman vs Docker](https://docs.podman.io/en/latest/Introduction.html)
- [Rootless Containers](https://rootlesscontaine.rs/)
- [Podman-Compose](https://github.com/containers/podman-compose)

---

## Quick Command Reference

```bash
# Build
./build_container.sh

# Run
podman run -d --name libfuzzer_dav1d \
  -v $(pwd)/crashes:/fuzzer/fuzzer/crashes:Z \
  libafl-dav1d

# Monitor
podman logs -f libfuzzer_dav1d
podman stats libfuzzer_dav1d

# Stop/Start
podman stop libfuzzer_dav1d
podman start libfuzzer_dav1d

# Clean up
podman rm -f libfuzzer_dav1d
podman system prune -a
```

---

**Ready to fuzz with Podman!** 🚀🐛