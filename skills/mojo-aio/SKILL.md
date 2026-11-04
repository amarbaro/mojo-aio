---
name: mojo-aio
description: "epoll event loop for Mojo on Linux: sockets, pipes, signalfd/inotify fds and timers, level or edge triggered, single or multi-threaded. Use when a Mojo program must wait on many file descriptors."
metadata:
  short-description: "epoll event loop for Mojo: fds, timers, TCP listen/accept, multi-threaded ready()"
---

# mojo-aio

Mojo 1.2, Linux, straight to epoll.

## When to use

A program waits on sockets, pipes, signalfd/inotify fds or timers. Not for file I/O or other OSes.

## Install

`mojo run -I src app.mojo` from a clone, or copy `src/aio/`.

## The calls

```mojo
import aio

def main() raises:
    var lfd = aio.tcp_listen(0, "127.0.0.1")        # port 0: pick a free one
    print(aio.local_port(lfd) > 0)
    var loop = aio.Loop()
    loop.add(lfd, aio.IN | aio.RDHUP, UInt64(1))    # token: whatever you dispatch on
    loop.after(10, UInt64(2))                       # a TIMER event in 10 ms
    var evs = List[aio.Event]()
    _ = loop.wait(evs)                              # evs is replaced on each call
    for e in evs:
        if e.events & aio.TIMER != 0:
            print("timer", e.token)
        elif e.token == 1:
            var c = aio.accept(lfd)                 # -1 when nobody waits
            if c >= 0:
                aio.close(c)
    var buf = List[UInt8](length=4096, fill=0)
    # aio.read(fd, buf): bytes, 0 at EOF, -1 not ready, -2 error;  aio.write(fd, span) may be partial
    aio.close(lfd)
```

## Gotchas

- `write` may be partial: keep the rest, arm `aio.OUT` with `modify`, write on the OUT event, re-arm `IN`.
- Level triggered by default: one read per event is enough. With `aio.ET`, read until `-1`.
- Multi-threaded: workers share one `Loop`; each calls `loop.ready(evs, buf, ms)` with its **own** `buf`
  (3 `UInt32` per slot) and registers fds with `aio.ONESHOT`, then `modify` re-arms after serving.
  Only one thread may call `wait()` (it owns the timer heap).
- Timer events carry the `aio.TIMER` bit in `events` and the token you gave to `after`.

## Gate

`scripts/check.sh` from the repo: 10k connections, timers, fd leak, a negative control, README equals
`examples/quickstart.mojo`.
