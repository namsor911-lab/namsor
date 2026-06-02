import pathlib

text = pathlib.Path('lib/main.dart').read_text(encoding='utf-8')
stack = []
state = 'code'
quote = None
i = 0
while i < len(text):
    ch = text[i]
    nxt = text[i + 1] if i + 1 < len(text) else ''
    if state == 'code':
        if ch == '/' and nxt == '/':
            state = 'linecomment'
            i += 2
            continue
        if ch == '/' and nxt == '*':
            state = 'blockcomment'
            i += 2
            continue
        if ch in ('"', "'", '`'):
            state = 'string'
            quote = ch
            i += 1
            continue
        if ch == '{':
            stack.append(i)
        elif ch == '}':
            if not stack:
                print('UNMATCHED CLOSE', i)
                break
            stack.pop()
    elif state == 'linecomment':
        if ch == '\n':
            state = 'code'
    elif state == 'blockcomment':
        if ch == '*' and nxt == '/':
            state = 'code'
            i += 2
            continue
    elif state == 'string':
        if ch == '\\':
            i += 2
            continue
        if ch == quote:
            state = 'code'
    i += 1
print('UNMATCHED OPEN', len(stack))
for pos in stack[-10:]:
    prefix = text[:pos].split('\n')
    print('line', len(prefix), 'col', len(prefix[-1]) + 1, repr(prefix[-1][-80:]))
