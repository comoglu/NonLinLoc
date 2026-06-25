#!/usr/bin/env bash
#
# GLOBAL-mode (teleseismic) regression test for NonLinLoc.
#
# Runs NLLoc on the bundled global "neic" sample (5 well-known teleseismic
# events) using the committed ak135 spherical-earth travel-time grids, and
# compares the per-event location output against the frozen reference in
#   tests/reference/global/
#
# The ak135 grids in nlloc_global_sample/taup/ak135/ were generated once with
# the legacy TauP_NLL tool; committing them keeps this test dependency-light
# (no Java / TauP needed at test time, only a C toolchain + CMake).
#
# Exit status: 0 = outputs match reference (behavior preserved); non-zero = regression.
#
# Usage:
#   tests/run_regression_global.sh
#   NLL_BIN=/path/to/bin tests/run_regression_global.sh
#
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
BIN_DIR="${NLL_BIN:-${REPO_ROOT}/src/bin}"
REF_DIR="${REPO_ROOT}/tests/reference/global"

# Build NLLoc if missing.
if [ ! -x "${BIN_DIR}/NLLoc" ]; then
    echo "[regression-global] NLLoc missing in ${BIN_DIR}, building..."
    mkdir -p "${REPO_ROOT}/src/bin"
    ( cd "${REPO_ROOT}/src" && rm -f CMakeCache.txt && cmake . >/dev/null && make -j"$(nproc)" >/dev/null ) \
        || { echo "[regression-global] BUILD FAILED"; exit 2; }
fi
export PATH="${BIN_DIR}:${PATH}"

# Run in an isolated work dir.
WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT
cp -r "${REPO_ROOT}/nlloc_global_sample/." "${WORK}/"
cd "${WORK}"
mkdir -p loc

echo "[regression-global] running NLLoc in ${WORK}"
if ! NLLoc run/neic_global.in > "${WORK}/NLLoc.log" 2>&1; then
    echo "[regression-global] FAIL: NLLoc exited non-zero. Last lines:"
    tail -10 "${WORK}/NLLoc.log"
    exit 1
fi

# Compare each frozen reference event against the produced output.
# The SIGNATURE line carries the run date/time and is expected to differ.
strip() { grep -v -e 'SIGNATURE' "$1"; }

fail=0
ncmp=0
for ref in "${REF_DIR}"/*.hyp; do
    name="$(basename "${ref}")"
    out="${WORK}/loc/${name}"
    if [ ! -f "${out}" ]; then
        echo "[regression-global] FAIL: expected output ${name} not produced"
        fail=1
        continue
    fi
    d="$(diff <(strip "${ref}") <(strip "${out}") | grep -c '^[<>]')"
    ncmp=$((ncmp + 1))
    if [ "${d}" -ne 0 ]; then
        echo "[regression-global] FAIL: ${name} differs by ${d} line(s)"
        diff <(strip "${ref}" | grep GEOGRAPHIC) <(strip "${out}" | grep GEOGRAPHIC) | head
        fail=1
    fi
done

echo "----------------------------------------------------------------------"
if [ "${fail}" -eq 0 ]; then
    echo "[regression-global] PASS: all ${ncmp} teleseismic locations identical to frozen reference"
    exit 0
else
    echo "[regression-global] FAIL: GLOBAL-mode output differs from frozen reference"
    exit 1
fi
