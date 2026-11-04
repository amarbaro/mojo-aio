#!/usr/bin/env bash
# The gate: timers (order, never early, <=2 ms late), 10k concurrent echo connections with every
# byte checked, no fd leak after they close, and a negative control that must fail.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .work; M=.venv/bin/mojo; PY="python3 -I"
ulimit -n 65536 || { echo "FAIL setup: need 65536 fds"; exit 1; }
for t in echo timers; do
  timeout 120 $M build -I src tests/$t.mojo -o .work/$t 2>.work/build.err || { echo "FAIL build: tests/$t.mojo"; cat .work/build.err; exit 1; }
done
timeout 20 .work/timers || { echo "FAIL timers"; exit 1; }
serve() { AIO_BREAK=${1:-0} .work/echo > .work/port & pid=$!; for _ in $(seq 50); do [ -s .work/port ] && return; sleep 0.1; done; echo "FAIL setup: server did not start"; exit 1; }
serve; fd0=$(ls /proc/$pid/fd | wc -l)
timeout 60 $PY tools/client.py "$(cat .work/port)" 10000 3 || { kill $pid; echo "FAIL echo"; exit 1; }
sleep 0.3; fd1=$(ls /proc/$pid/fd | wc -l); kill $pid; wait $pid 2>/dev/null || true; : > .work/port
[ "$fd0" = "$fd1" ] || { echo "FAIL fd leak: $fd0 fds before, $fd1 after"; exit 1; }
echo "fds before $fd0 after $fd1"
serve 1
if timeout 20 $PY tools/client.py "$(cat .work/port)" 50 2 3 >/dev/null 2>&1; then kill $pid; echo "FAIL negative control: broken server passed"; exit 1; fi
kill $pid; wait $pid 2>/dev/null || true; : > .work/port
echo "negative control caught"
echo "PASS all"
