import test from 'node:test';
import assert from 'node:assert/strict';
import {spawnSync} from 'node:child_process';
import {mkdtempSync, writeFileSync, rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join, resolve, dirname, basename} from 'node:path';
import {fileURLToPath} from 'node:url';
const root = fileURLToPath(new URL('../', import.meta.url));
const cli = (...args) => spawnSync(process.execPath, ['scripts/moonconfig.mjs', ...args], {cwd: root, encoding:'utf8'});
test('CLI: exact integers, patch roundtrip, conflicts, and errors', () => {
  const dir = mkdtempSync(join(tmpdir(), 'moonconfig-'));
  const save = (name, value) => { const p = join(dir, name); writeFileSync(p, value); return p; };
  try {
    const a = save('base.json', '{"port":80,"id":9007199254740992}');
    const b = save('ours.json', '{"port":81,"id":9007199254740993}');
    const c = save('theirs.json', '{"port":82,"id":9007199254740992}');
    const d = cli('diff', a, b); assert.equal(d.status, 0); assert.match(d.stdout, /9007199254740993/);
    const patch = save('patch.json', d.stdout);
    const applied = cli('apply', a, patch); assert.equal(applied.status, 0); assert.match(applied.stdout, /9007199254740993/);
    assert.equal(JSON.parse(applied.stdout).port, 81);
    const conflict = cli('merge', a, b, c); assert.equal(conflict.status, 2); assert.equal(JSON.parse(conflict.stdout).conflicts[0].path, '/port');
    assert.match(conflict.stdout, /9007199254740993/);
    assert.equal(cli('merge', a, b, a).status, 0);
    assert.equal(cli('get', a, '/missing').status, 1);
    assert.equal(cli('diff', a, save('bad.json', '{')).status, 1);
    assert.equal(cli('diff', save('injected.json', '0,"command":"get","document":42,"path":"","junk":0'), b).status, 1);
    assert.equal(cli('get', a, '/id').stdout.trim(), '9007199254740992');
  } finally {
    assert.equal(dirname(resolve(dir)),resolve(tmpdir()));
    assert.ok(basename(dir).startsWith('moonconfig-'));
    rmSync(dir, {recursive:true, force:true});
  }
});
