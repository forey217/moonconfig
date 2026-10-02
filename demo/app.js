const $ = id => document.getElementById(id);
let engine, mode = 'merge', output = '';
const sample = {
  base: '{\n  "server": {\n    "host": "localhost",\n    "port": 8080\n  },\n  "logging": { "level": "info" },\n  "features": ["search", "export"]\n}',
  ours: '{\n  "server": {\n    "host": "localhost",\n    "port": 9090\n  },\n  "logging": { "level": "info" },\n  "features": ["search", "export"]\n}',
  theirs: '{\n  "server": {\n    "host": "localhost",\n    "port": 8080\n  },\n  "logging": { "level": "debug" },\n  "features": ["search", "export"]\n}'
};
const patch = '[\n  { "op": "test", "path": "/server/port", "value": 8080 },\n  { "op": "replace", "path": "/server/port", "value": 9090 }\n]';
function loadSample(name = 'independent') {
  $('input-a').value = sample.base;
  $('input-b').value = mode === 'apply' ? patch : sample.ours;
  $('input-c').value = name === 'conflict' ? sample.theirs.replace('8080', '3000') : sample.theirs;
  if (name === 'large') {
    $('input-a').value = '{"id":9007199254740992,"enabled":true}';
    $('input-b').value = mode === 'apply' ? '[{"op":"replace","path":"/id","value":9007199254740993}]' : '{"id":9007199254740993,"enabled":true}';
    $('input-c').value = '{"id":9007199254740992,"enabled":false}';
  }
  if (name === 'conflict' && mode === 'diff') $('input-b').value = $('input-c').value;
  if (name === 'conflict' && mode === 'apply') $('input-b').value = patch.replace('"value": 8080', '"value": 3000');
  clearResult();
}
function clearResult() {
  output = ''; $('output').textContent = '// 配置已更新，点击运行查看结果';
  $('copy').disabled = $('download').disabled = true;
  $('status').textContent = '等待运行'; $('status').className = 'status';
  $('conflicts').replaceChildren(); $('result-title').textContent = '准备好了';
  $('summary').textContent = '点击运行。所有计算都在当前浏览器完成。';
}
function setMode(next) {
  mode = next;
  document.querySelectorAll('[data-mode]').forEach(b => b.setAttribute('aria-selected', String(b.dataset.mode === mode)));
  $('third-editor').hidden = mode !== 'merge'; $('editors').classList.toggle('two', mode !== 'merge');
  const labels = {merge:['原始版本','BASE','我的修改','OURS','运行合并 →','不同字段自动合并，同一字段的不同修改会报告冲突。'],diff:['原始配置','OLD','目标配置','NEW','生成补丁 →','按字段比较两个 JSON 文档，生成可应用的 JSON Patch。'],apply:['原始配置','DOCUMENT','JSON Patch','PATCH','应用补丁 →','按顺序应用补丁。任一步失败，原配置保持不变。']}[mode];
  ['label-a','hint-a','label-b','hint-b','run','help'].forEach((id,i) => $(id).textContent = labels[i]);
  $('result-note').hidden = mode !== 'merge'; loadSample();
}
function run() {
  if (!engine) return;
  $('conflicts').replaceChildren();
  try {
    const a = $('input-a').value, b = $('input-b').value, c = $('input-c').value;
    const fields = mode === 'merge' ? {base_text:a,ours_text:b,theirs_text:c} : mode === 'diff' ? {old_text:a,new_text:b} : {document_text:a,patch_text:b};
    const response = engine.run_json(JSON.stringify({command:mode,...fields}));
    const metadata = JSON.parse(response);
    if (!metadata.ok) throw new Error(metadata.error);
    // MoonBit serializes the result: JS never re-stringifies user numeric values.
    output = engine.result_json(response); $('output').textContent = output;
    const conflicts = mode === 'merge' ? metadata.result.conflicts : [];
    $('status').className = 'status ' + (conflicts.length ? 'warn' : 'good');
    $('status').textContent = conflicts.length ? `${conflicts.length} 处冲突` : mode === 'merge' ? '合并成功 · 无冲突' : '处理成功';
    $('result-title').textContent = conflicts.length ? '有修改需要你决定' : mode === 'merge' ? '修改可以合并' : mode === 'diff' ? `${metadata.result.length} 个补丁操作` : '补丁已完整应用';
    $('summary').textContent = conflicts.length ? '以下路径有不同修改。预览保留原始值，双方候选值见右侧报告。' : mode === 'merge' ? '独立的修改已合并。右侧报告包含完整配置。' : mode === 'diff' ? '右侧是标准操作数组，可复制到“应用补丁”继续验证。' : '右侧是最终配置。原始输入没有被改动。';
    for (const conflict of conflicts) { const li = document.createElement('li'); li.textContent = conflict.path || '(文档根节点)'; $('conflicts').append(li); }
    $('copy').disabled = $('download').disabled = false;
  } catch (error) {
    output = ''; $('output').textContent = error.message;
    $('status').textContent = '输入或操作错误'; $('status').className = 'status error';
    $('result-title').textContent = '处理未完成'; $('summary').textContent = '请检查 JSON 格式、操作字段和路径。输入配置保持不变。';
    $('copy').disabled = $('download').disabled = true;
  }
}
document.querySelectorAll('[data-mode]').forEach(b => b.addEventListener('click', () => setMode(b.dataset.mode)));
document.querySelectorAll('[data-sample]').forEach(b => b.addEventListener('click', () => loadSample(b.dataset.sample)));
document.querySelectorAll('textarea').forEach(t => t.addEventListener('input', clearResult));
$('run').addEventListener('click', run);
$('copy').addEventListener('click', async () => { try { await navigator.clipboard.writeText(output); $('copy').textContent = '已复制'; setTimeout(() => $('copy').textContent = '复制 JSON', 1500); } catch { $('status').textContent = '请手动选择结果复制'; } });
$('download').addEventListener('click', () => { const url = URL.createObjectURL(new Blob([output + '\n'], {type:'application/json'})); const a = document.createElement('a'); a.href = url; a.download = `moonconfig-${mode}.json`; a.click(); setTimeout(() => URL.revokeObjectURL(url), 1000); });
setMode('merge');
try { engine = await import('./engine.js'); $('run').disabled = false; run(); }
catch { $('run').textContent = '核心未加载'; $('status').textContent = '请先运行 npm run build'; $('status').className = 'status error'; }
