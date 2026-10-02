# MoonConfig 项目申报书（草稿）

**1．项目名称：** MoonConfig。

**2．项目简介：** JSON 配置经过多人修改后，需要分清哪些改动可以合并、哪些必须确认。MoonConfig 用 MoonBit 比较共同原版和两份修改，合并独立字段，列出冲突；确认后生成最终配置及带原版校验的补丁。

**3．方向与通用性：** 开发者工具、可复用工具库。核心只依赖 MoonBit 标准库，提供公开 API；同一核心供网页、Node CLI 和独立 MoonBit 模块使用，适用于 JSON 配置，不绑定某个框架。

**4．预期使用场景：**
- 服务配置协作：两位维护者分别改端口和日志等级，输入原版及双方版本，自动保留两项改动；若都改端口，逐项选择后下载最终配置和决策文件。
- CI 配置审查：流水线读取原版、双方版本及人工确认的决策。未解决冲突返回非零退出码；确认后导出补丁，应用前检查原版，防止误用到已变化的配置。
- MoonBit 工具接入：其他项目从 Mooncakes 安装核心库，调用 merge、resolve、apply，实现自己的配置审查界面；字段删除与 null、大整数均按 JSON 语义处理。

**5．核心功能与进度：** 已实现字段比较、JSON Pointer、六种 JSON Patch 操作、三方合并、显式决策和补丁回放。网页可导出已确认决策，CLI 可安全保存 UTF-8 结果且拒绝覆盖已有文件。150 个 MoonBit 测试及 5 个 CLI 集成测试通过；核心 JS、Wasm GC、原生后端已有 CI 验证。后续补充演示视频及真实用户反馈。数组整体处理，暂不支持 YAML/TOML；上述场景有样例验证，尚无生产采用记录。

**6．项目来源：** 原创实现，参考 RFC 6901/6902；不是现有库的移植。生态已有 tiye/recollect 等 JSON 差异工具，本项目重点是配置三方审查、决策复用和校验回放。

**7．来源与许可证：** 项目代码 MIT。测试引用 [json-patch/json-patch-tests](https://github.com/json-patch/json-patch-tests) 用例，保留 Apache-2.0 许可及来源说明。

**8．仓库与交付：** https://github.com/forey217/moonconfig 。主分支保留实现、测试和验证提交记录。核心 [forey217/moonconfig@0.2.0](https://mooncakes.io/docs/forey217/moonconfig@0.2.0) 已发布并通过独立安装验证；README 提供运行命令、示例和边界说明。
