#!/bin/bash

echo "=================================="
echo "Concolic Fuzzer Diagnostic Script"
echo "=================================="
echo ""

echo "1. Container Status:"
podman ps -a | grep concolic || docker ps -a | grep concolic
echo ""

echo "2. Corpus Directory Contents:"
echo "   Host corpus_concolic:"
ls -lh corpus_concolic/ | head -30
echo "   Total files: $(find corpus_concolic/ -type f | wc -l)"
echo ""

echo "3. Inside Container Corpus:"
podman exec libfuzzer_dav1d_concolic find ./corpus -type f | head -30 || docker exec libfuzzer_dav1d_concolic find ./corpus -type f | head -30
echo "   Total files visible: $(podman exec libfuzzer_dav1d_concolic find ./corpus -type f | wc -l || docker exec libfuzzer_dav1d_concolic find ./corpus -type f | wc -l)"
echo ""

echo "4. Recent Fuzzer Logs (last 50 lines):"
podman logs --tail 50 libfuzzer_dav1d_concolic || docker logs --tail 50 libfuzzer_dav1d_concolic
echo ""

echo "5. Coverage and Corpus Stats:"
podman logs --tail 200 libfuzzer_dav1d_concolic 2>&1 | grep -E "corpus:|edges:" | tail -20 || docker logs --tail 200 libfuzzer_dav1d_concolic 2>&1 | grep -E "corpus:|edges:" | tail -20
echo ""

echo "6. Solutions and Crashes:"
echo "   Solutions:"
ls -lh solutions_concolic/ 2>&1
echo "   Crashes:"
ls -lh crashes_concolic/ 2>&1
echo ""

echo "7. Resource Usage:"
podman stats --no-stream libfuzzer_dav1d_concolic || docker stats --no-stream libfuzzer_dav1d_concolic
echo ""

echo "8. Testing corpus accessibility from inside container:"
echo "   Sample file test:"
podman exec libfuzzer_dav1d_concolic sh -c "ls -lh ./corpus/*.ivf | head -5" || docker exec libfuzzer_dav1d_concolic sh -c "ls -lh ./corpus/*.ivf | head -5"
echo ""

echo "9. Checking for symcc target binary:"
podman exec libfuzzer_dav1d_concolic ls -lh ./target_symcc.out 2>&1 || docker exec libfuzzer_dav1d_concolic ls -lh ./target_symcc.out 2>&1
echo ""

echo "10. Current working directory inside container:"
podman exec libfuzzer_dav1d_concolic pwd || docker exec libfuzzer_dav1d_concolic pwd
echo ""

echo "=================================="
echo "Diagnostic Complete"
echo "=================================="
