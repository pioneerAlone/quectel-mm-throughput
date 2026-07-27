# Compatibility Matrix

## patch-management

| MM 版本 | upstream commit | patch 状态 | 已知问题 |
|---------|-----------------|-----------|---------|
| 1.22.0  | `03f786ce66360d67c669f4f122f8aa458e6f01ea` | ✅ 已测试 | 无 |
| 1.24.0  | `dfa41adf391b090720fb1ea56d884f61ea7fba29` | 🟡 占位（待 rebase） | 等 `bump-upstream.sh` + 人工适配 |

## runtime

| MM 版本 | adapter 状态 | 已知问题 |
|---------|-------------|---------|
| 1.22.x  | ✅ 已实现 | 无 |
| 1.24.x  | 🟡 占位 | 等实际跑通后填常量 |

## ModemManager 版本说明

- **1.22.0**：2024-04-30 发布（[announce](https://lists.freedesktop.org/archives/modemmanager-devel/2024-April/msg00003.html)），是本项目的起点版本
- **1.24.0**：下一个 major 系列的发布，patch 待适配

## 维护原则

- 任何新上游 MM 版本发布后，由 [`scripts/bump-upstream.sh`](./scripts/bump-upstream.sh) 自动建立占位目录
- 占位文件必须由人工 rebase 并将 `tested_at` / `tested_by` 字段填入后才视为"已测试"
- 兼容性矩阵由 [`scripts/check-compat-matrix.sh`](./scripts/check-compat-matrix.sh) 校验一致性