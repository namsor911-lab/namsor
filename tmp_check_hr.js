const fs = require('fs');
const html = fs.readFileSync('lib/hr.html', 'utf8');
const m = html.match(/function calcTax\(before\)\{([\s\S]*?)\n\}/);
if (!m) { console.error('not found'); process.exit(1); }
const code = m[1];
const calcTax = new Function('before', code + '\n return {exempt, b5, b10, b15, b20, b25, tax};');
[1300000, 5000000, 15000000, 25000000, 65000000].forEach(v => console.log(v, JSON.stringify(calcTax(v))));
