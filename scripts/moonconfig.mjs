#!/usr/bin/env node
import { readFile } from 'node:fs/promises';
const usage = `MoonConfig — structured configuration changes
Usage:
  node scripts/moonconfig.mjs diff OLD.json NEW.json
  node scripts/moonconfig.mjs apply DOCUMENT.json PATCH.json
  node scripts/moonconfig.mjs merge BASE.json OURS.json THEIRS.json
  node scripts/moonconfig.mjs get DOCUMENT.json POINTER
Exit codes: 0 success, 1 invalid input/I/O, 2 unresolved merge conflicts.
Run npm run build first. Output goes to stdout; errors go to stderr.`;
const [command, ...args] = process.argv.slice(2);
if (!command || command === '--help' || command === '-h') { console.log(usage); process.exit(0); }
try {
  const {run_json, result_json} = await import('../demo/engine.js');
  let fields;
  const source = async path => {
    const text = await readFile(path, 'utf8');
    if (text.length > 4000000) throw new Error(`Input exceeds limit: ${path}`);
    return text.replace(/^\uFEFF/, '');
  };
  if (command === 'diff' && args.length === 2) fields = `"old":${await source(args[0])},"new":${await source(args[1])}`;
  else if (command === 'apply' && args.length === 2) fields = `"document":${await source(args[0])},"patch":${await source(args[1])}`;
  else if (command === 'merge' && args.length === 3) fields = `"base":${await source(args[0])},"ours":${await source(args[1])},"theirs":${await source(args[2])}`;
  else if (command === 'get' && args.length === 2) fields = `"document":${await source(args[0])},"path":${JSON.stringify(args[1])}`;
  else throw new Error(usage);
  // Raw JSON crosses the boundary. Never parse/re-stringify user numbers in JS.
  const response = run_json(`{"command":${JSON.stringify(command)},${fields}}`);
  const metadata = JSON.parse(response);
  if (!metadata.ok) { console.error(metadata.error); process.exitCode = 1; }
  else {
    console.log(result_json(response));
    if (command === 'merge' && !metadata.result.clean) process.exitCode = 2;
  }
} catch (error) {
  console.error(error.code === 'ERR_MODULE_NOT_FOUND' ? 'Missing engine. Run npm run build first.' : error.message);
  process.exitCode = 1;
}
