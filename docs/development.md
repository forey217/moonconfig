# 开发与验证记录

## 2026-10-02：v0.1 原型

工具链：moon 0.1.20260920，moonc v0.10.14+7d59c7ec9，Node.js v24.21.0；开发环境 Windows。

核心功能覆盖 diff、六种 JSON Patch 操作、JSON Pointer、精确十进制比较和三方合并。构建后的同一 MoonBit 引擎由 Node CLI 和浏览器工作台调用。项目没有 npm 依赖。

## 可复现检查

```sh
moon fmt --check
moon check --target js --deny-warn
moon test --target js --deny-warn
moon test --target wasm-gc --deny-warn
moon info
npm run build
node --test tests/cli.test.mjs
```

132 个 MoonBit 用例包括 108 个启用的上游 JSON Patch 用例与 24 个项目用例。矩阵用例额外覆盖 121 组 diff/apply 往返及单方修改合并性质。项目用例包括删除/null、类型变更、深拷贝、错误路径和大补丁回退。CLI 测试启动真实子进程，覆盖数字精度、文件读写、冲突退出码和无效输入。

上游测试来源和生成方式见 THIRD_PARTY_NOTICES.md。使用仓库内的固定测试数据运行 `python scripts/generate_conformance.py` 后执行 `moon fmt`，即可重新生成 conformance_wbtest.mbt。

## 浏览器手动检查

独立修改自动合并；同字段冲突展示具体路径和三份候选；diff 保留大整数；失败的 test 显示错误并禁用结果复制/下载。检查窄屏单列与宽屏三列布局。

## 尚未验证或完成

本地原生测试因缺少 cc/gcc/clang 无法运行。CI 配置包括 Linux 原生测试；配置存在不等于远程检查已经成功。尚未进行生产负载、恶意超深解析、可访问性完整审计、赛事验收或 Mooncakes 发布。

## 2026-10-02：v0.2 冲突审查流程

新增 Choice、Decision、ResolvedMerge、resolve、guarded_diff、parse_decisions 和精确显示投影。解决接口从三份文档重算冲突，检查完整性后应用决策，生成以整个 base 的 test 为前置条件的补丁，并回放比较结果。数组保持整体处理。

工作区 150 个 MoonBit 测试：库 148 个，独立消费模块 2 个。Node 集成测试共 3 个，实际调用 CLI 完成预览、决策、最终配置和补丁导出、回放、旧 base 拒绝及输入不可变检查。CLI 新增 resolve 和 --output report/value/patch。

网页实际检查包括未选决策按钮禁用、非法自定义 JSON 拒绝、9443 自定义端口确认及最终配置下载文件核对。另检查删除/null、大整数候选和导出精度、修改输入清除决策，以及宽/窄屏布局。201 个冲突会明确提示使用 CLI，禁用网页确认且不生成最终配置。

独立消费模块通过自己的 moon.mod 声明版本依赖，由 moon.work 解析本地库。公开 API 黑盒测试和示例程序已运行，不使用库内部函数。Mooncakes 安装与外部采用尚未验证。

另将 `moon package` 产出的 v0.2.0 发布包解压到新的目录，由独立消费模块导入该归档中的库，两个黑盒测试及主程序均通过。发布包不包含开发工作区和消费模块。此检查验证归档完整性及本地依赖运行，不代替 Mooncakes 安装验证。

本机测量见 benchmark.md。CI 模板见 ci-example.yml；远程运行、原生测试、公开包发布及赛事报名仍未完成。
