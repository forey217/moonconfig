import test from 'node:test';
import assert from 'node:assert/strict';
import {spawnSync} from 'node:child_process';
import {mkdtempSync, writeFileSync, readFileSync, rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join, resolve, dirname, basename} from 'node:path';
import {fileURLToPath} from 'node:url';
const root = fileURLToPath(new URL('../', import.meta.url));
const cli = (...args) => spawnSync(process.execPath, ['scripts/moonconfig.mjs', ...args], {cwd:root,encoding:'utf8'});
function fixture(run) {
  const dir = mkdtempSync(join(tmpdir(), 'moonconfig-review-'));
  const save = (name, text) => { const p = join(dir,name); writeFileSync(p,text); return p; };
  try { run(save); }
  finally {
    assert.equal(dirname(resolve(dir)),resolve(tmpdir()));
    assert.ok(basename(dir).startsWith('moonconfig-review-'));
    rmSync(dir,{recursive:true,force:true});
  }
}
test('review workflow: resolve, export exact values, replay, reject stale base', () => fixture(save => {
  const original = '{"port":8080,"level":"info","id":9007199254740992}';
  const base = save('base.json',original);
  const ours = save('ours.json','{"port":9090,"level":"info","id":9007199254740993}');
  const theirs = save('theirs.json','{"port":3000,"level":"debug","id":9007199254740992}');
  assert.equal(cli('merge',base,ours,theirs).status,2);
  const decisions = save('decisions.json','[{"path":"/port","choice":"custom","value":9443}]');
  const reviewed = cli('resolve',base,ours,theirs,decisions);
  assert.equal(reviewed.status,0,reviewed.stderr);
  assert.equal(JSON.parse(reviewed.stdout).verified,true);
  const final = cli('resolve',base,ours,theirs,decisions,'--output','value');
  assert.equal(final.status,0,final.stderr);
  assert.equal(JSON.parse(final.stdout).port,9443);
  assert.equal(JSON.parse(final.stdout).level,'debug');
  assert.match(final.stdout,/9007199254740993/);
  const exported = cli('resolve',base,ours,theirs,decisions,'--output','patch');
  assert.equal(exported.status,0,exported.stderr);
  assert.equal(JSON.parse(exported.stdout)[0].op,'test');
  assert.equal(JSON.parse(exported.stdout)[0].path,'');
  const patch = save('patch.json',exported.stdout);
  const replay = cli('apply',base,patch);
  assert.equal(replay.status,0,replay.stderr);
  assert.deepEqual(JSON.parse(replay.stdout),JSON.parse(final.stdout));
  assert.match(replay.stdout,/9007199254740993/);
  const staleText = original.replace('8080','8081');
  const stale = save('stale.json',staleText);
  const blocked = cli('apply',stale,patch);
  assert.equal(blocked.status,1);
  assert.equal(blocked.stdout,'');
  assert.match(blocked.stderr,/Test failed/);
  assert.equal(readFileSync(base,'utf8'),original);
  assert.equal(readFileSync(stale,'utf8'),staleText);
}));
test('review workflow: incomplete choices block CI; deletion differs from null', () => fixture(save => {
  const base = save('base.json','{"x":1}');
  const ours = save('ours.json','{}');
  const theirs = save('theirs.json','{"x":null}');
  for (const [name,text] of [
    ['missing','[]'],
    ['duplicate','[{"path":"/x","choice":"ours"},{"path":"/x","choice":"theirs"}]'],
    ['unknown','[{"path":"/z","choice":"ours"}]'],
    ['invalid-custom','[{"path":"/x","choice":"custom","value_text":"0,1"}]']
  ]) {
    const failed = cli('resolve',base,ours,theirs,save(name+'.json',text));
    assert.equal(failed.status,1,name);
    assert.equal(failed.stdout,'',name);
  }
  const remove = cli('resolve',base,ours,theirs,save('remove.json','[{"path":"/x","choice":"ours"}]'),'--output','value');
  assert.equal(remove.status,0,remove.stderr);
  assert.deepEqual(JSON.parse(remove.stdout),{});
  const keepNull = cli('resolve',base,ours,theirs,save('null.json','[{"path":"/x","choice":"theirs"}]'),'--output','value');
  assert.equal(keepNull.status,0,keepNull.stderr);
  assert.deepEqual(JSON.parse(keepNull.stdout),{x:null});
  const invalidFlag = cli('resolve',base,ours,theirs,save('valid.json','[{"path":"/x","choice":"base"}]'),'--output','unknown');
  assert.equal(invalidFlag.status,1);
  assert.equal(invalidFlag.stdout,'');
}));
