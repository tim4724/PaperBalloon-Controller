# Run once the App Clip is approved (ASC rejects advanced experiences before that):
#   python3 add_advanced_experiences.py   (needs pyjwt, cryptography, requests)
import sys, os, re; sys.path.insert(0, os.path.dirname(__file__))
from asc import *
D = os.path.dirname(os.path.abspath(__file__)) + '/'
SUB = 'Your phone is the controller'
for link, title, f in [('https://hexstacker.com', 'HexStacker', 'hexstacker-appclip-3000x2000.png'),
                       ('https://tinytrack.paperballoon.games', 'Tiny Track', 'tinytrack-appclip-3000x2000.jpg'),
                       ('https://paperballoon.games', 'Paper Balloon', 'paperballoon-appclip-3000x2000.jpg')]:
    try:
        try: iid = upload('appClipAdvancedExperienceImages', D + f)['id']
        except AssertionError as ex:  # identical bytes were uploaded before
            iid = re.search(r'already exists with id - ([0-9a-f-]{36})', str(ex)).group(1)
        e = call('POST', '/v1/appClipAdvancedExperiences', {'data': {'type': 'appClipAdvancedExperiences',
            'attributes': {'link': link, 'action': 'OPEN', 'defaultLanguage': 'EN', 'isPoweredBy': False},
            'relationships': {'appClip': {'data': {'type': 'appClips', 'id': CLIP}},
                              'headerImage': {'data': {'type': 'appClipAdvancedExperienceImages', 'id': iid}},
                              'localizations': {'data': [{'type': 'appClipAdvancedExperienceLocalizations', 'id': '${loc}'}]}}},
            'included': [{'type': 'appClipAdvancedExperienceLocalizations', 'id': '${loc}',
                          'attributes': {'language': 'EN', 'title': title, 'subtitle': SUB}}]})['data']
        print(title, e['id'], e['attributes'].get('status'))
    except SystemExit:  # call() already printed the API error; try the next link
        print(title, 'FAILED', file=sys.stderr)
