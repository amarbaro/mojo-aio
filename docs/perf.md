# Performance

`scripts/bench.sh`: echo ping-pong, one uvloop client, 200 connections x 2000 round trips x 64 B,
3 runs per server. The client is the bottleneck for req/s, so server CPU per request is the number
that compares servers. Ryzen 7 7800X3D, Linux 7.2, 2026-11-04.

| Server | req/s | server CPU per request | peak RSS |
|---|---|---|---|
| mojo-aio | 100k to 107k | 4.5 us | 11 MB |
| uvloop | 118k to 123k | 4.4 to 4.5 us | 24 to 25 MB |
| Python asyncio | 52k to 56k | 14.6 to 15.4 us | 21 MB |
