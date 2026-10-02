import {performance} from 'node:perf_hooks';
import {run_json} from '../demo/engine.js';
// Generated numeric fixtures use small integers. User JSON stays in MoonBit.
const cases = [];
for (const fields of [100,1000,10000]) {
  const base = Object.fromEntries(Array.from({length:fields},(_,i)=>['field'+i,i]));
  const ours = {...base,field0:-1};
  const theirs = {...base,field0:-2,field1:-3};
  const request = JSON.stringify({command:'resolve',base,ours,theirs,decisions:[{path:'/field0',choice:'ours'}]});
  const sample = () => {
    const start = performance.now(); const text = run_json(request); const elapsed = performance.now()-start;
    const response = JSON.parse(text);
    if (!response.ok || !response.result.verified || response.result.value.field0 !== -1 || response.result.value.field1 !== -3) throw new Error('benchmark correctness check failed');
    return elapsed;
  };
  sample(); // one warm-up
  const timings = Array.from({length:5},sample).sort((a,b)=>a-b);
  cases.push({fields,samples:5,minMs:+timings[0].toFixed(2),medianMs:+timings[2].toFixed(2),heapUsedAfterMiB:+(process.memoryUsage().heapUsed/1048576).toFixed(2)});
}
console.log(JSON.stringify({node:process.version,platform:process.platform,arch:process.arch,method:'release JS bridge; one warm-up; five samples; parsing, merge, decisions, guarded diff, replay and serialization included; heap observation is not peak memory',cases},null,2));
