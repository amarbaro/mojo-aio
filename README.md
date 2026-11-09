# mojo-aio

<!-- badges -->
[![ci](https://github.com/amarbaro/mojo-aio/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/amarbaro/mojo-aio/actions/workflows/ci.yml) [![latest release](https://img.shields.io/github/v/release/amarbaro/mojo-aio)](https://github.com/amarbaro/mojo-aio/releases/latest) [![license](https://img.shields.io/github/license/amarbaro/mojo-aio)](https://github.com/amarbaro/mojo-aio/blob/main/LICENSE) [![checks](https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/amarbaro/mojo-aio/badges/checks.json)](https://github.com/amarbaro/mojo-aio/actions/workflows/ci.yml)
<!-- /badges -->

<!-- install -->
Install: `pixi workspace channel add https://conda.modular.com/max https://prefix.dev/amarbaro/amarbaro`, then `pixi add mojo-aio` (import `aio`). From source: `git clone https://github.com/amarbaro/mojo-aio`, then `mojo run -I mojo-aio/src app.mojo`.
Toolchains: Mojo 1.2 stable, and the nightly 1.3.0.dev2026110805 in the weekly [mojo-libs](https://github.com/amarbaro/mojo-libs) matrix (36 libraries on stable, 35 on nightly).

```mojo
import aio


def main() raises:
    var loop = aio.Loop()
    loop.after(10, 2)  # one TIMER event in 10 ms
    var evs = List[aio.Event]()
    _ = loop.wait(evs)
    print("timer", evs[0].token, "fired")
```

| Server | req/s | server CPU per request | peak RSS |
|---|---|---|---|
| mojo-aio | 100k to 107k | 4.5 us | 11 MB |
<!-- /install -->

epoll event loop for Mojo: readiness events, one-shot timers, non-blocking TCP. Callback-free:
`wait()` fills a list you own with `(token, events)` and you dispatch, so there is no closure
storage and no allocation per event. 163 lines of code, libc only, Linux.

Same server CPU per request as uvloop, a third of Python asyncio's, half the memory of either
(echo ping-pong, [docs/perf.md](docs/perf.md)).

Requires Mojo 1.2 on Linux.

## API

| Call | Does |
|---|---|
| `Loop(max_events=1024)` | epoll set; closed when the Loop is destroyed |
| `add/modify/remove(fd, events, token)` | register; events `IN OUT ERR HUP RDHUP ET ONESHOT` |
| `after(ms, token)` | one `TIMER` event, never early |
| `wait(evs, timeout_ms=-1)` | block; replace `evs` with what fired (descriptors and due timers) |
| `ready(evs, buf, timeout_ms)` | descriptors only; safe from many threads, each with its own `buf` |
| `tcp_listen(port, host="127.0.0.1")`, `local_port(fd)` | non-blocking listener |
| `accept(fd)` | next connection (TCP_NODELAY) or -1 |
| `read(fd, buf)`, `write(fd, span)` | bytes, 0 at EOF, -1 not ready, -2 error; no SIGPIPE |

[docs/design.md](docs/design.md) explains the choices, [docs/api.md](docs/api.md) lists every call. Used by [mojo-bento](https://github.com/amarbaro/mojo-bento)'s HTTP server.

**Limits:** Linux only (epoll). `wait()` and the timer heap belong to one thread; only `ready()` is meant for several threads, paired with `ONESHOT`. Per-connection I/O returns codes (-1 not ready, -2 gone) instead of raising.

## Check

`scripts/check.sh` (about 9 s): 2000 timers in deadline order and at most 2 ms late; 10,000
concurrent echo connections with every byte checked (446 MB); no descriptor leak; a server that
drops one byte per read must fail it. The README example above is `examples/quickstart.mojo`, run by the gate.
