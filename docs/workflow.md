# 可复现的配置审查流程

## 输入与预期结果

base 的服务端口是 8080，ours 将其改成 9090，theirs 改成 3000 并把日志等级改成 debug。

```sh
node scripts/moonconfig.mjs merge examples/base.json examples/ours.json examples/conflict.json
```

预期：退出码 2，冲突路径 /server/port，日志等级独立合并为 debug。此输出仍是预览。

examples/decisions.json 明确选择自定义端口 9443：

```json
[{"path":"/server/port","choice":"custom","value":9443}]
```

```sh
node scripts/moonconfig.mjs resolve examples/base.json examples/ours.json examples/conflict.json examples/decisions.json
node scripts/moonconfig.mjs resolve examples/base.json examples/ours.json examples/conflict.json examples/decisions.json --output value
node scripts/moonconfig.mjs resolve examples/base.json examples/ours.json examples/conflict.json examples/decisions.json --output patch
```

预期：退出码 0，最终端口 9443，日志等级 debug，报告 clean=true、verified=true。补丁第一步是根路径 test，其 value 为整个 base，后续是修改操作。resolve 内部已经回放补丁并比较最终结果。

直接以 UTF-8 安全保存补丁，再使用 apply 回放到 base：

```sh
node scripts/moonconfig.mjs resolve examples/base.json examples/ours.json examples/conflict.json examples/decisions.json --output patch --save reviewed-patch.json
node scripts/moonconfig.mjs apply examples/base.json reviewed-patch.json --save reviewed-config.json
```

目标文件必须不存在；CLI 不会覆盖输入或之前保存的结果。无效输入不生成输出。保存冲突预览仍返回退出码 2。如果 base 的任何字段发生语义变化，根 test 失败，退出码 1，不输出部分配置。键顺序、空白和等值数字写法变化不会触发语义校验失败。

## 显式决策

choice 可为 base、ours、theirs、delete、custom；custom 必须携带合法 JSON value。网页传输自定义 JSON 时使用 value_text 字符串，避免 JavaScript 先把数字转成 Number。删除与 custom/null 不同。

网页确认并回放成功后，可点击“下载决策文件”，得到 moonconfig-decisions.json。该文件仅包含已确认的路径和选择；自定义 JSON 保存在 value_text 字符串里，大整数不会被 JavaScript 舍入。CLI 的 resolve 可直接读取它；需要使用与网页审查时相同的 base/ours/theirs 文件。更改输入或决策会隐藏导出入口，必须重新确认后下载；无冲突时导出空数组。

```sh
node scripts/moonconfig.mjs resolve BASE.json OURS.json THEIRS.json moonconfig-decisions.json --output value --save reviewed-config.json
```

决策文件自身不保存原版指纹。若输入发生变化，即使路径相同，旧选择也不能证明已经审查过新值；应重新人工确认。校验补丁才带有原版前置 test。

每个冲突都必须且只能有一个决策。未知路径、重复决策、遗漏决策、非法 JSON、超出资源限制，以及删除文档根都会失败。未修改的独立字段会继续保留。

## CI 接入

CI 可直接使用 CLI 退出码：merge 返回 2 时阻止自动使用预览；resolve 在决策缺失或非法时返回 1；有完整决策时生成最终配置与受 base 校验保护的补丁。

[工作流模板](ci-example.yml) 使用本仓库固定样例生成最终配置和补丁。替换输入路径后可用于项目的配置审查。CLI 与此流程已通过真实进程集成测试；尚未远程执行模板。

测试命令：

```sh
npm run build
node --test tests/cli.test.mjs tests/workflow.test.mjs
```

tests/workflow.test.mjs 实际启动 CLI，覆盖冲突阻断、完整决策、精确大整数输出、独立字段保留、删除/null、补丁导出和旧 base 拒绝，并检查输入文件未被覆盖。

## 独立 MoonBit 消费

examples/consumer 是独立模块，依赖公开接口并通过 moon.work 解析本地库。其主程序和两个黑盒测试不使用库的内部函数：

```sh
cd examples/consumer
moon run cmd/main --target js
moon test --package forey217/config-gate-example --target js --deny-warn
```

本例证明跨模块接入与运行。另一独立目录已从 Mooncakes 安装 0.2.0 并完成验证，见 [安装记录](registry-verification.md)；外部用户采用尚未验证。
