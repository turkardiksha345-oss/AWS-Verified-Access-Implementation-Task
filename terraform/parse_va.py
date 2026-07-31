import json
from pathlib import Path
p = Path('va_deny.json')
data = json.loads(p.read_text())
for i, msg in enumerate(data, 1):
    try:
        payload = json.loads(msg)
    except Exception as e:
        print('PARSEERR', e)
        continue
    print('EVENT', i)
    print(' status_detail=', payload.get('status_detail'))
    print(' activity=', payload.get('activity_name'))
    print(' actor=', payload.get('actor'))
    req = payload.get('http_request', {}).get('url', {})
    print(' request=', req.get('text'))
    print('---')
