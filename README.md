# MoonConfig

**MoonBit 原生 JSON 配置变更工具：字段比较、原子补丁、三方合并与明确的冲突报告。**

项目处于 v0.1 原型阶段，作为 2026 MoonBit 黑客松参赛候选项目开发；尚未完成报名或赛事验收。

例如：一人修改服务端口，一人修改日志等级，MoonConfig 自动合并；两人把同一端口改为不同值，报告 `/server/port` 冲突，保留原始值供审查。

## 当前实现

- 结构化 diff：按字段比较，稳定的字典顺序，生成 JSON Patch。
- JSON Pointer：根路径、空键、Unicode、`~0` 和 `~1` 转义。
- JSON Patch：`add`、`remove`、`replace`、`move`、`copy`、`test`；失败不修改输入文档。
- 三方合并：独立修改自动合并，相同修改去重，删除/修改冲突，类型变更冲突。
- 明确区分字段缺失与 JSON `null`。
- 比较数字时使用十进制表示归一化，不把大整数先转成 JavaScript Number；命令行和演示结果保留原始数字表示。
- 浏览器工作台、Node CLI、中英文说明、MoonBit 测试和 CI 工作流。
- 核心只依赖 MoonBit 标准库。Node 负责文件输入输出和本地演示服务器。

## 快速运行

需要 [官方 MoonBit 工具链](https://www.moonbitlang.com/download/) 和 Node.js 20+。本地开发已验证 MoonBit `moonc v0.10.14` / `moon 0.1.20260920`。

```sh
git clone https://github.com/forey217/moonconfig.git
cd moonconfig
npm run build
node scripts/moonconfig.mjs merge examples/base.json examples/ours.json examples/theirs.json
npm run demo
```

打开 <http://127.0.0.1:4173>，试用“独立修改”“同字段冲突”“大整数变更”。配置数据只在当前浏览器本地处理，演示没有上传接口。

无需 `npm install`，本项目没有 npm 依赖。构建生成 `demo/engine.js`，该文件不提交 Git。

## 命令行

```sh
node scripts/moonconfig.mjs diff examples/base.json examples/ours.json
node scripts/moonconfig.mjs apply examples/base.json examples/patch.json
node scripts/moonconfig.mjs merge examples/base.json examples/ours.json examples/conflict.json
node scripts/moonconfig.mjs get examples/base.json /server/port
```

diff 输出标准补丁数组；apply 输出最终配置；merge 输出 `{clean, value, conflicts}`。退出码：`0` 成功、`1` 输入/文件/操作错误、`2` 未解决的合并冲突。结果写 stdout，错误写 stderr。输入文件不会被覆盖。

保存输出时请使用 UTF-8。Windows PowerShell 5 的默认输出重定向编码不同，请用 `Out-File -Encoding utf8`；CLI 接受 UTF-8 BOM。

## MoonBit API

在包配置中导入本模块，并指定别名：

```moonbit
import {
  "forey217/moonconfig" @config,
  "moonbitlang/core/json",
}
```

```moonbit
let base = @json.parse("{\"port\":8080,\"level\":\"info\"}")
let ours = @json.parse("{\"port\":9090,\"level\":\"info\"}")
let theirs = @json.parse("{\"port\":8080,\"level\":\"debug\"}")
let result = @config.merge(base, ours, theirs)
let patch = @config.diff(base, ours)
let updated = @config.apply(base, patch)
```

这些操作可能抛出 `ConfigError`，调用方需要使用 MoonBit 的错误处理。以上片段应放在允许抛错的函数或测试中。本包尚未发布到 Mooncakes，当前请使用仓库源码。

## 合并语义与边界

1. 一方未修改：使用另一方。
2. 双方修改结果相同：使用共同结果。
3. 双方修改对象的不同字段：递归合并。
4. 同一位置有不同修改：报告冲突，预览结果保留该位置的原始值；原来不存在时继续保持缺失。

**`clean: false` 的结果是审查预览，不是可以自动部署的配置。** 缺失用 `{"present":false}` 表示，显式 null 用 `{"present":true,"value":null}` 表示。

当前数组按整体处理；不宣称生成最短补丁、数组元素级智能合并、YAML/TOML 支持或完整配置迁移功能。超过 10000 个操作的 diff 回退为一次根替换。拒绝根节点 `remove`，因为该 API 必须返回一个 JSON 文档；其他 RFC 6902 操作有测试覆盖，尚不宣称完整标准认证。

文档最多 128 层、100000 个节点；补丁最多 10000 个操作；路径最多 128 段；JSON 字符串入口最多 4000000 个 UTF-16 单位；数字十进制指数范围为 ±1000000。通过 JSON 解析入口传入大整数可保留精度；调用方如果先转换为 Double，已丢失的精度无法恢复。重复对象键使用 MoonBit 标准解析器的最后值规则，不保留原始空白/键重复/注释。

## 验证

```sh
moon fmt --check
moon check --target js --deny-warn
moon test --target js --deny-warn
moon test --target wasm-gc --deny-warn
npm run build
node --test tests/cli.test.mjs
```

目前 132 个 MoonBit 测试：108 个上游 JSON Patch 有效用例和 24 个配置合并/边界测试，其中一个矩阵测试覆盖 121 组 diff/apply 往返。CLI 集成测试实际调用进程，检查文件输入输出、大整数、错误码和冲突退出码。JavaScript、WebAssembly GC 在本地验证；原生后端本机缺少 C 编译器，配置了 Linux CI 验证，首次远程 CI 结果待确认。

## 开发与参赛材料

- [设计与取舍](docs/design.md)
- [项目申报草稿](docs/proposal.md)
- [对照上次初审反馈的改进计划](docs/review-plan.md)
- [开发记录与验证](docs/development.md)
- [English README](README_EN.md)

## 来源与许可

实现根据 [RFC 6901](https://www.rfc-editor.org/rfc/rfc6901)、[RFC 6902](https://www.rfc-editor.org/rfc/rfc6902) 的行为独立编写。上游测试来自 [json-patch/json-patch-tests](https://github.com/json-patch/json-patch-tests)，保留在 `tests/upstream/`，遵循 Apache-2.0，详见 [第三方声明](THIRD_PARTY_NOTICES.md)。项目代码采用 MIT。开发使用 AI 辅助，参赛者需理解实现、审查成果并承担维护责任。
