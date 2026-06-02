const fs = require('fs');
const text = fs.readFileSync('lib/main.dart', 'utf8');
const stack = [];
let state = 'code';
let quote = null;
let i = 0;
while (i < text.length) {
  const ch = text[i];
  const nxt = i + 1 < text.length ? text[i + 1] : '';
  if (state === 'code') {
    if (ch === '/' && nxt === '/') {
      state = 'linecomment';
      i += 2;
      continue;
    }
    if (ch === '/' && nxt === '*') {
      state = 'blockcomment';
      i += 2;
      continue;
    }
    if (ch === '"' || ch === "'" || ch === '`') {
      state = 'string';
      quote = ch;
      i += 1;
      continue;
    }
    if (ch === '{') stack.push(i);
    else if (ch === '}') {
      if (!stack.length) {
        console.log('UNMATCHED CLOSE', i);
        break;
      }
      stack.pop();
    }
  } else if (state === 'linecomment') {
    if (ch === '\n') state = 'code';
  } else if (state === 'blockcomment') {
    if (ch === '*' && nxt === '/') {
      state = 'code';
      i += 2;
      continue;
    }
  } else if (state === 'string') {
    if (ch === '\\') {
      i += 2;
      continue;
    }
    if (ch === quote) state = 'code';
  }
  i += 1;
}
console.log('UNMATCHED OPEN', stack.length);
for (const pos of stack.slice(-10)) {
  const before = text.slice(0, pos).split('\n');
  console.log('line', before.length, 'col', before[before.length - 1].length + 1, JSON.stringify(before[before.length - 1].slice(-80)));
}
