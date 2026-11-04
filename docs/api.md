# API

Everything is in `aio` (`src/aio/__init__.mojo`). Linux only: epoll, non-blocking sockets.

## Event flags (`UInt32`)

`IN` readable · `OUT` writable · `ERR` error · `HUP` hang-up · `RDHUP` peer closed its write side ·
`ONESHOT` disarm after one event · `ET` edge-triggered · `TIMER` set on events from `after()`.

## `Event`

`token: UInt64` (what you passed to `add` or `after`), `events: UInt32` (the flags that fired).

## `Loop`

| signature | does | raises |
|---|---|---|
| `Loop(max_events: Int = 1024) raises` | an epoll instance; closed in `__deinit__` | when `epoll_create1` fails |
| `add(self, fd: Int32, events: UInt32, token: UInt64) raises` | watch `fd` | on `epoll_ctl` failure |
| `modify(self, fd: Int32, events: UInt32, token: UInt64) raises` | change flags or token (re-arm a `ONESHOT`) | on `epoll_ctl` failure |
| `remove(self, fd: Int32) raises` | stop watching `fd` | on `epoll_ctl` failure |
| `after(mut self, ms: Int, token: UInt64)` | one `TIMER` event carrying `token`, no earlier than `ms` from now | no |
| `wait(mut self, mut out: List[Event], timeout_ms: Int = -1) raises -> Int` | block until a descriptor is ready, a timer is due, or the timeout passes (`-1`: no limit); replaces `out`, returns `len(out)`; a signal yields 0 events | on `epoll_wait` failure |
| `ready(self, mut out: List[Event], mut buf: List[UInt32], timeout_ms: Int) raises -> Int` | append ready descriptors to `out`, no timers; safe from many threads when each passes its own `buf` (3 `UInt32` per slot); pair with `ONESHOT` | on `epoll_wait` failure |

## Sockets

| signature | returns | raises |
|---|---|---|
| `tcp_listen(port: Int, host: String = "127.0.0.1", backlog: Int = 4096) raises -> Int32` | non-blocking listening TCP socket; port 0 picks a free one | bad IPv4 host, socket/bind/listen failure |
| `local_port(fd: Int32) raises -> Int` | the port a socket is bound to | on `getsockname` failure |
| `accept(fd: Int32) raises -> Int32` | next connection, non-blocking with `TCP_NODELAY`; `-1` when none is waiting, it was aborted, or descriptors ran out (retry on the next event) | on any other `accept4` error |
| `read(fd: Int32, mut buf: List[UInt8]) -> Int` | fills `buf` up to its length: bytes read, `0` end of stream, `-1` not ready, `-2` error | no |
| `write(fd: Int32, data: Span[UInt8, _]) -> Int` | writes what fits now, no `SIGPIPE`: bytes written, `-1` not ready, `-2` error (peer gone) | no |
| `close(fd: Int32)` | close a descriptor | no |

`host` accepts a dotted quad, `"localhost"`, or `""` / `"*"` for every interface.
