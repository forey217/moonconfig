#!/usr/bin/env node
import { readFile, open, link, unlink } from 'node:fs/promises';
import { randomUUID } from 'node:crypto';
import { dirname, join, resolve } from 'node:path';
const usage = `MoonConfig — structured configuration changes
Usage:
  node scripts/moonconfig.mjs diff OLD.json NEW.json
  node scripts/moonconfig.mjs apply DOCUMENT.json PATCH.json
  node scripts/moonconfig.mjs merge BASE.json OURS.json THEIRS.json
  node scripts/moonconfig.mjs resolve BASE.json OURS.json THEIRS.json DECISIONS.json [--output report|value|patch]
  node scripts/moonconfig.mjs get DOCUMENT.json POINTER
Options:
  --save FILE.json   Save UTF-8 JSON atomically; refuse to overwrite any existing file.
  --                Treat remaining arguments as literal file names or pointers.
Exit codes: 0 success, 1 invalid input/I/O, 2 unresolved merge conflicts.
Run npm run build first. Output goes to stdout unless --save is used; errors go to stderr.
Saving a merge preview still returns 2 when conflicts remain.`;
const [command, ...args] = process.argv.slice(2);
if (!command || command === '--help' || command === '-h') { console.log(usage); process.exit(0); }
async function saveResult(path, text) {
  const destination = resolve(path);
  const temporary = join(dirname(destination), `.moonconfig-${randomUUID()}.tmp`);
  const handle = await open(temporary, 'wx', 0o600);
  let closed = false;
  try {
    await handle.writeFile(text + '\n', 'utf8');
    await handle.sync();
    await handle.close();
    closed = true;
    // Link creation is atomic and refuses existing paths, including inputs,
    // symlinks and output paths concurrently created by another process.
    await link(temporary, destination);
  } catch (error) {
    if (error.code === 'EEXIST') throw new Error(`Refusing to overwrite existing output: ${path}`);
    throw error;
  } finally {
    if (!closed) await handle.close().catch(() => {});
    await unlink(temporary).catch(() => {});
  }
}
try {
  let projection = 'report';
  let savePath, outputSeen = false;
  const positional = [];
  for (let i = 0; i < args.length; i++) {
    const arg = args[i];
    if (arg === '--') { positional.push(...args.slice(i + 1)); break; }
    if (arg === '--output') {
      if (command !== 'resolve' || outputSeen || !['report','value','patch'].includes(args[i + 1])) throw new Error(usage);
      outputSeen = true; projection = args[++i];
    } else if (arg === '--save') {
      if (savePath !== undefined || !args[i + 1] || args[i + 1].startsWith('--')) throw new Error(usage);
      savePath = args[++i];
    } else {
      if (arg.startsWith('--')) throw new Error(usage);
      positional.push(arg);
    }
  }
  args.splice(0, args.length, ...positional);
  const {run_json, result_json, result_field_json} = await import('../demo/engine.js');
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
    const text = projection === 'report' ? result_json(response) : result_field_json(response, projection);
    if (savePath === undefined) console.log(text);
    else { await saveResult(savePath, text); console.error(`Saved ${savePath}`); }
    if (command === 'merge' && !metadata.result.clean) process.exitCode = 2;
  }
} catch (error) {
  console.error(error.code === 'ERR_MODULE_NOT_FOUND' ? 'Missing engine. Run npm run build first.' : error.message);
  process.exitCode = 1;
}
