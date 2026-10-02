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

将补丁输出以 UTF-8 保存，再使用 apply 回放到 base。如果 base 的任何字段发生语义变化，根 test 失败，退出码 1，stdout 不输出部分配置。键顺序、空白和等值数字写法变化不会触发语义校验失败。

## 显式决策

choice 可为 base、ours、theirs、delete、custom；custom 必须携带合法 JSON value。网页传输自定义 JSON 时使用 value_text 字符串，避免 JavaScript 先把数字转成 Number。删除与 custom/null 不同。

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

当前证明的是跨模块接入与运行，尚未证明 Mooncakes 安装或外部用户采用。
