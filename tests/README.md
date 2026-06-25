# NonLinLoc regression tests

## `run_regression.sh`

A dependency-light regression test that guards against unintended changes to
location results. It is the safety net for the modernization work described in
[../docs/MODERNIZATION.md](../docs/MODERNIZATION.md).

### What it does

1. Builds the core tools if they are not already present in `src/bin/`.
2. Runs the core computational pipeline on the bundled `alaska` sample dataset,
   in an isolated temporary directory:
   `Vel2Grid` → `Grid2Time` → `Time2EQ` → `NLLoc`.
3. Compares the combined location output (`loc/alaska.hyp`) against the frozen
   reference in `nlloc_sample_test_frozen_20260625/original_output/alaska.hyp`,
   ignoring the date-stamped `SIGNATURE` line.

A passing run means the locations and uncertainties are **byte-for-byte identical**
to the reference — i.e. behavior is preserved.

### Why a separate script (vs. `run_tests.bash`)

The existing `run_nlloc_sample.sh` interleaves the computation with GMT (PostScript
plots) and Java (Seismicity Viewer) visualization steps. Those require external
software and do not affect the location results. This harness runs only the
computational steps, so it can run unattended (e.g. in CI) on a machine with just a
C toolchain and CMake.

### Usage

```bash
tests/run_regression.sh
```

Use a custom tools directory:

```bash
NLL_BIN=/path/to/bin tests/run_regression.sh
```

Exit status is `0` on match and non-zero on regression (or build/run failure),
so it can be used directly as a CI gate.

## `run_regression_global.sh`

GLOBAL-mode (teleseismic) counterpart. Runs `NLLoc` on the bundled `neic` sample
(5 well-known teleseismic events: Fiji, S. East Pacific Rise, Arkansas, Morocco
2004, S. Java 2006) using the committed ak135 spherical-earth travel-time grids
in `nlloc_global_sample/taup/ak135/`, and compares the per-event output against
`tests/reference/global/`.

Those grids were generated once with the legacy `TauP_NLL` tool (TauP is Java).
They are committed so the test stays dependency-light — at test time it needs
only a C toolchain + CMake, no Java/TauP. To regenerate them, see
`nlloc_global_sample/taup/TauP_Table_NLL.sh`.

```bash
tests/run_regression_global.sh
```

## `run_regression_ssst.sh`

NLL-SSST test on a real, complex dataset: the **Parkfield 2004** example (383
events, 38 stations) from the NLL-SSST-coherence procedure. Runs
`Vel2Grid` → `Grid2Time` → `NLLoc` on the committed `nlloc_ssst_sample/` fixture
and checks every located epicentre and depth against `tests/reference/ssst/`
within a tolerance (default 250 m).

Unlike the alaska/global tests, this one is **tolerance-based**, for a concrete
reason: NLLoc's global search is stochastic and the reference was generated on
macOS, so identical source on another platform gives numerically equivalent but
not bit-identical locations (observed max ~80 m, vs the 500 m grid spacing). The
example's own README expects output "identical or numerically similar". This is a
platform property, not a code property — modernized and unmodified NonLinLoc
produce byte-identical output on the same machine; both differ from the macOS
reference by the same ~80 m. The 250 m tolerance sits well above that noise and
far below any real regression (which moves locations by grid cells / km).

It takes a few minutes (383 events). The fixture is only the picks + control
files + reference (~3 MB); the full example (waveforms, QuakeML, coherence stage)
is not needed for the C-code regression.

```bash
tests/run_regression_ssst.sh          # default 250 m tolerance
TOL_M=150 tests/run_regression_ssst.sh
```

All three scripts run in CI via `.github/workflows/regression.yml`.

### Roadmap

Planned extensions (see the modernization plan):
- Add the SSST relocation stage (iterative `Loc2ssst`) to the Parkfield test.
- Additional sample datasets and more captured output fields.
