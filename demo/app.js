const $ = id => document.getElementById(id);
let engine, mode = 'merge', output = '', outputName = 'report';
let mergeRequest = null, previewResponse = '', decisionRows = [], finalOutputs = null, conflictCount = 0;
const sample = {
  base: '{\n  "server": { "host": "localhost", "port": 8080 },\n  "logging": { "level": "info" },\n  "features": ["search", "export"]\n}',
  ours: '{\n  "server": { "host": "localhost", "port": 9090 },\n  "logging": { "level": "info" },\n  "features": ["search", "export"]\n}',
  theirs: '{\n  "server": { "host": "localhost", "port": 8080 },\n  "logging": { "level": "debug" },\n  "features": ["search", "export"]\n}'
};
const patch = '[\n  { "op": "test", "path": "/server/port", "value": 8080 },\n  { "op": "replace", "path": "/server/port", "value": 9090 }\n]';
function loadSample(name = 'independent') {
  $('input-a').value = sample.base;
  $('input-b').value = mode === 'apply' ? patch : sample.ours;
  $('input-c').value = name === 'conflict' ? sample.theirs.replace('8080', '3000') : sample.theirs;
  if (name === 'large') {
    $('input-a').value = '{"id":9007199254740992,"enabled":true}';
    $('input-b').value = mode === 'apply' ? '[{"op":"replace","path":"/id","value":9007199254740993}]' : '{"id":9007199254740993,"enabled":true}';
    $('input-c').value = '{"id":9007199254740994,"enabled":false}';
  }
  if (name === 'presence') {
    $('input-a').value = '{"timeout":30,"logging":{"level":"info"}}';
    $('input-b').value = mode === 'apply' ? '[{"op":"remove","path":"/timeout"}]' : '{"logging":{"level":"info"}}';
    $('input-c').value = '{"timeout":null,"logging":{"level":"debug"}}';
  }
  if ((name === 'conflict' || name === 'presence') && mode === 'diff') $('input-b').value = $('input-c').value;
  if (name === 'conflict' && mode === 'apply') $('input-b').value = patch.replace('"value": 8080', '"value": 3000');
  clearResult();
}
function clearResult() {
  output = ''; finalOutputs = null; mergeRequest = null; previewResponse = ''; decisionRows = []; conflictCount = 0;
  $('output').textContent = '// 配置已更新，点击运行查看结果';
  $('copy').disabled = $('download').disabled = true;
  $('download').textContent = '下载结果';
  $('status').textContent = '等待运行'; $('status').className = 'status';
  $('conflicts').replaceChildren(); $('decision-list').replaceChildren();
  $('review').hidden = $('exports').hidden = true;
  $('result-title').textContent = '准备好了';
  $('summary').textContent = '点击运行。所有计算都在当前浏览器完成。';
}
function setMode(next) {
  mode = next;
  document.querySelectorAll('[data-mode]').forEach(b => {
    b.setAttribute('aria-selected', String(b.dataset.mode === mode));
    b.tabIndex = b.dataset.mode === mode ? 0 : -1;
  });
  $('third-editor').hidden = mode !== 'merge'; $('editors').classList.toggle('two', mode !== 'merge');
  const labels = {
    merge:['原始版本','BASE','我的修改','OURS','运行合并 →','先合并独立修改，再逐项确认冲突并导出结果。'],
    diff:['原始配置','OLD','目标配置','NEW','生成补丁 →','按字段比较两个 JSON 文档，生成可应用的 JSON Patch。'],
    apply:['原始配置','DOCUMENT','JSON Patch','PATCH','应用补丁 →','按顺序应用补丁。任一步失败，原配置保持不变。']
  }[mode];
  ['label-a','hint-a','label-b','hint-b','run','help'].forEach((id,i) => $(id).textContent = labels[i]);
  $('result-note').hidden = mode !== 'merge'; loadSample();
}
function invoke(request) {
  const response = engine.run_json(JSON.stringify(request));
  const metadata = JSON.parse(response);
  if (!metadata.ok) throw new Error(metadata.error);
  return {response, result:metadata.result};
}
function showError(error) {
  output = ''; finalOutputs = null; $('exports').hidden = true;
  $('output').textContent = error.message;
  $('status').textContent = '输入或操作错误'; $('status').className = 'status error';
  $('result-title').textContent = '处理未完成';
  $('summary').textContent = '请检查 JSON、路径及每项选择。输入配置保持不变。';
  $('copy').disabled = $('download').disabled = true;
}
function showOutput(text, name = 'report') {
  output = text; outputName = name; $('output').textContent = text;
  $('copy').disabled = $('download').disabled = false;
  $('download').textContent = name === 'value' ? '下载最终配置' : name === 'patch' ? (finalOutputs ? '下载校验补丁' : '下载补丁') : finalOutputs ? '下载完整报告' : mode === 'merge' ? '下载预览' : '下载结果';
}
function selectOutput(name) {
  if (!finalOutputs) return;
  showOutput(finalOutputs[name], name);
  $('download-patch').hidden = name === 'patch';
  document.querySelectorAll('[data-output]').forEach(b => b.setAttribute('aria-pressed', String(b.dataset.output === name)));
}
function updateDecisions() {
  finalOutputs = null; $('exports').hidden = true;
  showOutput(engine.result_json(previewResponse));
  const count = decisionRows.filter(row => row.select.value && (row.select.value !== 'custom' || row.custom.value.trim())).length;
  $('decision-count').textContent = `已选择 ${count} / ${conflictCount}`;
  $('resolve').disabled = count !== conflictCount || conflictCount > 200;
  $('status').textContent = `${conflictCount} 处冲突 · 待确认`; $('status').className = 'status warn';
  $('result-title').textContent = '有修改需要你决定';
  $('summary').textContent = '预览保留原始值。逐项选择后，生成最终配置和经过回放校验的补丁。';
}
function element(tag, text, className) {
  const el = document.createElement(tag); if (text !== undefined) el.textContent = text; if (className) el.className = className; return el;
}
function renderDecisions(response, conflicts) {
  conflictCount = conflicts.length;
  $('review').hidden = false; $('decision-list').replaceChildren(); decisionRows = [];
  $('review-message').textContent = conflicts.length > 200 ? '本页最多处理 200 处冲突。更多冲突请使用 CLI。' : '每项都选好后，点击确认。修改输入配置会清除已有选择。';
  if (conflicts.length > 200) {
    $('decision-count').textContent = `共 ${conflicts.length} 处冲突`;
    $('resolve').disabled = true;
    $('status').textContent = `${conflicts.length} 处冲突 · 请使用 CLI`;
    $('status').className = 'status warn';
    $('result-title').textContent = '请使用 CLI 确认';
    $('summary').textContent = '冲突数量超过网页交互上限。当前输出是预览，尚未生成最终配置。';
    return;
  }
  for (const [index, conflict] of conflicts.slice(0,200).entries()) {
    const card = element('article', undefined, 'decision-card');
    card.append(element('h4', conflict.path || '(文档根节点)'));
    const candidates = element('div', undefined, 'candidates');
    for (const [side, label] of [['base','原始值'],['ours','我的修改'],['theirs','另一份修改']]) {
      const box = element('section'); box.append(element('p', label));
      const text = conflict[side].present ? engine.result_path_json(response, `/conflicts/${index}/${side}/value`) : '字段缺失';
      box.append(element('pre', text)); candidates.append(box);
    }
    card.append(candidates);
    const id = `choice-${index}`, customId = `custom-${index}`;
    const label = element('label', '这个位置采用'); label.htmlFor = id;
    const select = element('select'); select.id = id;
    for (const [value, text] of [['','请选择…'],['base','保留原始值'],['ours','采用我的修改'],['theirs','采用另一份修改'],['delete','删除这个字段'],['custom','填写自定义 JSON']]) {
      const option = element('option', text); option.value = value;
      if (value === 'delete' && conflict.path === '') option.disabled = true;
      select.append(option);
    }
    const choiceBar = element('div', undefined, 'choice-bar'); choiceBar.append(label, select); card.append(choiceBar);
    const customLabel = element('label', '自定义 JSON'); customLabel.htmlFor = customId; customLabel.hidden = true;
    const custom = element('textarea'); custom.id = customId; custom.hidden = true; custom.spellcheck = false;
    const row = {path:conflict.path, select, custom}; decisionRows.push(row);
    select.addEventListener('change', () => { custom.hidden = customLabel.hidden = select.value !== 'custom'; updateDecisions(); });
    custom.addEventListener('input', updateDecisions);
    card.append(customLabel, custom); $('decision-list').append(card);
  }
  updateDecisions();
}
function confirmDecisions() {
  if (!mergeRequest) return;
  try {
    const decisions = decisionRows.map(row => ({path:row.path, choice:row.select.value, ...(row.select.value === 'custom' ? {value_text:row.custom.value} : {})}));
    const {response, result} = invoke({...mergeRequest, command:'resolve', decisions_text:JSON.stringify(decisions)});
    if (!result.verified) throw new Error('补丁回放校验未完成');
    finalOutputs = {value:engine.result_field_json(response,'value'),patch:engine.result_field_json(response,'patch'),report:engine.result_json(response)};
    $('exports').hidden = false; selectOutput('value');
    $('status').textContent = '已确认 · 补丁回放通过'; $('status').className = 'status good';
    $('result-title').textContent = '最终配置已生成';
    $('summary').textContent = '补丁已在原始版本上回放并核对结果。应用到其他版本时，原始配置校验会拒绝执行。';
    $('conflicts').replaceChildren();
  } catch (error) { showError(error); }
}
function run() {
  if (!engine) return;
  clearResult();
  try {
    const a = $('input-a').value, b = $('input-b').value, c = $('input-c').value;
    const fields = mode === 'merge' ? {base_text:a,ours_text:b,theirs_text:c} : mode === 'diff' ? {old_text:a,new_text:b} : {document_text:a,patch_text:b};
    const {response, result} = invoke({command:mode,...fields});
    showOutput(engine.result_json(response), mode === 'diff' ? 'patch' : 'report');
    if (mode === 'merge') {
      mergeRequest = fields; previewResponse = response;
      if (result.conflicts.length) {
        for (const conflict of result.conflicts.slice(0,200)) $('conflicts').append(element('li', conflict.path || '(文档根节点)'));
        renderDecisions(response, result.conflicts);
      } else { confirmDecisions(); }
    } else {
      $('status').className = 'status good'; $('status').textContent = '处理成功';
      $('result-title').textContent = mode === 'diff' ? `${result.length} 个补丁操作` : '补丁已完整应用';
      $('summary').textContent = mode === 'diff' ? '复制到“应用补丁”可继续验证。' : '右侧是最终配置。原始输入没有被改动。';
    }
  } catch (error) { showError(error); }
}
function download(text, name) {
  const url = URL.createObjectURL(new Blob([text + '\n'], {type:'application/json'}));
  const a = element('a'); a.href = url; a.download = `moonconfig-${name}.json`; a.click(); setTimeout(() => URL.revokeObjectURL(url),1000);
}
document.querySelectorAll('[data-mode]').forEach((b,i,buttons) => {
  b.addEventListener('click', () => setMode(b.dataset.mode));
  b.addEventListener('keydown', e => { if (e.key === 'ArrowRight' || e.key === 'ArrowLeft') { e.preventDefault(); const next = buttons[(i + (e.key === 'ArrowRight' ? 1 : buttons.length-1)) % buttons.length]; setMode(next.dataset.mode); next.focus(); } });
});
document.querySelectorAll('[data-sample]').forEach(b => b.addEventListener('click', () => loadSample(b.dataset.sample)));
document.querySelectorAll('.editor textarea').forEach(t => t.addEventListener('input', clearResult));
document.querySelectorAll('[data-output]').forEach(b => b.addEventListener('click', () => selectOutput(b.dataset.output)));
$('run').addEventListener('click', run); $('resolve').addEventListener('click', confirmDecisions);
$('copy').addEventListener('click', async () => { try { await navigator.clipboard.writeText(output); $('copy').textContent = '已复制'; setTimeout(() => $('copy').textContent = '复制 JSON',1500); } catch { $('status').textContent = '请手动选择结果复制'; } });
$('download').addEventListener('click', () => download(output,outputName));
$('download-patch').addEventListener('click', () => { if (finalOutputs) download(finalOutputs.patch,'patch'); });
setMode('merge');
try { engine = await import('./engine.js'); $('run').disabled = false; run(); }
catch { $('run').textContent = '核心未加载'; $('status').textContent = '请先运行 npm run build'; $('status').className = 'status error'; }
