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
   reference in `nlloc_sample_test_frozen_20220513/original_output/alaska.hyp`,
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

### Roadmap

Planned extensions (see the modernization plan):
- GLOBAL (teleseismic) mode dataset.
- Additional sample datasets and more captured output fields.
- A GitHub Actions workflow running this script on every push / pull request.
