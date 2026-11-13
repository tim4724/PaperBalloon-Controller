"""Minimal App Store Connect API client. Takes the key from the environment, under the names
the release workflow's secrets use: ASC_API_KEY_ID and ASC_API_ISSUER_ID, with the key file
at ~/.appstoreconnect/private_keys/AuthKey_<ASC_API_KEY_ID>.p8 (where altool looks too)."""
import jwt, time, json, sys, os, requests
KEY_ID=os.environ['ASC_API_KEY_ID']; ISSUER=os.environ['ASC_API_ISSUER_ID']
PK=open(os.path.expanduser(f'~/.appstoreconnect/private_keys/AuthKey_{KEY_ID}.p8')).read()
APP='6825072879'; CLIP='14177ea9-dbcb-4490-b36d-fb4cc2a4e337'
def token():
    now=int(time.time())
    return jwt.encode({'iss':ISSUER,'iat':now,'exp':now+1100,'aud':'appstoreconnect-v1'},PK,algorithm='ES256',headers={'kid':KEY_ID,'typ':'JWT'})
def call(method, path, body=None, ok=(200,201,204)):
    url=path if path.startswith('http') else 'https://api.appstoreconnect.apple.com'+path
    for attempt in range(6):
        r=requests.request(method,url,headers={'Authorization':'Bearer '+token(),'Content-Type':'application/json'},data=json.dumps(body) if body is not None else None, timeout=60)
        if r.status_code in ok or (r.status_code < 500 and r.status_code != 429): break
        time.sleep(30 if r.status_code == 429 else 5)
    if r.status_code not in ok:
        print(method,path,r.status_code,r.text[:3000],file=sys.stderr); raise SystemExit(1)
    return r.json() if r.text else {}

import hashlib, os
def upload(rtype, path, relationships=None):
    """Reserve an asset of `rtype`, PUT its bytes per the returned upload operations, commit."""
    data=open(path,'rb').read()
    body={'data':{'type':rtype,'attributes':{'fileName':os.path.basename(path),'fileSize':len(data)}}}
    if relationships: body['data']['relationships']=relationships
    res=call('POST',f'/v1/{rtype}',body)['data']
    for op in res['attributes']['uploadOperations']:
        h={x['name']:x['value'] for x in op.get('requestHeaders',[])}
        r=requests.request(op['method'],op['url'],headers=h,data=data[op['offset']:op['offset']+op['length']],timeout=120)
        assert r.status_code<300, (r.status_code,r.text[:300])
    res=call('PATCH',f"/v1/{rtype}/{res['id']}",{'data':{'type':rtype,'id':res['id'],'attributes':{'sourceFileChecksum':hashlib.md5(data).hexdigest(),'uploaded':True}}})['data']
    return res
