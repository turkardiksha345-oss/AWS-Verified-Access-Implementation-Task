from pathlib import Path
import json
p = Path('verifiedaccess_log.txt')
text = p.read_text(encoding='utf-16', errors='ignore')
entries = []
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
            entries.append(json.loads(cur))
        except json.JSONDecodeError:
            pass
        cur = ''

for i, obj in enumerate(entries, 1):
    if obj.get('status_detail') == 'Authorization Denied' or obj.get('status') == 'Failure':
        print('DENY OBJECT', i)
        def walk(o, prefix=''):
            if isinstance(o, dict):
                for k,v in o.items():
                    full = f'{prefix}.{k}' if prefix else k
                    print(full)
                    walk(v, full)
            elif isinstance(o, list):
                for idx, v in enumerate(o):
                    walk(v, f'{prefix}[{idx}]')
        walk(obj)
        break
