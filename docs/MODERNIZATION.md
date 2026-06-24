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
  - With the project's own flags (`-Wall`), a clean-environment build emits only
    **5 warnings**. The large warning counts seen previously came from extra flags
    (`-Wdeclaration-after-statement`, `-Wextra`, …) injected via a developer's
    shell `CFLAGS`, not from the repository — the code is much cleaner than it
    first appears.
  - **31 `-Wunused-result`** — genuine latent bugs: ignored return values of
    `fread`/`fscanf`/`fgets`/`system`. Addressed in Phase 1.
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

## Progress

- [x] **Phase 0** — dependency-light regression harness (`tests/run_regression.sh`)
      plus a GitHub Actions workflow (`.github/workflows/regression.yml`) that
      builds and runs it on every push / PR.
- [x] **Phase 1** — fixed all 31 `-Wunused-result` latent I/O bugs.
- [x] **Phase 1b** — removed dead backup/duplicate files (8.3k lines).
- [x] **Phase 1c** — fixed two real bugs found via warnings: a stack
      buffer-overflow risk in `NLDiffLoc.c` (`fgets` size > buffer) and invalid
      pointer-vs-`0` allocation checks in `alomax_matrix.c`.
- [x] **Phase 0 follow-up** — added a GLOBAL/teleseismic regression test
      (`tests/run_regression_global.sh`) using committed ak135 grid fixtures, so
      it runs in CI without Java/TauP. Covers 5 teleseismic events; deterministic
      and verified against a frozen reference. This widens coverage beyond the
      single non-GLOBAL path, de-risking Phase 2.
- [~] **Phase 2** — string safety (in progress). Golden-path files done
      (`velmod.c`, `GridLib.c`, `NLLocLib.c`, `GridMemLib.c`): ~430 `sprintf`/
      `strcpy` calls into in-scope array buffers converted to bounded `snprintf`
      using `sizeof(destination)`. Remaining within those files: a few `sprintf`
      into function-parameter pointers of unknown size, and ~11 `strcat` calls —
      both need caller analysis / a bounded-append form and are deferred.
      Off-golden-path tool files (Grid2GMT, Vel2Grid3D, …) still to do.
- [ ] **Phase 3 / 4** — modularize, then encapsulate globals.

## Phased roadmap

### Phase 0 — Strengthen the safety net (enabler) — done
- A dependency-light regression harness runs the core pipeline
  (`Vel2Grid` → `Grid2Time` → `Time2EQ` → `NLLoc`) and diffs against the frozen
  reference, **without** requiring GMT or Java; CI runs it automatically.
- Follow-up: expand the corpus — GLOBAL (teleseismic) mode, additional sample
  datasets, more captured output fields.

### Phase 1 — Zero-/low-risk correctness and hygiene — done
- Fixed `-Wunused-result` I/O bugs, removed dead backups, fixed two real bugs.

### Phase 2 — String safety
- Convert `sprintf` → `snprintf` and bound `strcpy`/`strcat` against their
  destination buffer sizes, verifying buffer sizes per site (not a blind sed:
  `sizeof` is only correct for array buffers, not pointers). Each change verified
  against the regression net. Best scoped to golden-path files first.

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
