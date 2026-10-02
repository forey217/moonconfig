#!/usr/bin/env node
import { readFile } from 'node:fs/promises';
const usage = `MoonConfig — structured configuration changes
Usage:
  node scripts/moonconfig.mjs diff OLD.json NEW.json
  node scripts/moonconfig.mjs apply DOCUMENT.json PATCH.json
  node scripts/moonconfig.mjs merge BASE.json OURS.json THEIRS.json
  node scripts/moonconfig.mjs resolve BASE.json OURS.json THEIRS.json DECISIONS.json [--output report|value|patch]
  node scripts/moonconfig.mjs get DOCUMENT.json POINTER
Exit codes: 0 success, 1 invalid input/I/O, 2 unresolved merge conflicts.
Run npm run build first. Output goes to stdout; errors go to stderr.`;
const [command, ...args] = process.argv.slice(2);
if (!command || command === '--help' || command === '-h') { console.log(usage); process.exit(0); }
try {
  const {run_json, result_json, result_field_json} = await import('../demo/engine.js');
  let projection = 'report';
  const flag = args.indexOf('--output');
  if (flag !== -1) {
    if (command !== 'resolve' || flag !== args.length - 2 || !['report','value','patch'].includes(args[flag + 1])) throw new Error(usage);
    projection = args[flag + 1]; args.splice(flag, 2);
  }
  let fields;
  const source = async path => {
    const text = await readFile(path, 'utf8');
    if (text.length > 4000000) throw new Error(`Input exceeds limit: ${path}`);
    return text.replace(/^\uFEFF/, '');
  };
  if (command === 'diff' && args.length === 2) fields = {old_text:await source(args[0]),new_text:await source(args[1])};
  else if (command === 'apply' && args.length === 2) fields = {document_text:await source(args[0]),patch_text:await source(args[1])};
  else if (command === 'merge' && args.length === 3) fields = {base_text:await source(args[0]),ours_text:await source(args[1]),theirs_text:await source(args[2])};
  else if (command === 'resolve' && args.length === 4) fields = {base_text:await source(args[0]),ours_text:await source(args[1]),theirs_text:await source(args[2]),decisions_text:await source(args[3])};
  else if (command === 'get' && args.length === 2) fields = {document_text:await source(args[0]),path:args[1]};
  else throw new Error(usage);
  // Raw JSON crosses the boundary. Never parse/re-stringify user numbers in JS.
  const response = run_json(JSON.stringify({command,...fields}));
  const metadata = JSON.parse(response);
  if (!metadata.ok) { console.error(metadata.error); process.exitCode = 1; }
  else {
    console.log(projection === 'report' ? result_json(response) : result_field_json(response, projection));
    if (command === 'merge' && !metadata.result.clean) process.exitCode = 2;
  }
} catch (error) {
  console.error(error.code === 'ERR_MODULE_NOT_FOUND' ? 'Missing engine. Run npm run build first.' : error.message);
  process.exitCode = 1;
}
