import aio


def main() raises:
    var loop = aio.Loop()
    loop.after(10, 2)  # one TIMER event in 10 ms
    var evs = List[aio.Event]()
    _ = loop.wait(evs)
    print("timer", evs[0].token, "fired")
