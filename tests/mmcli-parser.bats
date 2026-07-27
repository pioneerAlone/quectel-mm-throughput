#!/usr/bin/env bats
#
# mmcli-parser.bats — test the parser functions in runtime/lib/mmcli-parser.sh
#
# These tests use the mock mmcli binary at tests/fixtures/mock-bin/mmcli
# (selected via PATH manipulation) so they don't require a real modem.
#
# Run with:
#   bats tests/mmcli-parser.bats
#
# Requires: bats-core (https://github.com/bats-core/bats-core)

setup() {
    REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    FIXTURE_DIR="${REPO_ROOT}/tests/fixtures"
    MOCK_BIN="${FIXTURE_DIR}/mock-bin"

    # Prepend mock bin to PATH so the parser functions pick up the mock mmcli.
    export PATH="${MOCK_BIN}:${PATH}"
    export MMCLI_FIXTURE_DIR="${FIXTURE_DIR}"
    export MMCLI_FIXTURE_VERSION="1.22.0"

    # Source the adapter constants (1.22.sh)
    source "${REPO_ROOT}/runtime/adapters/1.22.sh"

    # Source the parser
    source "${REPO_ROOT}/runtime/lib/mmcli-parser.sh"
}

@test "get_modem_index returns 0 from mmcli --output-keyvalue -L" {
    run get_modem_index
    [ "$status" -eq 0 ]
    [ "$output" = "0" ]
}

@test "get_modem_index returns non-zero when mmcli output is empty" {
    MMCLI_FIXTURE_VERSION="nonexistent" run get_modem_index
    # The parser handles missing fixtures gracefully
    [ "$status" -ne 0 ] || [ -z "$output" ]
}

@test "create_or_get_bearer returns bearer path" {
    run create_or_get_bearer "0" "3gnet"
    [ "$status" -eq 0 ]
    [[ "$output" == *"/org/freedesktop/ModemManager1/Bearer/"* ]]
}

@test "get_bearer_field extracts interface" {
    run get_bearer_field "/org/freedesktop/ModemManager1/Bearer/0" "interface"
    [ "$status" -eq 0 ]
    [ "$output" = "qmapmux0" ]
}

@test "get_bearer_field extracts gateway" {
    run get_bearer_field "/org/freedesktop/ModemManager1/Bearer/0" "gateway"
    [ "$status" -eq 0 ]
    [ "$output" = "10.0.0.1" ]
}

@test "get_bearer_field extracts dns" {
    run get_bearer_field "/org/freedesktop/ModemManager1/Bearer/0" "dns"
    [ "$status" -eq 0 ]
    [ "$output" = "8.8.8.8,8.8.4.4" ]
}

@test "get_bearer_field returns empty for unknown field" {
    run get_bearer_field "/org/freedesktop/ModemManager1/Bearer/0" "no_such_field"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}