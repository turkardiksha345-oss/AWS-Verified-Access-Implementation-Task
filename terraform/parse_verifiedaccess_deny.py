from pathlib import Path
import json
p = Path('verifiedaccess_deny.txt')
text = p.read_text(encoding='utf-16')
lines = text.splitlines()
entries = []
cur = None
brace = 0
in_str = False
esc = False
for line in lines:
    if cur is None and not line.strip():
        continue
    if cur is None and line.lstrip().startswith('{'):
        cur = line
    elif cur is not None:
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
    if cur is not None and brace == 0:
        try:
            entries.append(json.loads(cur))
        except Exception as e:
            print('PARSE ERROR', e)
            print(cur[:1000])
            break
        cur = None
        brace = 0
        in_str = False
        esc = False
print('PARSED', len(entries))
for i, entry in enumerate(entries[:3], 1):
    print('--- ENTRY', i, '---')
    print(json.dumps(entry, indent=2)[:9000])
