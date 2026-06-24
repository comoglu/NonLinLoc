#!/usr/bin/env bash
#
# Dependency-light regression test for NonLinLoc.
#
# Runs the core computational pipeline on the bundled "alaska" sample dataset
#   Vel2Grid -> Grid2Time -> Time2EQ -> NLLoc
# and compares the resulting location output against the frozen reference in
#   nlloc_sample_test_frozen_20220513/original_output/
#
# Unlike nlloc_sample/run_nlloc_sample.sh, this does NOT require GMT or Java:
# the visualization steps are intentionally omitted because they do not affect
# the location results being validated.
#
# Exit status: 0 = outputs match reference (behavior preserved); non-zero = regression.
#
# Usage:
#   tests/run_regression.sh            # uses src/bin tools, builds if missing
#   NLL_BIN=/path/to/bin tests/run_regression.sh
#
set -u

# --- locate repo root and tools ------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
BIN_DIR="${NLL_BIN:-${REPO_ROOT}/src/bin}"

REQUIRED_TOOLS=(Vel2Grid Grid2Time Time2EQ NLLoc)

# Build the tools if any are missing.
missing=0
for t in "${REQUIRED_TOOLS[@]}"; do
    [ -x "${BIN_DIR}/${t}" ] || missing=1
done
if [ "${missing}" -ne 0 ]; then
    echo "[regression] tools missing in ${BIN_DIR}, building..."
    mkdir -p "${REPO_ROOT}/src/bin"
    ( cd "${REPO_ROOT}/src" && rm -f CMakeCache.txt && cmake . >/dev/null && make -j"$(nproc)" >/dev/null ) \
        || { echo "[regression] BUILD FAILED"; exit 2; }
fi
export PATH="${BIN_DIR}:${PATH}"

# --- run the pipeline in an isolated work dir ---------------------------------
WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT
cp -r "${REPO_ROOT}/nlloc_sample/." "${WORK}/"
cd "${WORK}"
mkdir -p model time obs_synth loc gmt

CTRL="run/nlloc_sample.in"
echo "[regression] running pipeline in ${WORK}"
for step in "Vel2Grid ${CTRL}" "Grid2Time ${CTRL}" "Time2EQ ${CTRL}" "NLLoc ${CTRL}"; do
    name="${step%% *}"
    if ! ${step} > "${WORK}/${name}.log" 2>&1; then
        echo "[regression] FAIL: ${name} exited non-zero. Last lines:"
        tail -10 "${WORK}/${name}.log"
        exit 1
    fi
done

# --- compare against the frozen reference -------------------------------------
REF="${REPO_ROOT}/nlloc_sample_test_frozen_20220513/original_output/alaska.hyp"
OUT="${WORK}/loc/alaska.hyp"

if [ ! -f "${OUT}" ]; then
    echo "[regression] FAIL: expected output ${OUT} not produced"
    exit 1
fi

# The SIGNATURE line contains the run date/time and is expected to differ.
strip() { grep -v -e 'SIGNATURE' "$1"; }

DIFF_LINES="$(diff <(strip "${REF}") <(strip "${OUT}") | grep -c '^[<>]')"

echo "----------------------------------------------------------------------"
if [ "${DIFF_LINES}" -eq 0 ]; then
    echo "[regression] PASS: location output identical to frozen reference"
    echo "             (compared $(strip "${OUT}" | wc -l) lines, SIGNATURE excluded)"
    exit 0
else
    echo "[regression] FAIL: ${DIFF_LINES} differing line(s) vs frozen reference"
    echo "             reference: ${REF}"
    echo "             produced : ${OUT}"
    echo "--- sample of differences (GEOGRAPHIC = locations) ---"
    diff <(strip "${REF}" | grep GEOGRAPHIC) <(strip "${OUT}" | grep GEOGRAPHIC) | head -20
    exit 1
fi
