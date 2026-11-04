#!/usr/bin/env bash
# Echo ping-pong req/s (client-bound), server CPU per request and peak RSS: mojo-aio vs Python asyncio vs uvloop, same uvloop
# client (200 conns x 2000 round trips x 64 B), 3 runs each. Run scripts/check.sh first (builds .work/echo).
set -euo pipefail
cd "$(dirname "$0")/.."
ulimit -n 65536
PY=.venv/bin/python
[[ -x .work/echo ]] || { echo "FAIL setup: .work/echo missing (run scripts/check.sh)"; exit 1; }
for srv in mojo asyncio uvloop; do
  for i in 1 2 3; do
    if [ $srv = mojo ]; then .work/echo > .work/bport & else $PY -I tools/bench_server.py $srv > .work/bport & fi
    pid=$!; for _ in $(seq 50); do [ -s .work/bport ] && break; sleep 0.1; done
    rps=$(timeout 60 $PY -I tools/bench_client.py "$(cat .work/bport)" 200 2000 64) || { kill $pid; echo "FAIL bench: $srv"; exit 1; }
    rss=$(awk '/VmHWM/{print int($2/1024)}' /proc/$pid/status)
    cpu=$(awk -v hz="$(getconf CLK_TCK)" -v rps="$rps" '{printf "%.1f", ($14+$15)/hz*1e6/(200*2000)}' /proc/$pid/stat); kill $pid; wait $pid 2>/dev/null || true; : > .work/bport
    echo "$srv run $i: $rps req/s, server CPU $cpu us/req, peak RSS $rss MB"
  done
done
