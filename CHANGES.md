# Changelog

本项目所有重要变更记录于此。日期格式 `YYYY-MM-DD`。

## v0.1.0 — 2026-07-27

### Initial release

#### patches/

- **1.22.0/**
  - `01-anchor.patch`：插入 `QUECTEL_THROUGHPUT_ANCHOR` 注释，提供稳定字符串锚点
  - `02-ul-agg.patch`：在 `src/mm-port-qmi.c` 的 `sync_wda_data_format` 中添加 UL AGG 设置：
    - `uplink_data_aggregation_max_size = 4096`
    - `uplink_data_aggregation_max_datagrams = 11`
  - `source.json`：锁定上游 commit `03f786ce66360d67c669f4f122f8aa458e6f01ea`

- **1.24.0/**
  - `01-anchor.patch` / `02-ul-agg.patch` / `source.json`：占位文件，等 `scripts/bump-upstream.sh` 流程与人工 rebase

#### runtime/

- 顶层入口 `runtime/mmcli.sh`（GPL header）
- `runtime/lib/` 模块拆分：`version-detect.sh`、`mmcli-parser.sh`、`qmiquectel-config.sh`、`net-setup.sh`
- `runtime/adapters/` 版本适配：`1.22.sh`（已实现）、`1.24.sh`（占位）、`_loader.sh`（动态加载）

#### scripts/

- `bump-upstream.sh`：新上游版本号 → 占位目录
- `verify-anchor.sh`：校验锚点串存在性
- `check-compat-matrix.sh`：校验 SUPPORTED.md 与实际目录一致

#### tests/

- bats 测试覆盖 `mmcli-parser.sh` 与 `version-detect.sh`
- fixtures：`mmcli-1.22.0-L.out`、`mmcli-1.22.0-bearer.out`、`mmcli-1.24.0-L.out`

#### docs/

- `rationale.md`：4096/11/1000us 参数依据
- `anchor-strategy.md`：锚点策略详解
- `upstream-tracking.md`：上游追踪机制
- `runtime-portability.md`：runtime 跨 MM 版本脆弱点
- `quectel-modules.md`：EG25/EG21/EM060/RG500Q 兼容性

#### .github/

- 4 个 workflow：upstream-compat、runtime-smoke、lint、check-anchor
- 2 个 issue template

#### 验证

- `git apply --check` 在 MM 1.22.0 上游源码（GitHub 镜像）上对 `patches/1.22.0/*.patch` 全部通过
- bats 测试套件通过
- shellcheck + shfmt 无 error