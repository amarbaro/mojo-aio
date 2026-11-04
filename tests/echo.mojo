# Echo server for the gate: `echo [port]` prints its port, echoes every byte, handles partial writes.
# AIO_BREAK=1 drops the last byte of each read (negative control: the gate must fail).
from std.os import getenv
from std.sys import argv
import aio

comptime LISTENER: UInt64 = 1 << 40


def main() raises:
    var lfd = aio.tcp_listen(Int(argv()[1]) if len(argv()) > 1 else 0)
    print(aio.local_port(lfd), flush=True)
    var brk = 1 if getenv("AIO_BREAK") == "1" else 0
    var loop = aio.Loop()
    loop.add(lfd, aio.IN, LISTENER)
    var evs = List[aio.Event]()
    var buf = List[UInt8](length=65536, fill=0)
    var pending = Dict[Int32, List[UInt8]]()  # bytes the kernel had no room for yet
    while True:
        _ = loop.wait(evs)
        for ev in evs:
            if ev.token == LISTENER:
                while True:
                    var c = aio.accept(lfd)
                    if c < 0:
                        break
                    loop.add(c, aio.IN | aio.RDHUP, UInt64(c))
                continue
            var fd = Int32(ev.token)
            if ev.events & aio.OUT:
                var rest = pending.pop(fd)
                var w = aio.write(fd, Span(rest))
                if w >= 0 and w < len(rest):
                    pending[fd] = List[UInt8](rest[w:])
                    continue
                loop.modify(fd, aio.IN | aio.RDHUP, UInt64(fd))
                if w == -2:
                    aio.close(fd)
                continue
            var n = aio.read(fd, buf)
            if n == -1:
                continue
            if n <= 0:
                loop.remove(fd)
                aio.close(fd)
                _ = pending.pop(fd, List[UInt8]())
                continue
            n -= brk
            var w = aio.write(fd, Span(buf)[:n])
            if w == -2:
                loop.remove(fd)
                aio.close(fd)
            elif w < n:
                pending[fd] = List[UInt8](Span(buf)[max(w, 0):n])
                loop.modify(fd, aio.OUT, UInt64(fd))
