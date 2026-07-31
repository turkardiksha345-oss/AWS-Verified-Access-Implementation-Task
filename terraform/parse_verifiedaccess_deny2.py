from pathlib import Path
import json
path = Path('verifiedaccess_log.txt')
text = path.read_text(encoding='utf-16', errors='ignore')
objects = []
cur = ''
depth = 0
in_str = False
esc = False
for ch in text:
    cur += ch
    if esc:
        esc = False
        continue
    if ch == '\\':
        esc = True
        continue
    if ch == '"':
        in_str = not in_str
        continue
    if in_str:
        continue
    if ch == '{':
        depth += 1
    elif ch == '}':
        depth -= 1
    if depth == 0 and cur.strip():
        try:
            obj = json.loads(cur)
            objects.append(obj)
        except Exception:
            pass
        cur = ''
print('PARSED', len(objects), 'objects')
for i, obj in enumerate(objects[:10], 1):
    print('--- OBJ', i, '---')
    print('KEYS', list(obj.keys()))
    if 'status_detail' in obj:
        print('STATUS_DETAIL', obj['status_detail'])
    if 'user' in obj:
        print('USER', obj['user'])
    if 'authorizations' in obj:
        print('AUTHZ', obj['authorizations'])
    if 'actor' in obj:
        print('ACTOR', obj['actor'])
    print()
