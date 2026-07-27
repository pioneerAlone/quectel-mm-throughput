#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0+
#
# 1.22.sh — adapter constants for ModemManager 1.22.x
#
# This file exports CONSTANTS ONLY (no functions). Constants describe the
# mmcli output format / DBus path conventions specific to MM 1.22.x.
#
# Verified against upstream commit 03f786ce66360d67c669f4f122f8aa458e6f01ea.

# Detection pattern for this adapter (used by version-detect.sh warning logic)
MM_ADAPTER_VERSION_PATTERN='^1\.22\.'

# mmcli -L output for 1.22.x: "/org/freedesktop/ModemManager1/Modem/N (vendor) model"
MM_MODEM_PATH_REGEX='/org/freedesktop/ModemManager1/Modem/[0-9]+'

# Bearer field names in --output-keyvalue format
MM_BEARER_KEYS=(connected interface address prefix gateway dns mtu)

# --create-bearer keyword/value for QMAP multiplex (introduced stable in 1.18)
MM_BEARER_MULTIPLEX_KEY='multiplex'
MM_BEARER_MULTIPLEX_VALUE='required'

# Default APN if user did not provide MM_DEFAULT_APN env var
MM_DEFAULT_APN='3gnet'

# Default WDA endpoint (Quectel EG25 typically uses USB iface 4, raw-ip)
MM_WDA_EP_TYPE='hsusb'
MM_WDA_EP_IFACE='4'
MM_WDA_LINK_LAYER='raw-ip'

# Default ethtool aggregation time (usecs)
MM_ETHTOOL_AGGR_TIME_USECS='1000'