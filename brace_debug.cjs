const fs = require('fs');
const text = fs.readFileSync('lib/main.dart', 'utf8');
let state = 'code';
let quote = null;
let brace = 0;
let line = 1;
for (let i = 0; i < text.length; i++) {
  const ch = text[i];
  const nxt = i + 1 < text.length ? text[i + 1] : '';
  if (ch === '\n') line++;
  if (state === 'code') {
    if (ch === '/' && nxt === '/') {
      state = 'linecomment';
      i++;
      continue;
    }
    if (ch === '/' && nxt === '*') {
      state = 'blockcomment';
      i++;
      continue;
    }
    if (ch === '"' || ch === "'" || ch === '`') {
      state = 'string';
      quote = ch;
      continue;
    }
    if (ch === '{') brace++;
    else if (ch === '}') brace--;
  } else if (state === 'linecomment') {
    if (ch === '\n') state = 'code';
  } else if (state === 'blockcomment') {
    if (ch === '*' && nxt === '/') {
      state = 'code';
      i++;
      continue;
    }
  } else if (state === 'string') {
    if (ch === '\\') {
      i++;
      continue;
    }
    if (ch === quote) state = 'code';
  }
  if (line >= 2496 && line <= 3392 && (ch === '{' || ch === '}')) {
    console.log('line', line, 'ch', ch, 'state', state, 'brace', brace);
  }
}
console.log('final', brace, state);
