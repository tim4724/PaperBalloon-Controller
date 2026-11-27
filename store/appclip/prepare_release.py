# Readies the App Store release a version tag built, up to the point of submitting it:
# waits for the TestFlight build to process, sets up that version (renaming one still being
# prepared, as for a superseded tag, else creating it: its listing copies over from the live
# version), attaches the build, writes What's New, and gives the App Clip the version's own
# default experience. Submitting for review stays a separate, deliberate step.
#   python3 prepare_release.py <version> <build number>   (needs pyjwt, cryptography, requests)
# DRY_RUN=1 only reads, printing the writes it would make.
import sys, os, time, json; sys.path.insert(0, os.path.dirname(__file__))
from asc import *

version, build_number = sys.argv[1], sys.argv[2]
# What's New is Play's text (store/play/whatsnew), whose file names are the same locale
# codes; any other locale gets the English one.
WHATS_NEW = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'play', 'whatsnew', 'whatsnew-')
def whats_new(locale):
    path = WHATS_NEW + locale if os.path.exists(WHATS_NEW + locale) else WHATS_NEW + 'en-US'
    return open(path).read().strip()
EDITABLE = {'PREPARE_FOR_SUBMISSION', 'DEVELOPER_REJECTED', 'REJECTED', 'METADATA_REJECTED'}

def write(method, path, body):
    if os.environ.get('DRY_RUN'):
        print('would', method, path, json.dumps(body)[:300])
        return {'data': {'id': 'DRY_RUN'}}
    return call(method, path, body)

# Just uploaded, the build takes a while to process.
deadline = time.time() + 45 * 60
while True:
    builds = call('GET', f'/v1/builds?filter[app]={APP}&filter[version]={build_number}'
                         f'&filter[preReleaseVersion.version]={version}')['data']
    state = builds[0]['attributes']['processingState'] if builds else 'NOT_FOUND'
    print('build', version, build_number, state)
    if state == 'VALID': break
    if state in ('FAILED', 'INVALID') or time.time() > deadline: raise SystemExit(f'build not usable: {state}')
    time.sleep(60)
build = builds[0]['id']

versions = call('GET', f'/v1/apps/{APP}/appStoreVersions?filter[platform]=IOS&limit=50')['data']
editable = [v for v in versions if v['attributes']['appStoreState'] in EDITABLE]
if editable:
    vid = editable[0]['id']
    print('renaming', editable[0]['attributes']['versionString'], '->', version)
    write('PATCH', f'/v1/appStoreVersions/{vid}', {'data': {'type': 'appStoreVersions', 'id': vid,
                                                            'attributes': {'versionString': version}}})
else:
    print('creating', version)
    vid = write('POST', '/v1/appStoreVersions', {'data': {'type': 'appStoreVersions',
        'attributes': {'platform': 'IOS', 'versionString': version, 'releaseType': 'AFTER_APPROVAL'},
        'relationships': {'app': {'data': {'type': 'apps', 'id': APP}}}}})['data']['id']
write('PATCH', f'/v1/appStoreVersions/{vid}/relationships/build', {'data': {'type': 'builds', 'id': build}})

if vid != 'DRY_RUN':
    for loc in call('GET', f'/v1/appStoreVersions/{vid}/appStoreVersionLocalizations')['data']:
        text = whats_new(loc['attributes']['locale'])
        write('PATCH', f"/v1/appStoreVersionLocalizations/{loc['id']}", {'data': {
            'type': 'appStoreVersionLocalizations', 'id': loc['id'], 'attributes': {'whatsNew': text}}})

# Each version needs its own App Clip default experience; copy the newest version's
# (subtitle, card image and review invocation come with it).
experiences = call('GET', f'/v1/appClips/{CLIP}/appClipDefaultExperiences'
                          '?include=releaseWithAppStoreVersion&limit=50')['data']
of_version = {(e['relationships']['releaseWithAppStoreVersion'].get('data') or {}).get('id'): e['id']
              for e in experiences}
if vid in of_version:
    print('App Clip experience already set')
else:
    numbers = lambda s: tuple(int(p) for p in s.split('.'))
    newest = max((v for v in versions if v['id'] in of_version and v['id'] != vid),
                 key=lambda v: numbers(v['attributes']['versionString']), default=None)
    if newest is None: raise SystemExit('no App Clip default experience to copy')
    print('copying the App Clip experience of', newest['attributes']['versionString'])
    write('POST', '/v1/appClipDefaultExperiences', {'data': {'type': 'appClipDefaultExperiences',
        'relationships': {
            'appClip': {'data': {'type': 'appClips', 'id': CLIP}},
            'releaseWithAppStoreVersion': {'data': {'type': 'appStoreVersions', 'id': vid}},
            'appClipDefaultExperienceTemplate': {'data': {'type': 'appClipDefaultExperiences',
                                                          'id': of_version[newest['id']]}}}}})
print('ready to submit:', version, 'build', build_number)
