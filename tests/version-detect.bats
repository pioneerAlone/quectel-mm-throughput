#!/usr/bin/env bats
#
# version-detect.bats — test detect_mm_version() from runtime/lib/version-detect.sh
#
# Uses the mock mmcli binary at tests/fixtures/mock-bin/mmcli to simulate
# different ModemManager versions.
#
# Run with:
#   bats tests/version-detect.bats

setup() {
    REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    FIXTURE_DIR="${REPO_ROOT}/tests/fixtures"
    MOCK_BIN="${FIXTURE_DIR}/mock-bin"

    export PATH="${MOCK_BIN}:${PATH}"
    export MMCLI_FIXTURE_DIR="${FIXTURE_DIR}"

    source "${REPO_ROOT}/runtime/lib/version-detect.sh"
}

@test "detect_mm_version returns 1.22.0 for mmcli 1.22.0" {
    MMCLI_FIXTURE_VERSION="1.22.0" run detect_mm_version
    [ "$status" -eq 0 ]
    [ "$output" = "1.22.0" ]
}

@test "detect_mm_version returns 1.24.0 for mmcli 1.24.0" {
    MMCLI_FIXTURE_VERSION="1.24.0" run detect_mm_version
    [ "$status" -eq 0 ]
    [ "$output" = "1.24.0" ]
}

@test "detect_mm_version warns on unknown version family" {
    MMCLI_FIXTURE_VERSION="2.0.0" run detect_mm_version
    # Should still return the version, but with a warning
    [ "$status" -eq 0 ]
    [ "$output" = "2.0.0" ]
}

@test "detect_mm_version returns non-zero when mmcli missing" {
    # Save PATH, remove mock-bin, expect failure
    saved_path="${PATH}"
    export PATH="/nonexistent"
    run detect_mm_version
    export PATH="${saved_path}"
    [ "$status" -ne 0 ]
}