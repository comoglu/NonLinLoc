#!/usr/bin/env bash
#
# NLL-SSST regression test (Parkfield 2004 example, initial-location stage).
#
# Runs the NonLinLoc location pipeline (Vel2Grid -> Grid2Time -> NLLoc) on the
# Parkfield 2004 dataset (383 events, 38 stations) from the NLL-SSST-coherence
# example, and checks that every located epicentre and depth agrees with the
# reference in tests/reference/ssst/ within a tolerance.
#
# Why tolerance (not byte-exact): NLLoc's global search is stochastic, and the
# reference output was generated on macOS. Identical source on a different
# platform yields locations that are numerically equivalent but not bit-identical
# (observed max difference ~80 m, far below the 500 m grid spacing). The example's
# own README states output should be "identical or numerically similar". This
# behaviour is a property of the platform/algorithm, not of any one change:
# modernized and unmodified code produce byte-identical output on the same
# machine. The tolerance below sits well above platform noise and far below any
# real regression (which shifts locations by grid cells / kilometres).
#
# Exit status: 0 = within tolerance; non-zero = regression (or build/run failure).
#
# Usage:
#   tests/run_regression_ssst.sh
#   NLL_BIN=/path/to/bin TOL_M=250 tests/run_regression_ssst.sh
#
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
BIN_DIR="${NLL_BIN:-${REPO_ROOT}/src/bin}"
REF="${REPO_ROOT}/tests/reference/ssst/Parkfield_2004.sum.grid0.loc.hyp"
TOL_M="${TOL_M:-250}"   # tolerance in metres (epicentre and depth)
CTRL="Parkfield_2004_Oppenheimer_1993.in"

for t in Vel2Grid Grid2Time NLLoc; do
    if [ ! -x "${BIN_DIR}/${t}" ]; then
        echo "[regression-ssst] building tools..."
        ( cd "${REPO_ROOT}/src" && rm -f CMakeCache.txt && cmake . >/dev/null && make -j"$(nproc)" >/dev/null ) \
            || { echo "[regression-ssst] BUILD FAILED"; exit 2; }
        break
    fi
done
export PATH="${BIN_DIR}:${PATH}"

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT
cp -r "${REPO_ROOT}/nlloc_ssst_sample/." "${WORK}/"
cd "${WORK}"
mkdir -p out/Oppenheimer1993/model out/Oppenheimer1993/time out/Oppenheimer1993/loc

echo "[regression-ssst] running pipeline (383 events; this takes a few minutes)..."
for step in Vel2Grid Grid2Time NLLoc; do
    if ! ${step} "${CTRL}" > "${WORK}/${step}.log" 2>&1; then
        echo "[regression-ssst] FAIL: ${step} exited non-zero:"; tail -8 "${WORK}/${step}.log"; exit 1
    fi
done

OUT="${WORK}/out/Oppenheimer1993/loc/Parkfield_2004.sum.grid0.loc.hyp"
[ -f "${OUT}" ] || { echo "[regression-ssst] FAIL: no summary output produced"; exit 1; }

nref=$(grep -c GEOGRAPHIC "${REF}")
nout=$(grep -c GEOGRAPHIC "${OUT}")
if [ "${nref}" -ne "${nout}" ]; then
    echo "[regression-ssst] FAIL: event count ${nout} != reference ${nref}"; exit 1
fi

# Pair events in order (deterministic glob order on both platforms) and compute
# max epicentre/depth difference in metres.
result=$(paste \
    <(grep GEOGRAPHIC "${REF}" | awk '{print $10, $12, $14}') \
    <(grep GEOGRAPHIC "${OUT}" | awk '{print $10, $12, $14}') | \
  awk -v tol="${TOL_M}" '
    NF==6 {
        lat=$1; dla=($1-$4); dlo=($2-$5); dz=($3-$6);
        dla=dla<0?-dla:dla; dlo=dlo<0?-dlo:dlo; dz=dz<0?-dz:dz;
        mlat=dla*111195.0;                      # deg lat -> m
        mlon=dlo*111195.0*cos(lat*3.14159265/180.0);  # deg lon -> m
        mz=dz*1000.0;                           # km -> m
        if (mlat>maxlat) maxlat=mlat;
        if (mlon>maxlon) maxlon=mlon;
        if (mz>maxz)   maxz=mz;
        if (mlat>tol||mlon>tol||mz>tol) nbad++;
        n++;
    }
    END {
        printf "%d %.1f %.1f %.1f %d", n, maxlat, maxlon, maxz, nbad+0;
    }')
read -r n maxlat maxlon maxz nbad <<< "${result}"

echo "----------------------------------------------------------------------"
echo "[regression-ssst] events: ${n}   tolerance: ${TOL_M} m"
echo "  max |dLat|=${maxlat} m   max |dLon|=${maxlon} m   max |dDepth|=${maxz} m"
if [ "${nbad}" -eq 0 ]; then
    echo "[regression-ssst] PASS: all ${n} Parkfield locations within ${TOL_M} m of reference"
    exit 0
else
    echo "[regression-ssst] FAIL: ${nbad} event(s) exceed ${TOL_M} m tolerance"
    exit 1
fi
