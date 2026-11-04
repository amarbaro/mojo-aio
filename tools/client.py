"""Gate client: N concurrent connections to the echo server, R rounds each of seeded random
payloads; every byte must come back. Prints 'conns N rounds R bytes B ok' (args: port n rounds [timeout s]) or exits 1."""
import asyncio, random, sys

async def one(port, i, rounds, sem):
    rng = random.Random(i)
    async with sem:
        r, w = await asyncio.open_connection("127.0.0.1", port)
    total = 0
    for _ in range(rounds):
        data = rng.randbytes(rng.choice([1, 7, 512, 4096, 70000]))
        w.write(data); await w.drain()
        got = await r.readexactly(len(data))
        if got != data:
            raise SystemExit(f"FAIL echo: conn {i} payload mismatch")
        total += len(data)
    w.close()
    return total

async def main(port, n, rounds, lim):
    sem = asyncio.Semaphore(512)  # connect pace; all n stay open together
    try:
        tot = await asyncio.wait_for(asyncio.gather(*(one(port, i, rounds, sem) for i in range(n))), lim)
    except (asyncio.IncompleteReadError, asyncio.TimeoutError, ConnectionError) as e:
        raise SystemExit(f"FAIL echo: {type(e).__name__}")
    print(f"conns {n} rounds {rounds} bytes {sum(tot)} ok")

asyncio.run(main(int(sys.argv[1]), int(sys.argv[2]), int(sys.argv[3]), float(sys.argv[4]) if len(sys.argv) > 4 else 50))
