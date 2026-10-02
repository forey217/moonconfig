# MoonConfig

**MoonBit 可嵌入的 JSON 配置三方合并与冲突审查工具。**

v0.2 原型已完成“发现冲突 → 显式决策 → 最终配置 → 校验补丁 → 回放核对”的流程。完整源码已上传 GitHub，[远程 CI 已通过](docs/ci-verification.md)。项目用于准备 2026 MoonBit 黑客松；尚未完成报名或 Mooncakes 发布。

例如：一人修改端口，一人修改日志等级，自动合并独立字段；双方修改同一端口时，逐项选择原值、某一方、删除或自定义值。导出的补丁先校验整个原始配置，避免应用到已经变化的版本。

## 当前实现

- 三方合并与逐项冲突解决：遗漏、重复、未知路径和非法决策均会失败。
- 删除与 JSON null 明确区分；根节点可替换，不能删除。
- 最终配置与受 base 校验保护的 JSON Patch；核心会回放补丁并核对结果。
- 字段 diff、严格 JSON Pointer、六种 JSON Patch 操作；失败不修改输入。
- 十进制精确比较与序列化，不把配置大整数先转成 JavaScript Number。
- 浏览器工作台、Node CLI、独立 MoonBit 消费模块、CI 场景模板与实际进程集成测试。
- 核心只依赖 MoonBit 标准库；Node 负责文件输入输出和本地服务器。

## 快速运行

需要 [官方 MoonBit 工具链](https://www.moonbitlang.com/download/) 和 Node.js 20+。本地使用 moon 0.1.20260920、moonc v0.10.14、Node 24.21.0。

```sh
git clone https://github.com/forey217/moonconfig.git
cd moonconfig
npm run build
npm run demo
```

无需 npm install，本项目没有 npm 依赖。GitHub 仓库包含完整源码、消费示例和自动验证流程。

打开 http://127.0.0.1:4173，尝试“同字段冲突”“删除与 null”“大整数变更”。选择每个冲突，再确认并导出最终配置或补丁。修改输入会清除已有决策。所有配置计算在当前浏览器本地完成，没有上传接口。

## 命令行审查流程

```sh
node scripts/moonconfig.mjs merge examples/base.json examples/ours.json examples/conflict.json
node scripts/moonconfig.mjs resolve examples/base.json examples/ours.json examples/conflict.json examples/decisions.json
node scripts/moonconfig.mjs resolve examples/base.json examples/ours.json examples/conflict.json examples/decisions.json --output value
node scripts/moonconfig.mjs resolve examples/base.json examples/ours.json examples/conflict.json examples/decisions.json --output patch
```

第一条报告 /server/port 冲突并返回退出码 2。决策文件将端口设为 9443；resolve 同时保留独立的 debug 日志修改，生成最终配置和补丁，回放验证后返回 `{clean:true, verified:true, value, patch}`。

决策格式：

```json
[{"path":"/server/port","choice":"custom","value":9443}]
```

choice 可为 base、ours、theirs、delete、custom。custom 必须包含 value。每个冲突必须且只能有一个决策；无冲突时传空数组。网页适配层可用 value_text 传递自定义 JSON 文本，由 MoonBit 单独解析。

其他命令：

```sh
node scripts/moonconfig.mjs diff examples/base.json examples/ours.json
node scripts/moonconfig.mjs apply examples/base.json examples/patch.json
node scripts/moonconfig.mjs get examples/base.json /server/port
```

退出码 0 成功、1 输入/文件/操作/决策错误、2 未解决的 merge 冲突。结果写 stdout，错误写 stderr；输入文件不会被覆盖。保存输出请使用 UTF-8，Windows PowerShell 5 可用 Out-File -Encoding utf8，CLI 接受 UTF-8 BOM。

## MoonBit API 与独立复用

在 moon.pkg 中导入：

```moonbit
import {
  "forey217/moonconfig" @config,
  "moonbitlang/core/json",
}
```

在允许抛错的函数或测试中调用：

```moonbit
let base = @json.parse("{\"port\":8080,\"level\":\"info\"}")
let ours = @json.parse("{\"port\":9090,\"level\":\"info\"}")
let theirs = @json.parse("{\"port\":3000,\"level\":\"debug\"}")
let reviewed = @config.resolve(base, ours, theirs, [
  { path: "/port", choice: @config.Choice::Set(@json.parse("9443")) },
])
let replay = @config.apply(base, reviewed.patch)
```

公开接口见 pkg.generated.mbti。`guarded_diff` 可为其他审查流程生成受原版本校验保护的补丁。返回值隔离输入容器；若调用方随后修改返回的 JSON/数组，需要重新生成和验证补丁。

examples/consumer 是有自己 moon.mod 的独立消费模块，使用公开接口。moon.work 将其依赖解析到本地库：

```sh
cd examples/consumer
moon run cmd/main --target js
moon test --package forey217/config-gate-example --target js --deny-warn
```

已经验证跨模块接入；尚未验证从 Mooncakes 安装。示例属于集成证据，不代表外部用户采用或生产部署。

## 合并语义与边界

一方未修改时取另一方；双方结果相同时取共同结果；对象独立字段递归合并。其余不同变更输出冲突，预览保留 base，原字段缺失时继续缺失。类型替换和数组按整体处理。

`clean:false` 是待确认的预览。resolve 会从三份文档重新计算冲突，不接受调用方伪造的预览作为依据。守护补丁第一步 test 整个 base：任何字段的语义变化都会失败，但等值数字写法、键顺序和空白变化不构成不同配置。这不是字节校验、数字签名或配置 schema 验证。

不宣称最短补丁、完整 RFC 认证、数组元素身份推断、YAML/TOML 支持或自动部署。超过 10000 个操作的 diff 回退为根 replace；guarded_diff 为 test 留出一个操作额度。apply 拒绝根 remove。

每份文档/操作 value 最多 128 层、100000 节点；补丁最多 10000 操作；决策最多 10000 项；路径最多 128 段；字符串入口最多 4000000 UTF-16 单位；数字指数 ±1000000。网页最多交互处理 200 个冲突，更多使用 CLI。重复键采用标准解析器最后值规则，不保留空白或注释。输入在进入库之前丢失的数字精度无法恢复。限制不构成恶意输入的严格资源隔离。

## 生态增量与证据

生态已有 [tiye/recollect](https://mooncakes.io/docs/tiye/recollect) 等 JSON diff/patch 工具。本项目聚焦配置三方合并、明确的缺失/null 冲突、显式决策和可校验的审查输出。不宣称该领域空白、首创或优于已有项目的性能。

目前证据是公开源码、可运行的公开 API、独立消费模块、网页闭环及已通过的远程 CLI/CI 场景验证；Mooncakes 发布和外部采用仍未完成。

## 验证

```sh
moon fmt --check
moon check --target js --deny-warn
moon test --target js --deny-warn
moon test --target wasm-gc --deny-warn
moon info
npm run build
node --test tests/cli.test.mjs tests/workflow.test.mjs
```

工作区共 150 个 MoonBit 测试：库内 148 个（108 个上游 JSON Patch 用例、40 个项目测试），另有独立消费模块 2 个黑盒测试。矩阵用例覆盖 121 组 diff/apply 往返。3 个 Node 集成测试启动真实 CLI，验证精度、冲突、决策、导出、回放、旧 base 拒绝及输入文件不变。

JS 和 WebAssembly GC 已在本地验证；Linux GitHub Actions 的 JS、WebAssembly GC、原生测试、构建、独立消费示例与 Node 集成测试均已通过，见 [远程验证记录](docs/ci-verification.md)。本地 Windows 缺少 C 编译器。基准脚本 `node scripts/benchmark.mjs` 与 [测量记录](docs/benchmark.md) 提供方法和本机结果，不承诺跨环境性能。

## 文档与参赛材料

- [完整使用场景及 CI 模板](docs/workflow.md)
- [设计与取舍](docs/design.md)
- [项目申报草稿](docs/proposal.md)
- [对照初审反馈的进度](docs/review-plan.md)
- [开发与验证记录](docs/development.md)
- [远程 CI 验证证据](docs/ci-verification.md)
- [English README](README_EN.md)

实现依照 RFC 6901/6902 行为独立编写。上游测试来自 json-patch/json-patch-tests，保留 Apache-2.0 许可；详见 THIRD_PARTY_NOTICES.md。项目代码 MIT。开发使用 AI 辅助，参赛者需理解实现、审查成果并承担维护责任。
