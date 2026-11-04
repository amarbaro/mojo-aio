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
