"""Ping-pong load: C connections x R round trips of S bytes, uvloop client. Prints req/s."""
import asyncio, sys, time, uvloop

async def one(port, rounds, size):
    r, w = await asyncio.open_connection("127.0.0.1", port)
    msg = b"x" * size
    for _ in range(rounds):
        w.write(msg); await r.readexactly(size)
    w.close()

async def main(port, c, rounds, size):
    t = time.perf_counter()
    await asyncio.gather(*(one(port, rounds, size) for _ in range(c)))
    print(f"{c * rounds / (time.perf_counter() - t):.0f}")

uvloop.run(main(*map(int, sys.argv[1:5])))
