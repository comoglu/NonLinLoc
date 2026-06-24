# NonLinLoc Modernization Plan

This document describes a **behavior-preserving, incrementally-verified** plan to
modernize, simplify, and harden the NonLinLoc C codebase. It is maintained on the
[`comoglu/NonLinLoc`](https://github.com/comoglu/NonLinLoc) fork.

## Guiding principles

1. **Never change scientific results without an explicit, reviewed reason.** Every
   change is gated by a regression test that compares program output against a
   frozen reference. A passing run means byte-for-byte identical locations and
   uncertainties (excluding date stamps).
2. **Small, reviewable steps.** Each pull request does one kind of thing
   (hygiene, warning fixes, a single module extraction). No mixed-concern PRs.
3. **The test net comes first.** Refactoring is only as safe as the oracle that
   validates it. We expand the regression corpus *before* large structural change.
4. **Domain expert owns "correct".** The maintainer (A. Lomax) validates that
   reference outputs are seismologically correct; tooling/AI performs the
   mechanical transformation and proves outputs are unchanged.

## Current state (baseline assessment)

- **Builds clean**: CMake + `make` produce 0 errors, ~360 warnings.
  - ~315 `-Wdeclaration-after-statement` — stylistic (C89 vs C99), no risk.
  - **31 `-Wunused-result`** — genuine latent bugs: ignored return values of
    `fread`/`fscanf`/`fgets`/`system`. These are addressed in Phase 1.
- **Concentrated complexity**: `NLLocLib.c` (~15k lines) and `GridLib.c` (~7k
  lines) hold most of the logic.
- **Pervasive global state**: ~100+ file-scope globals; the code is non-reentrant
  and not thread-safe. Parallelism is achieved by launching separate OS processes.
- **String-handling surface**: heavy use of `sprintf`/`strcpy`/`strcat` into
  fixed buffers (overflow risk; no `gets`).
- **Repo hygiene**: duplicated source trees and committed backup/cache files
  inflate the apparent size.
- **Test oracle exists**: the `nlloc_sample` run diffs against
  `nlloc_sample_test_frozen_20220513`. Current `HEAD` reproduces it exactly.

## Phased roadmap

### Phase 0 — Strengthen the safety net (enabler)
- Add a dependency-light regression harness that runs the core pipeline
  (`Vel2Grid` → `Grid2Time` → `Time2EQ` → `NLLoc`) and diffs against the frozen
  reference, **without** requiring GMT or Java. *(Started in this PR.)*
- Follow-up: expand the corpus — GLOBAL (teleseismic) mode, additional sample
  datasets, more captured output fields — and wire it into CI (GitHub Actions).

### Phase 1 — Zero-/low-risk correctness and hygiene
- **Fix `-Wunused-result` I/O bugs** — check return values; report short reads /
  failures instead of silently continuing. Success path unchanged. *(This PR.)*
- Repo hygiene (separate PR): remove duplicated source trees and committed
  `*_OLD`, `.ORIG`, `*OUT_OF_DATE*`, and `CMakeCache_OLD` artifacts.

### Phase 2 — String safety
- Mechanically convert `sprintf` → `snprintf` and bound `strcpy`/`strcat` against
  their destination buffer sizes. Each change verified against the regression net.

### Phase 3 — Modularize the monoliths
- Split `NLLocLib.c` along its existing functional seams (I/O, search methods,
  grid handling, statistics) into separate translation units with clear headers.
  Pure code movement, no logic change, verified at each step.

### Phase 4 — Encapsulate global state
- Group related globals into context structs threaded through call sites. This is
  the highest-value, highest-effort change; it enables in-process parallelism. Done
  last, on top of the strengthened test net.

## How to run the regression test

```
tests/run_regression.sh
```

See [tests/README.md](../tests/README.md) for details.
