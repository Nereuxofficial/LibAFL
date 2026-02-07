# LibAFL dav1d Fuzzer - Command Cheat Sheet

Quick reference for common commands and operations.

---

## 🚀 Quick Start

### Docker Compose (Recommended)
```bash
cd LibAFL/fuzzers/structure_aware/libfuzzer_dav1d
docker-compose up -d                    # Start fuzzing
docker-compose logs -f                  # View logs
docker-compose down                     # Stop fuzzing
```

### Docker Run (Without docker-compose.yml)
```bash
# From LibAFL root directory
docker build -f fuzzers/structure_aware/libfuzzer_dav1d/Dockerfile -t libafl-dav1d .

# Run with crash persistence
docker run -d --name libfuzzer_dav1d \
  --restart=unless-stopped \
  --cpus="4" --memory="4g" \
  -v $(pwd)/crashes:/fuzzer/fuzzer/crashes \
  -v $(pwd)/corpus_output:/fuzzer/fuzzer/corpus \
  -v $(pwd)/solutions:/fuzzer/fuzzer/solutions \
  libafl-dav1d ./target/release/libfuzzer_dav1d_concolic
```

### Management Script
```bash
./fuzzer.sh start                       # Start fuzzer
./fuzzer.sh logs                        # View logs
./fuzzer.sh stats                       # Show statistics
./fuzzer.sh stop                        # Stop fuzzer
./fuzzer.sh help                        # All commands
```

---

## 📋 Docker Compose Commands

### Starting & Stopping
```bash
docker-compose up -d                    # Start in background
docker-compose up                       # Start in foreground
docker-compose stop                     # Stop containers
docker-compose down                     # Stop and remove containers
docker-compose restart                  # Restart containers
```

### Concolic Mode
```bash
docker-compose --profile concolic up -d libfuzzer_dav1d_concolic    # Start concolic
docker-compose --profile concolic down                               # Stop concolic
```

### Monitoring
```bash
docker-compose logs -f                  # Follow logs (live)
docker-compose logs --tail=100          # Last 100 lines
docker-compose ps                       # Container status
docker-compose top                      # Process list
```

### Building
```bash
docker-compose build                    # Build image
docker-compose build --no-cache         # Clean rebuild
docker-compose pull                     # Pull base images
```

---

## 🐳 Docker Run Commands

### Basic Operations
```bash
# Build image
cd /path/to/LibAFL
docker build -f fuzzers/structure_aware/libfuzzer_dav1d/Dockerfile -t libafl-dav1d .

# Run with volumes mounted (CRITICAL for saving crashes)
docker run -d --name libfuzzer_dav1d \
  -v $(pwd)/crashes:/fuzzer/fuzzer/crashes \
  libafl-dav1d

# Stop and remove
docker stop libfuzzer_dav1d
docker rm libfuzzer_dav1d
```

### Full Command with All Options
```bash
docker run -d --name libfuzzer_dav1d \
  --restart=unless-stopped \
  --cpus="4" \
  --memory="4g" \
  -v $(pwd)/crashes:/fuzzer/fuzzer/crashes \
  -v $(pwd)/corpus_output:/fuzzer/fuzzer/corpus \
  -v $(pwd)/solutions:/fuzzer/fuzzer/solutions \
  -e RUST_LOG=info \
  -e RUST_BACKTRACE=1 \
  libafl-dav1d
```

### Concolic Mode
```bash
docker run -d --name libfuzzer_dav1d_concolic \
  --cpus="4" --memory="4g" \
  -v $(pwd)/crashes_concolic:/fuzzer/fuzzer/crashes \
  libafl-dav1d ./target/release/libfuzzer_dav1d_concolic --concolic
```

### Interactive Mode
```bash
docker run -it --rm libafl-dav1d /bin/bash                              # Open shell
docker run -it --rm libafl-dav1d ./target/release/libfuzzer_dav1d_concolic  # Run interactively
```

---

## 📊 Monitoring & Debugging

### View Logs
```bash
# Docker Compose
docker-compose logs -f
docker-compose logs --tail=100

# Docker Run
docker logs -f libfuzzer_dav1d
docker logs --tail=100 libfuzzer_dav1d
```

### Check Status
```bash
# Docker Compose
docker-compose ps
docker-compose top

# Docker Run
docker ps | grep libfuzzer_dav1d
docker stats libfuzzer_dav1d
docker inspect libfuzzer_dav1d
```

### Access Container Shell
```bash
# Docker Compose
docker-compose exec libfuzzer_dav1d /bin/bash

# Docker Run
docker exec -it libfuzzer_dav1d /bin/bash
```

---

## 📁 Output Management

### Check Results
```bash
# List crashes
ls -lh crashes/
find crashes -type f | wc -l            # Count crashes

# List corpus
ls -lh corpus_output/
find corpus_output -type f | wc -l      # Count corpus files

# List solutions
ls -lh solutions/
find solutions -type f | wc -l          # Count solutions
```

### Statistics
```bash
# Using script
./fuzzer.sh stats

# Manual
echo "Crashes: $(find crashes -type f 2>/dev/null | wc -l)"
echo "Corpus: $(find corpus_output -type f 2>/dev/null | wc -l)"
echo "Solutions: $(find solutions -type f 2>/dev/null | wc -l)"
```

### Export & Backup
```bash
# Export crashes with timestamp
./fuzzer.sh export-crashes

# Manual backup
tar -czf fuzzer-results-$(date +%Y%m%d).tar.gz crashes/ corpus_output/ solutions/

# Copy specific crash
cp crashes/crash-abc123 ~/important-crashes/
```

### Clean Output Directories
```bash
# Remove all output (careful!)
rm -rf crashes/ corpus_output/ solutions/
rm -rf crashes_concolic/ corpus_concolic/ solutions_concolic/

# Using script
./fuzzer.sh clean-all                   # Prompts for confirmation
```

---

## 🔧 Troubleshooting

### Build Issues
```bash
# Check disk space
df -h

# Clean Docker cache
docker system prune -a

# Rebuild from scratch
docker-compose down
docker-compose build --no-cache
```

### Container Not Starting
```bash
# Check logs
docker-compose logs libfuzzer_dav1d
docker logs libfuzzer_dav1d

# Check if port/name conflicts
docker ps -a | grep libfuzzer_dav1d

# Remove old containers
docker rm -f libfuzzer_dav1d
```

### Permission Issues
```bash
# Fix ownership of output directories
sudo chown -R $(id -u):$(id -g) crashes/ corpus_output/ solutions/

# Run as specific user (add to docker-compose.yml)
user: "1000:1000"
```

### Out of Memory
```bash
# Check memory usage
docker stats libfuzzer_dav1d

# Reduce memory limit in docker-compose.yml
memory: 2G  # Instead of 4G

# Or in docker run
docker run --memory="2g" ...
```

### Container Keeps Restarting
```bash
# Check why
docker-compose logs --tail=50 libfuzzer_dav1d

# Disable auto-restart
docker update --restart=no libfuzzer_dav1d

# Or in docker-compose.yml
restart: "no"
```

---

## 🛠️ Advanced Usage

### Resource Limits
```bash
# In docker-compose.yml
deploy:
  resources:
    limits:
      cpus: '4'
      memory: 4G

# In docker run
docker run --cpus="4" --memory="4g" ...
```

### Custom Corpus
```bash
# Add files before starting
mkdir -p corpus_output
cp /path/to/your/*.ivf corpus_output/
docker-compose up -d
```

### Run for Specific Duration
```bash
# 1 hour
timeout 1h docker-compose up

# 24 hours in background
docker-compose up -d
sleep 24h
docker-compose down
```

### Multiple Fuzzers
```bash
# Standard mode
docker-compose up -d libfuzzer_dav1d

# Concolic mode
docker-compose --profile concolic up -d libfuzzer_dav1d_concolic

# Or use script
./fuzzer.sh start-both
```

### Analyze Crashes
```bash
# Inside container
docker-compose exec libfuzzer_dav1d /bin/bash
cd /fuzzer/fuzzer
./target/release/libfuzzer_dav1d crashes/crash-XXXXX

# Copy crash out for analysis
docker cp libfuzzer_dav1d:/fuzzer/fuzzer/crashes/crash-XXXXX ./
```

---

## 📚 File Locations

### In Repository
```
libfuzzer_dav1d/
├── Dockerfile                  # Docker build instructions
├── docker-compose.yml          # Docker Compose configuration
├── fuzzer.sh                   # Management script
├── README.md                   # Full documentation
├── DOCKER_COMPOSE_QUICKSTART.md # Quick start guide
├── CHEATSHEET.md              # This file
├── env.example                # Environment variables example
├── fuzzer/                    # Fuzzer source code
├── runtime/                   # Concolic runtime
└── generate_corpus.py         # Corpus generation script
```

### In Container
```
/fuzzer/
├── fuzzer/                    # Fuzzer directory
│   ├── crashes/              # Crashes (mounted)
│   ├── corpus/               # Corpus (mounted)
│   ├── solutions/            # Solutions (mounted)
│   └── target/release/       # Built binaries
├── runtime/                   # Runtime library
├── dav1d/                    # dav1d library
└── corpus/                   # Initial corpus
```

### On Host (After Running)
```
libfuzzer_dav1d/
├── crashes/                   # Crashes found
├── corpus_output/             # Evolved corpus
├── solutions/                 # Solutions
├── crashes_concolic/          # Concolic crashes
├── corpus_concolic/           # Concolic corpus
└── solutions_concolic/        # Concolic solutions
```

---

## 🎯 Common Workflows

### Quick Test (5 minutes)
```bash
docker-compose up -d
sleep 300
docker-compose logs --tail=50
docker-compose down
ls crashes/
```

### Overnight Fuzzing Campaign
```bash
./fuzzer.sh start
# Next morning:
./fuzzer.sh stats
./fuzzer.sh export-crashes
```

### Continuous Fuzzing (Multiple Days)
```bash
docker-compose up -d
# Check periodically:
./fuzzer.sh stats
# Stop when satisfied:
docker-compose down
```

### Debug a Crash
```bash
./fuzzer.sh shell
cd crashes/
ls -lh
# Test crash file
./target/release/libfuzzer_dav1d crash-XXXXX
```

---

## 🔗 Quick Links

- **Full Documentation**: [README.md](README.md)
- **Quick Start Guide**: [DOCKER_COMPOSE_QUICKSTART.md](DOCKER_COMPOSE_QUICKSTART.md)
- **Environment Config**: [env.example](env.example)
- **Management Script Help**: `./fuzzer.sh help`

---

## 💡 Tips

1. **Always mount volumes** when using `docker run` to preserve crashes
2. **Use Docker Compose** for long-term fuzzing campaigns
3. **Monitor memory usage** with `docker stats`
4. **Run overnight** for best results
5. **Backup crashes regularly** with `./fuzzer.sh export-crashes`
6. **Check logs** if container restarts frequently
7. **Use both modes** (standard + concolic) for comprehensive testing
8. **Start simple** (docker-compose up -d) and customize later

---

**Need more help?** Check [README.md](README.md) or run `./fuzzer.sh help`

---

## ⚡ Performance Note

The Docker image runs the **pre-built release binary** (`./target/release/libfuzzer_dav1d_concolic`) instead of `cargo run --release`:

- ✅ **Instant startup** - No compilation time
- ✅ **Lower memory usage** - No cargo overhead  
- ✅ **Consistent performance** - Same optimized binary every time

The fuzzer is built during Docker image creation, so it starts immediately.
