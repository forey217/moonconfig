# 本机测量记录

日期：2026-10-02。Windows x64，Node.js v24.21.0，MoonBit moon 0.1.20260920 / moonc v0.10.14，release JavaScript 引擎。

```sh
npm run build
node scripts/benchmark.mjs
```

每组生成一个含对应数量字段的对象。双方修改 field0 为不同值，theirs 独立修改 field1，决策采用 ours 的 field0。计时包含 MoonBit JSON 解析、合并、决策、带 base test 的 diff、补丁回放和序列化，使用字符串桥接入口。每组先预热一次，再记录 5 次。

| 字段数 | 最小耗时 ms | 中位耗时 ms | 组完成后 Node heapUsed MiB |
| --- | ---: | ---: | ---: |
| 100 | 2.74 | 3.20 | 8.27 |
| 1000 | 15.84 | 17.80 | 18.84 |
| 10000 | 334.45 | 350.61 | 59.24 |

heapUsed 是整个 Node 进程在该时刻的观察，包含生成数据、引擎及历史分配，不是峰值，也不是每次操作的净内存消耗。后续运行数值可能因硬件、GC、负载和工具链变化而不同。

脚本对每次结果检查 verified 及两个修改字段。这是固定工作负载的观察，不是吞吐承诺、最大输入承诺、复杂冲突压力测试或竞品性能比较。
