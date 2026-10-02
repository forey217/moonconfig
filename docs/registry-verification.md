# Mooncakes 发布与安装验证

日期：2026-10-02。模块：[forey217/moonconfig@0.2.0](https://mooncakes.io/docs/forey217/moonconfig@0.2.0)。

## 发布

账号为 forey217。发布单元为 MoonConfig 核心库的独立归档，不包含开发工作区、独立消费模块、构建缓存或账号凭据。MIT 许可及上游用例的 Apache-2.0 许可记录均保留。

官方命令 `moon publish --frozen` 检查模块、验证归档、重新解压并检查后上传；结果为 `Server status: 200 OK`。

安装文件与本次发布前归档中的 51 个文件逐一比对一致。该归档的 SHA-256 为 `160278dedfef4ade5f3dc56c29969b9f63a5d262886742999491c5e3841857af`。

## 独立安装

环境：Windows，moon 0.1.20260920，moonc v0.10.14，Node.js 24.21.0。使用仓库外的新消费目录及隔离的 MOON_HOME，仅用目录联接复用官方工具链的 bin/lib；没有登录凭据、moon.work、缓存依赖或本地库路径覆盖。

`moon whoami` 返回 `Not logged in`。随后运行：

```sh
moon add forey217/moonconfig@0.2.0
moon tree
moon check --target js --deny-warn
moon build --target js --deny-warn
moon test --target js --deny-warn
moon test --target wasm-gc --deny-warn
moon run cmd/main --target js
```

安装过程报告 `Registry index cloned successfully` 与 `Downloading forey217/moonconfig@0.2.0`。独立模块的版本依赖指向 registry 安装目录 `.mooncakes/forey217/moonconfig`。

| 检查 | 结果 |
| --- | --- |
| 公开 registry 下载 | 成功，无需登录 |
| 51 个发布文件内容比对 | 全部一致 |
| check / build，JS 后端 | 通过 |
| 公开 API 黑盒测试，JS | 2 / 2 通过 |
| 公开 API 黑盒测试，Wasm GC | 2 / 2 通过 |
| 独立消费主程序 | 通过 |

主程序实际输出：

```text
review: conflicts=1
final: {"level":"debug","port":9443}
replay: port=9443
stale base: rejected
```

测试还验证大整数 9007199254740993、未完成决策拒绝及旧 base 的补丁失败。没有用库内部函数，也没有复用仓库工作区中的本地库。

## 复现及记录边界

在自己的 MoonBit 模块中运行 `moon add forey217/moonconfig@0.2.0` 并导入 `forey217/moonconfig`。仓库中的 examples/consumer 通过 moon.work 使用本地库；复现 registry 验证时，将其中的 .mbt/.pkg 文件复制到仓库外的新模块，然后安装上述版本。

发布版本是固定快照。发布归档中的开发进度文字记录发布前状态；本文件及仓库最新 README 记录后续实际安装结果。该验证不代表外部用户采用、生产部署或赛事报名已经完成。原生后端的验证来自已通过的 Linux CI，独立 registry 消费在本机验证了 JS 和 Wasm GC。
