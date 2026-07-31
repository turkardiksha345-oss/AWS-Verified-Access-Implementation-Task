from pathlib import Path
import json
p = Path('verifiedaccess_deny.txt')
text = p.read_text(encoding='utf-8')
lines = text.splitlines()
objs = []
cur = ''
brace = 0
in_str = False
esc = False
for line in lines:
    if not cur and not line.strip():
        continue
    if not cur and line.lstrip().startswith('{'):
        cur = line
    elif cur:
        cur += line
    else:
        continue
    for ch in line:
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
            brace += 1
        elif ch == '}':
            brace -= 1
    if cur and brace == 0:
        try:
            objs.append(json.loads(cur))
        except Exception as e:
            print('PARSE ERROR', e)
            print(cur[:1000])
            break
        cur = ''
        in_str = False
        esc = False
print('PARSED', len(objs))
for i, o in enumerate(objs[:2], 1):
    print('--- OBJ', i, '---')
    print(json.dumps(o, indent=2)[:12000])
