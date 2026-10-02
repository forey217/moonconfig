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
