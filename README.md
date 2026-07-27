# quectel-mm-throughput

> Uplink Data Aggregation patches + runtime scripts for Quectel modules on ModemManager.

ModemManager 通过 QMI 协议控制 Quectel 模组（EG25、EG21、EM060、RG500Q 等）时，默认不启用 Uplink Data Aggregation（UL AGG），数传吞吐率受限。本仓库提供两件互补的工具：

1. **`patches/`** — 给上游 ModemManager 源码打补丁，启用 UL AGG 默认值（4096 bytes / 11 datagrams）。构建时集成。
2. **`runtime/`** — 在目标设备上运行 `mmcli.sh`，完成 WDA 数据格式协商、MTU 调整、ethtool 上联聚合配置、IP / DNS 设置。

## 上游

| 角色 | 地址 |
|------|------|
| Canonical | <https://gitlab.freedesktop.org/mobile-broadband/ModemManager> |
| GitHub 镜像（CI 用） | <https://github.com/linux-mobile-broadband/ModemManager> |
| 邮件列表 | `modemmanager-devel@lists.freedesktop.org` |

## 兼容性矩阵

详见 [SUPPORTED.md](./SUPPORTED.md)。

## 快速开始

```bash
# 1. 拉本仓库
git clone https://github.com/pioneerAlone/quectel-mm-throughput.git
cd quectel-mm-throughput

# 2. 应用 patch 到上游 MM 源码（假设 MM 1.22.0 已下载）
git clone --depth 1 --branch 1.22.0 \
  https://github.com/linux-mobile-broadband/ModemManager.git upstream
cd upstream
for p in ../patches/1.22.0/*.patch; do git apply "$p"; done

# 3. 在设备上跑 runtime 脚本（设备侧）
scp -r runtime/* user@device:/tmp/qmiquectel-throughput/
ssh user@device 'sudo /tmp/qmiquectel-throughput/mmcli.sh'
```

## 仓库结构

```
patches/      # Build-time: 每个上游 MM 版本一个目录，01-anchor + 02-ul-agg 双 patch 拆分
runtime/      # Run-time: 在目标设备上跑的主入口 + lib/ + adapters/
scripts/      # 仓库维护脚本（升级 / 校验）
tests/        # bats 测试覆盖 mmcli 输出解析
docs/         # 锚点策略 / 上游追踪 / 模组适配说明 / 参数依据
```

详见 [docs/](./docs/)。

## 参数选取依据

UL AGG 参数（4096 bytes / 11 datagrams / 1000us）的选取依据见 [docs/rationale.md](./docs/rationale.md)。

## License

**GPL-2.0+** — 与上游 ModemManager 一致。

所有 shell 脚本、patch 与文档以 `SPDX-License-Identifier: GPL-2.0+` 标识。

由于 GPL 传染性，任何携带本补丁的下游二进制产物必须配套发布对应源码或提供获取源码的方式。

## 贡献

请通过 GitHub Issues 反馈：
- **patch 不工作**：使用 `.github/ISSUE_TEMPLATE/new-mm-version.md` 模板，注明 MM 版本、模组型号、错误信息
- **runtime 脚本问题**：使用 `.github/ISSUE_TEMPLATE/mmcli-runtime-issue.md` 模板