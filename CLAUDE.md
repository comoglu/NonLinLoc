# CLAUDE.md — AI-assisted modernization of NonLinLoc

This file documents that the modernization work on this fork is **AI-assisted**,
how it is done, and how its safety is verified. It also serves as guidance for
any future AI-assisted changes to this repository.

The phased plan and current status live in
[docs/MODERNIZATION.md](docs/MODERNIZATION.md); this file is about *how* the work
is carried out and who is responsible for what.

## Roles in this work

This modernization is AI-assisted. To be precise about who did what:

- **Human (Mustafa Comoglu)** — directs the effort and is accountable for it:
  chose the scope and order of each phase, set the hard constraint
  (behavior-preserving; no functionality removed), made the judgment calls
  (what to defer, how to package test fixtures, keeping `main` a clean mirror of
  upstream), supplied domain tooling and context (the TauP / `TauP_NLL` grids),
  and spot-checks and reviews the work. He does not hand-author the diffs.

- **AI (Claude)** — performs the work under that direction: code investigation,
  the string / I-O transformations, the regression harness and tests, running
  the verification, and writing the commit messages and docs. Bulk conversions
  were applied via a guarded scripted transformation, inspected on a copy before
  being kept.

- **How behavior preservation is verified** — every change is gated by the
  regression tests, which re-run the full location pipeline and compare the
  located hypocentres against frozen references in regional, teleseismic and
  SSST modes, within a tolerance well below any real regression. (Comparison is
  on the maximum-likelihood hypocentre for well-constrained regional events and
  the more stable expectation hypocentre for weakly-constrained teleseismic
  events; see [tests/lib_compare.sh](tests/lib_compare.sh).) That test net — not
  line-by-line human review — is what guarantees the science is unchanged, which
  is why code the tests do not exercise is flagged as higher-risk. The work is
  offered for the maintainer's review and domain validation.

## Methodology

The work follows a few non-negotiable rules:

1. **Behavior-preserving.** Changes correct safety/robustness or structure
   without altering results. Removing functionality is out of scope.
2. **Test-gated.** Nothing is committed unless the regression tests pass — every
   located hypocentre within tolerance of the frozen reference (see below). Each
   file is verified before moving on.
3. **Small, reviewable commits.** One kind of change per commit, with the
   rationale, what was deferred, and the verification recorded in the message.
4. **Defer rather than guess.** Where a change cannot be made safely without
   more analysis (e.g. bounding a write into a pointer of unknown size), it is
   left unchanged and explicitly noted, not guessed at.

### On the scripted transformations

The bulk string-safety conversions (`sprintf`→`snprintf`, `strcpy`→bounded
`snprintf`) were applied with guarded `sed` rules, but never blind:

- destinations that are function-parameter pointers were excluded by name,
  because `sizeof` is only valid on in-scope arrays;
- each transformation was run on a copy and inspected before being kept (this
  caught a real defect — an empty-source rewrite — before it reached a tracked
  file);
- the build and both regression tests were run after every file.

## Verifying it yourself

Requires only a C toolchain and CMake (no GMT, no Java):

```bash
cd src && cmake . && make -j"$(nproc)" && cd ..
tests/run_regression.sh          # regional (alaska) sample
tests/run_regression_global.sh   # global (teleseismic) sample
tests/run_regression_ssst.sh     # NLL-SSST initial location (Parkfield, ~3 min)
tests/run_regression_ssst_full.sh  # full iterative SSST (Parkfield, opt-in, ~20 min)
```

Each prints `PASS` when every located hypocentre is within tolerance of the
frozen reference. See [tests/README.md](tests/README.md) for details. CI runs the
three fast tests on every push and pull request
(`.github/workflows/regression.yml`); the full iterative SSST test is slower and
stochastic (opt-in — run locally, or trigger the manual
`.github/workflows/regression-ssst-full.yml` workflow on GitHub).

## Guidance for future AI-assisted changes

- Keep `main` a clean mirror of upstream; do modernization on feature branches.
- Treat the three fast regression tests as the gate: run them after every change; a
  non-`PASS` (any hypocentre outside tolerance vs. the frozen reference) means stop and
  investigate, not adjust the reference. The full iterative SSST test
  (`run_regression_ssst_full.sh`, ~20 min) is a deeper, opt-in check worth running
  before pushing SSST-affecting changes.
- `sizeof(dest)` is only correct when `dest` is an in-scope array. For pointer
  parameters, trace the real buffer size or defer.
- When touching code the regression tests do not exercise, say so in the commit
  and treat it as higher-risk.
- Do not add `Co-Authored-By` trailers to commits; AI involvement is recorded
  here instead.
