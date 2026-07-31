from pathlib import Path
import json
import re

raw = Path('terraform/verifiedaccess_log.txt').read_bytes()
text = raw.decode('utf-16-le', errors='ignore')
objs = []
cur = ''
brace = 0
in_str = False
esc = False
for ch in text:
    if not cur and ch.isspace():
        continue
    cur += ch
    if ch == '\\' and not esc:
        esc = True
        continue
    if ch == '"' and not esc:
        in_str = not in_str
    if esc:
        esc = False
        continue
    if not in_str:
        if ch == '{':
            brace += 1
        elif ch == '}':
            brace -= 1
    if brace == 0 and cur.strip():
        try:
            objs.append(json.loads(cur))
        except Exception as e:
            pass
        cur = ''
        in_str = False
        esc = False

print('parsed', len(objs), 'objects')
for i, obj in enumerate(objs[:20], 1):
    if obj.get('activity_name') == 'Access Deny':
        print('\n--- Access Deny event', i, '---')
        print(json.dumps(obj, indent=2)[:12000])
        if i >= 5:
            break

for key in ['actor', 'principal', 'context', 'user', 'email_addr', 'email', 'uid', 'group', 'actor.user', 'principal.user', 'context.identity']:
    print('SEARCH', key)
    count = 0
    for obj in objs:
        s = json.dumps(obj)
        if key in s:
            count += 1
    print(' count', count)
