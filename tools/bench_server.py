"""Reference echo servers for the bench: `bench_server.py asyncio|uvloop` prints its port."""
import asyncio, sys

class Echo(asyncio.Protocol):
    def connection_made(self, t): self.t = t
    def data_received(self, d): self.t.write(d)

async def main():
    srv = await asyncio.get_running_loop().create_server(Echo, "127.0.0.1", 0, backlog=4096)
    print(srv.sockets[0].getsockname()[1], flush=True)
    await srv.serve_forever()

if sys.argv[1] == "uvloop":
    import uvloop; uvloop.run(main())
else:
    asyncio.run(main())
