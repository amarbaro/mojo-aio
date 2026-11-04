# mojo-aio

epoll event loop for Mojo: readiness events, one-shot timers, non-blocking TCP. Callback-free:
`wait()` fills a list you own with `(token, events)` and you dispatch, so there is no closure
storage and no allocation per event. 163 lines of code, libc only, Linux.

Same server CPU per request as uvloop, a third of Python asyncio's, half the memory of either
(echo ping-pong, [docs/perf.md](docs/perf.md)).

```mojo
import aio


def main() raises:
    var lfd = aio.tcp_listen(0)  # 127.0.0.1, a free port
    var loop = aio.Loop()
    loop.add(lfd, aio.IN, 1)
    loop.after(10, 2)  # one TIMER event in 10 ms
    var evs = List[aio.Event]()
    while True:
        _ = loop.wait(evs)
        for ev in evs:
            if ev.events & aio.TIMER:
                print("timer", ev.token, "fired; port", aio.local_port(lfd) > 0)
                aio.close(lfd)
                return
```

## Install

Requires Mojo 1.2 on Linux. `mojo run -I path/to/mojo-aio/src app.mojo`, or copy `src/aio/` into your project.

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

[docs/design.md](docs/design.md) explains the choices. Used by [mojo-bento](https://github.com/amarbaro/mojo-bento)'s HTTP server.

## Check

`scripts/check.sh` (about 9 s): 2000 timers in deadline order and at most 2 ms late; 10,000
concurrent echo connections with every byte checked (446 MB); no descriptor leak; a server that
drops one byte per read must fail it. The README example above is `examples/quickstart.mojo`, run by the gate.
