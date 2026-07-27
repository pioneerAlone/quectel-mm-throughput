#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0+
#
# 1.24.sh — adapter constants for ModemManager 1.24.x (PLACEHOLDER).
#
# Verified baseline: dfa41adf391b090720fb1ea56d884f61ea7fba29.
#
# To finalize this adapter:
#   1. Run `mmcli --output-keyvalue -L` on a system with MM 1.24.x.
#   2. Run `mmcli --output-keyvalue -m 0 -b` and inspect the field names.
#   3. Update the constants below to match the actual 1.24.x output.
#   4. Test by sourcing this file from a debug shell.
#
# The current values are COPIED from adapters/1.22.sh as a starting point.
# Some may need adjustment; treat them as untested until verified.

# Detection pattern
MM_ADAPTER_VERSION_PATTERN='^1\.24\.'

# Modem DBus path
MM_MODEM_PATH_REGEX='/org/freedesktop/ModemManager1/Modem/[0-9]+'

# Bearer fields — TODO: verify against actual MM 1.24.x output
MM_BEARER_KEYS=(connected interface address prefix gateway dns mtu)

# Multiplex keyword — TODO: verify (may have been renamed)
MM_BEARER_MULTIPLEX_KEY='multiplex'
MM_BEARER_MULTIPLEX_VALUE='required'

# Default APN
MM_DEFAULT_APN='3gnet'

# WDA endpoint defaults — TODO: verify
MM_WDA_EP_TYPE='hsusb'
MM_WDA_EP_IFACE='4'
MM_WDA_LINK_LAYER='raw-ip'

# Ethtool aggregation time
MM_ETHTOOL_AGGR_TIME_USECS='1000'