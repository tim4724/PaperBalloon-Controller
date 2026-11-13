#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.10"
# dependencies = ["websockets", "certifi"]
# ///
"""Stand in for a HexStacker display on the LAN, so the launchers show a nearby room card.

    uv run tools/fake_room.py                      # "Living Room", Apple TV
    uv run tools/fake_room.py "Wohnzimmer" androidtv

Creates a real room on the HexStacker relay with the display's controller-URL template
(CONTRACT §6) — the launchers resolve an advertised code there and drop it otherwise —
then advertises its code over DNS-SD (§8) with macOS's dns-sd. Press Enter or Ctrl-C to
stop: the advertisement is withdrawn with a goodbye and the room is closed.
Joining from a phone loads the main-branch controller page, which waits for a display that
never sends anything.
"""
import asyncio, json, ssl, subprocess, sys, uuid
import certifi, websockets

RELAY = 'wss://ws.hexstacker.com'
# As the native displays send it, but pointing at the main-branch deployment.
TEMPLATE = 'https://main.hexstacker.com/{room}?pbp=%s#{instance}'

async def main(name, platform):
    # python.org builds ship without CA roots.
    async with websockets.connect(RELAY, ssl=ssl.create_default_context(cafile=certifi.where())) as ws:
        await ws.send(json.dumps({'type': 'create', 'clientId': 'fake-room-' + uuid.uuid4().hex,
                                  'maxClients': 9, 'url': TEMPLATE % platform}))
        while (msg := json.loads(await ws.recv()))['type'] != 'created':
            if msg['type'] == 'error':
                sys.exit(f'relay refused the room: {msg.get("message")}')
        code = msg['room']
        advert = subprocess.Popen(['dns-sd', '-R', name, '_paperballoon._tcp', 'local', '9', f'c={code}'],
                                  stdout=subprocess.DEVNULL)
        print(f'Advertising "{name}" ({platform}), room {code}. Press Enter to stop.', flush=True)
        # The relay pings; websockets answers while we wait, which keeps the room alive.
        stop = asyncio.get_running_loop().run_in_executor(None, sys.stdin.readline)
        try:
            await stop
        finally:
            advert.terminate()  # dns-sd sends the goodbye on SIGTERM
            advert.wait()
            await ws.send(json.dumps({'type': 'close_room'}))
            print('Stopped.', flush=True)

if __name__ == '__main__':
    args = sys.argv[1:]
    try:
        asyncio.run(main(args[0] if args else 'Living Room', args[1] if len(args) > 1 else 'tvos'))
    except KeyboardInterrupt:
        pass
