#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.10"
# dependencies = ["pillow"]
# ///
"""Capture the stores' app screenshots and write them into store/.

    uv run tools/store_screenshots.py                     # ios duo android, en and de
    uv run tools/store_screenshots.py duo --locales en    # one target, one language

Targets: ios = App Store 6.5" (an iPhone 14 Plus simulator), duo = App Store iPhone Duo,
android = Play phone (the ci_api35 AVD, 1080×1920). Each shot is the app's own screen,
taken by the listing UI tests (ListingScreenshotTests.swift, ListingScreenshotTest.kt) with
fake_room.py standing in for a TV nearby. The explainers (03, 04 in the phone sets) are
artwork, not captures, and stay as they are. Review the result with `git diff` before
uploading.

The Duo needs you: only DeviceHub's pose buttons fold and unfold its simulator, so the
script says when to press Open or Closed and waits.
"""
import argparse, json, os, re, shutil, socket, subprocess, sys, tempfile, time
from pathlib import Path
from urllib.parse import quote
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
ROOM_LABEL = {'en': 'Living Room', 'de': 'Wohnzimmer'}
OUT = {
    ('ios', 'en'): 'store/appstore/screenshots-6.5', ('ios', 'de'): 'store/appstore/de/screenshots-6.5',
    ('duo', 'en'): 'store/appstore/screenshots-duo', ('duo', 'de'): 'store/appstore/de/screenshots-duo',
    ('android', 'en'): 'store/play/screenshots', ('android', 'de'): 'store/play/de/screenshots',
}
FILE = {
    'ios': {'home-nearby': '01-home-nearby', 'game-page': '02-game-page', 'tiny-track': '05-tiny-track'},
    'duo': {'home-nearby': '01-home-nearby', 'game-page': '02-game-page', 'tiny-track': '03-tiny-track',
            'cover-home': '04-cover-home'},
    'android': {'home-nearby': '01-home-nearby', 'game-page': '02-game-page', 'tiny-track': '05-tiny-track'},
}
# The stores take these sizes exactly (portrait, or the same turned).
SIZE = {'ios': (1284, 2778), 'duo': (2853, 2007), 'duo-cover': (1398, 2034), 'android': (1080, 1920)}
WORK = Path(tempfile.mkdtemp(prefix='store-screenshots-'))


def run(*cmd, **kw):
    return subprocess.run(cmd, check=True, text=True, capture_output=True, **kw).stdout


def write(target, locale, shot, png):
    """Flattens [png] (the stores refuse alpha), checks its size, and writes it into store/."""
    image = Image.open(png).convert('RGB')
    want = SIZE['duo-cover' if shot == 'cover-home' else target]
    if image.size not in (want, want[::-1]):
        sys.exit(f'{target} {shot}: {image.size[0]}×{image.size[1]}, the store wants {want[0]}×{want[1]}')
    path = ROOT / OUT[target, locale] / (FILE[target][shot] + '.png')
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, optimize=True)
    print(f'  {path.relative_to(ROOT)}')


def copy_shot(target, shot, source, locale):
    """Tiny Track's pages are English whatever the app's language: one capture serves all."""
    name = FILE[target][shot] + '.png'
    path = ROOT / OUT[target, locale] / name
    path.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(ROOT / OUT[target, source] / name, path)
    print(f'  {path.relative_to(ROOT)} (as {source})')


class NearbyRoom:
    """fake_room.py: a real relay room, advertised over the Mac's DNS-SD, while up."""

    def __init__(self, label):
        self.label, self.proc, self.code = label, None, None

    def up(self):
        if self.proc: return self.code
        self.proc = subprocess.Popen(['uv', 'run', '--quiet', str(ROOT / 'tools/fake_room.py'), self.label],
                                     stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True)
        line = self.proc.stdout.readline()
        match = re.search(r'room (\w+)\.', line)
        if not match:
            self.proc.kill()
            sys.exit(f'fake_room.py: {line.strip() or "no room"}')
        self.code = match.group(1)
        return self.code

    def down(self):
        if not self.proc: return
        self.proc.stdin.write('\n')
        self.proc.stdin.close()
        self.proc.wait(timeout=15)
        self.proc = None


# ---- iOS ---------------------------------------------------------------------------

def simulator(name, device_type):
    """A booted simulator of [device_type] named [name], created on the newest runtime
    that has it, with an en_US region (a de_DE Mac otherwise shows "09:41")."""
    devices = json.loads(run('xcrun', 'simctl', 'list', 'devices', 'available', '-j'))['devices']
    udid = next((d['udid'] for ds in devices.values() for d in ds if d['name'] == name), None)
    if not udid:
        runtimes = json.loads(run('xcrun', 'simctl', 'list', 'runtimes', '-j'))['runtimes']
        runtime = max((r for r in runtimes if r['isAvailable'] and r['platform'] == 'iOS'
                       and any(t['identifier'] == device_type for t in r.get('supportedDeviceTypes', []))),
                      key=lambda r: [int(p) for p in r['version'].split('.')])
        udid = run('xcrun', 'simctl', 'create', name, device_type, runtime['identifier']).strip()
        run('xcrun', 'simctl', 'boot', udid)
        run('xcrun', 'simctl', 'bootstatus', udid, '-b')
        spawn = ('xcrun', 'simctl', 'spawn', udid, 'defaults', 'write')
        run(*spawn, '-g', 'AppleLocale', 'en_US')
        run(*spawn, '-g', 'AppleLanguages', '-array', 'en')
        # First-use keyboard tutorials would cover the screen.
        for key in ('DidShowContinuousPathIntroduction', 'KeyboardDidShowProductivityTutorial',
                    'DidShowGestureKeyboardIntroduction'):
            run(*spawn, 'com.apple.keyboard.preferences', key, '-bool', 'true')
        run('xcrun', 'simctl', 'shutdown', udid)
    if f'{udid}) (Booted)' not in run('xcrun', 'simctl', 'list', 'devices'):
        subprocess.run(['xcrun', 'simctl', 'boot', udid], capture_output=True)
        run('xcrun', 'simctl', 'bootstatus', udid, '-b')
    run('xcrun', 'simctl', 'status_bar', udid, 'override', '--time', '9:41', '--batteryState', 'charged',
        '--batteryLevel', '100', '--cellularMode', 'active', '--cellularBars', '4', '--operatorName', ' ',
        '--wifiBars', '3')
    return udid


def build_ios():
    """Builds the app and its UI tests once for every simulator; returns the .xctestrun."""
    print('Building the iOS app and UI tests…')
    run('xcodegen', 'generate', '--quiet', cwd=ROOT / 'ios')
    derived = Path.home() / 'Library/Caches/paperballoon-store-screenshots'
    log = WORK / 'build.log'
    with open(log, 'w') as f:
        result = subprocess.run(['xcodebuild', 'build-for-testing', '-project', 'PaperBalloon.xcodeproj',
                                 '-scheme', 'PaperBalloon', '-destination', 'generic/platform=iOS Simulator',
                                 '-derivedDataPath', str(derived), 'CODE_SIGNING_ALLOWED=NO'],
                                cwd=ROOT / 'ios', stdout=f, stderr=subprocess.STDOUT)
    if result.returncode:
        sys.exit(f'iOS build failed, see {log}')
    return next((derived / 'Build/Products').glob('*.xctestrun'))


def ios_tests(xctestrun, udid, tests, env, display=None):
    """Runs ListingScreenshotTests [tests] on [udid], capturing the screen for each marker
    the test drops; returns {shot name: png}."""
    markers = Path(tempfile.mkdtemp(dir=WORK))
    log = WORK / f'test-{len(list(WORK.glob("test-*")))}.log'
    test_env = {**os.environ, **{'TEST_RUNNER_' + k: v for k, v in {**env, 'SNAP_DIR': str(markers)}.items()}}
    cmd = ['xcodebuild', 'test-without-building', '-xctestrun', str(xctestrun), '-destination', f'id={udid}']
    cmd += [f'-only-testing:PaperBalloonUITests/ListingScreenshotTests/{t}' for t in tests]
    shots = {}
    with open(log, 'w') as f:
        proc = subprocess.Popen(cmd, env=test_env, stdout=f, stderr=subprocess.STDOUT)
        while proc.poll() is None:
            for marker in markers.iterdir():
                png = WORK / f'{udid}-{marker.name}-{time.monotonic_ns()}.png'
                run('xcrun', 'simctl', 'io', udid, 'screenshot', *([f'--display={display}'] if display else []), str(png))
                shots[marker.name] = png
                marker.unlink()
            time.sleep(0.2)
    if proc.returncode:
        sys.exit(f'iOS UI tests failed, see {log}')
    return shots


def capture_ios(xctestrun, locales, room_for):
    udid = simulator('PB Store 6.5', 'com.apple.CoreSimulator.SimDeviceType.iPhone-14-Plus')
    for i, locale in enumerate(locales):
        print(f'iOS 6.5", {locale}')
        room = room_for(locale)
        room.up()
        shots = ios_tests(xctestrun, udid, ['testHomeNearby'], {'LISTING_LOCALE': locale, 'LISTING_ROOM': room.label})
        room.down()  # home behind the game sheet shows "Searching…", not the room
        shots |= ios_tests(xctestrun, udid, ['testGamePage'] + (['testTinyTrack'] if i == 0 else []),
                           {'LISTING_LOCALE': locale, 'LISTING_ROOM': room.label})
        for shot, png in shots.items():
            write('ios', locale, shot, png)
        if i: copy_shot('ios', 'tiny-track', locales[0], locale)


def lit(udid, display):
    png = WORK / 'pose.png'
    run('xcrun', 'simctl', 'io', udid, 'screenshot', f'--display={display}', str(png))
    return Image.open(png).convert('L').getextrema()[1] >= 16


def duo_pose(udid):
    """Which screen is on: 'open' (the inner one), 'folded' (the cover), or None between
    the two, as while it boots. Not which way it's turned: a screenshot comes out the way
    the front app is, and the test runner left in front is portrait-only."""
    cover, inner = lit(udid, 'primary'), lit(udid, 'primary-1')
    return 'open' if inner and not cover else 'folded' if cover and not inner else None


def settled_pose(udid):
    for _ in range(60):
        if pose := duo_pose(udid): return pose
        time.sleep(1)
    sys.exit('the Duo never settled on a screen')


def wait_for_pose(udid, pose):
    if duo_pose(udid) == pose: return
    button = 'Open (held as a book: wider than tall)' if pose == 'open' else 'Closed'
    print(f'  In DeviceHub, show "PB Store Duo" and press {button}. Waiting…', flush=True)
    deadline = time.monotonic() + 600
    while duo_pose(udid) != pose:
        if time.monotonic() > deadline: sys.exit('gave up waiting for the Duo')
        time.sleep(2)
    time.sleep(3)  # the screens settle


def capture_duo(xctestrun, locales, room_for):
    udid = simulator('PB Store Duo', 'com.apple.CoreSimulator.SimDeviceType.iPhone-Duo')
    for i, locale in enumerate(locales):
        print(f'iPhone Duo, {locale}')
        room = room_for(locale)
        env = {'LISTING_LOCALE': locale, 'LISTING_ROOM': room.label}
        inner = ['testGamePage'] + (['testTinyTrack'] if i == 0 else [])

        def cover():
            wait_for_pose(udid, 'folded')
            room.up()
            return {'cover-home': ios_tests(xctestrun, udid, ['testHomeNearby'], {**env, 'DUO_POSE': 'folded'},
                                            'primary')['home-nearby']}

        def open_():
            wait_for_pose(udid, 'open')
            room.up()
            shots = ios_tests(xctestrun, udid, ['testHomeNearby'], {**env, 'DUO_POSE': 'open'}, 'primary-1')
            room.down()
            return shots | ios_tests(xctestrun, udid, inner, {**env, 'DUO_POSE': 'open'}, 'primary-1')

        # Whichever pose it's in first, so one press covers both.
        shots = open_() | cover() if settled_pose(udid) == 'open' else cover() | open_()
        room.down()
        for shot, png in shots.items():
            write('duo', locale, shot, png)
        if i: copy_shot('duo', 'tiny-track', locales[0], locale)


# ---- Android -----------------------------------------------------------------------

def sdk():
    props = (ROOT / 'android/local.properties').read_text()
    return Path(re.search(r'^sdk\.dir=(.+)$', props, re.M).group(1).strip())


def free_emulator_port():
    """An even console port whose adb port (+1) is free too: other agents run emulators."""
    for port in range(5600, 5700, 2):
        try:
            for p in (port, port + 1):
                with socket.socket() as s: s.bind(('127.0.0.1', p))
            return port
        except OSError:
            continue
    sys.exit('no free emulator port')


def capture_android(locales, room_for):
    port = free_emulator_port()
    serial = f'emulator-{port}'
    adb = [str(sdk() / 'platform-tools/adb'), '-s', serial]
    print(f'Android: booting ci_api35 as {serial}')
    emulator = subprocess.Popen([str(sdk() / 'emulator/emulator'), '-avd', 'ci_api35', '-port', str(port), '-read-only',
                                 '-no-window', '-no-audio', '-no-boot-anim', '-no-snapshot'],
                                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    try:
        run(*adb, 'wait-for-device')
        while run(*adb, 'shell', 'getprop', 'sys.boot_completed').strip() != '1':
            time.sleep(2)
        run(*adb, 'shell', 'settings', 'put', 'global', 'hide_error_dialogs', '1')
        run(*adb, 'shell', 'am', 'broadcast', '-a', 'android.intent.action.CLOSE_SYSTEM_DIALOGS')
        for i, locale in enumerate(locales):
            print(f'Android, {locale}')
            room = room_for(locale)
            pictures = '/sdcard/Pictures/paperballoon-listing'
            run(*adb, 'shell', 'rm', '-rf', pictures)
            shots = ['game-page'] + (['tiny-track'] if i == 0 else []) + ['home-nearby']
            arg = '-Pandroid.testInstrumentationRunnerArguments.'
            log = WORK / f'android-{locale}.log'
            with open(log, 'w') as f:
                result = subprocess.run(['./gradlew', ':app:connectedDebugAndroidTest',
                                         arg + 'class=games.paperballoon.controller.ListingScreenshotTest',
                                         arg + 'listingShots=' + ','.join(shots), arg + 'listingLocale=' + locale,
                                         arg + 'listingRoomCode=' + room.up(),
                                         arg + 'listingRoomLabel=' + quote(room.label)],
                                        cwd=ROOT / 'android', env={**os.environ, 'ANDROID_SERIAL': serial},
                                        stdout=f, stderr=subprocess.STDOUT)
            room.down()
            if result.returncode:
                sys.exit(f'Android UI test failed, see {log}')
            pulled = WORK / f'android-{locale}'
            run(*adb, 'pull', pictures, str(pulled))
            for png in sorted(pulled.rglob('*.png')):
                write('android', locale, png.stem, png)
            if i: copy_shot('android', 'tiny-track', locales[0], locale)
    finally:
        subprocess.run([*adb, 'emu', 'kill'], capture_output=True)
        emulator.wait(timeout=60)


def main():
    sys.stdout.reconfigure(line_buffering=True)  # progress shows when piped, too
    parser =argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('targets', nargs='*', choices=['ios', 'duo', 'android'], help='default: all three')
    parser.add_argument('--locales', default='en,de', help='comma-separated, first one first (default: en,de)')
    args = parser.parse_args()
    targets = args.targets or ['ios', 'duo', 'android']
    locales = args.locales.split(',')
    rooms = {locale: NearbyRoom(ROOM_LABEL[locale]) for locale in locales}
    try:
        if {'ios', 'duo'} & set(targets):
            xctestrun = build_ios()
            if 'ios' in targets: capture_ios(xctestrun, locales, rooms.get)
            if 'duo' in targets: capture_duo(xctestrun, locales, rooms.get)
        if 'android' in targets: capture_android(locales, rooms.get)
    finally:
        for room in rooms.values(): room.down()
    shutil.rmtree(WORK, ignore_errors=True)
    print('Done. Review with git diff before uploading.')


if __name__ == '__main__':
    main()
