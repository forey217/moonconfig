# 远程 CI 验证记录

2026-10-02，完整源码已上传到 [forey217/moonconfig](https://github.com/forey217/moonconfig)。

- 源码提交：[4cc2b5d57a22e876ad3f8b5c491602824f087b0a](https://github.com/forey217/moonconfig/commit/4cc2b5d57a22e876ad3f8b5c491602824f087b0a)。
- 工作流：[Verify MoonConfig #36980451563](https://github.com/forey217/moonconfig/actions/runs/36980451563)。
- 验证作业：[verify](https://github.com/forey217/moonconfig/actions/runs/36980451563/job/110753542586)。
- 环境：Linux GitHub Actions、官方 MoonBit 工具链、Node.js 24。
- 创建时间：2026-10-02 07:47:41 UTC；验证作业完成时间：07:48:10 UTC。
- 结果：completed / success；通过 GitHub 公开 Actions API 核对作业及步骤结果。

已通过的主要检查：

| 检查 | 结果 |
| --- | --- |
| moon fmt --check | 通过 |
| moon check --target js --deny-warn | 通过 |
| moon test --target js --deny-warn | 通过 |
| moon test --target wasm-gc --deny-warn | 通过 |
| moon test --target native --deny-warn | 通过 |
| npm run build | 通过 |
| 独立 MoonBit 消费模块 | 通过 |
| CLI 与配置审查完整流程测试 | 通过 |
| 演示构建产物上传 | 通过 |

实际工作流源文件是 [.github/workflows/ci.yml](../.github/workflows/ci.yml)。后续提交会产生各自的运行结果，上述链接固定记录本次源码验证。

该结果验证仓库在 CI 环境中的构建和测试。消费模块通过工作区依赖使用库；本记录不代表 Mooncakes 发布、registry 安装、生产部署或赛事审核已经完成。docs/ci-example.yml 是接入场景模板，本次运行的配置审查验证来自 tests/workflow.test.mjs。
