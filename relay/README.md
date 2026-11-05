# Mari0 AE UDP relay

The relay lets players join a host without router port forwarding. It forwards
game UDP packets between one host and one guest in each room. It does not host
the game simulation or require third-party Python packages.

## Run the relay

Use Python 3.10 or newer on a machine with a public IPv4 address:

```powershell
python relay\server.py --host 0.0.0.0 --port 27021
```

Allow inbound UDP traffic on port `27021` in the machine firewall and any
cloud firewall. Keep the process running while players use the service.

## Point game builds at the relay

Set `host` and `port` in `relayconfig.lua` to the relay's public hostname or
IPv4 address and UDP port. Build and distribute the same game build to both
players. The host creates a room and shares the displayed eight-character
code; the guest enters that code. Neither player needs to forward ports.

Rooms support one host and one guest. The relay forwards gameplay packets
without inspecting them, removes disconnected guests after 45 seconds, and
expires rooms after ten minutes without host traffic.

## Test

When the game uses the default local address (`127.0.0.1`), it starts the
relay automatically. Python 3.10 or newer must be installed. For a local
multiplayer test, launch the game twice as separate processes, create a room
in the first window, then enter its code in the second. Each game instance
gets its own ephemeral UDP port.

For testing on other devices, set the relay address in `relayconfig.lua` to
the relay machine's public hostname or IPv4 address before launching either
game instance, and run the relay separately on that machine. Remote relay
processes are not managed by the game and remain available after a game quits.

The local managed relay shuts down shortly after the last game exits normally.
If a game is force-terminated, the relay detects the missing heartbeat and
shuts down within about 13 seconds.

The relay protocol tests can be run with:

```powershell
python -m unittest discover -s relay -p "test_*.py"
```
