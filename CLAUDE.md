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
  regression tests, which re-run the full location pipeline and compare output
  byte-for-byte against frozen references in both regional and teleseismic
  modes. That test net — not line-by-line human review — is what guarantees the
  science is unchanged, which is why code the tests do not exercise is flagged
  as higher-risk. The work is offered for the maintainer's review and domain
  validation.

## Methodology

The work follows a few non-negotiable rules:

1. **Behavior-preserving.** Changes correct safety/robustness or structure
   without altering results. Removing functionality is out of scope.
2. **Test-gated.** Nothing is committed unless both regression tests pass with
   byte-identical output (see below). Each file is verified before moving on.
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
```

Both print `PASS` when the location output matches the frozen reference. See
[tests/README.md](tests/README.md) for details. CI runs both on every push and
pull request (`.github/workflows/regression.yml`).

## Guidance for future AI-assisted changes

- Keep `main` a clean mirror of upstream; do modernization on feature branches.
- Treat the two regression tests as the gate: run them after every change; a
  non-`PASS` (any non-zero diff vs. the frozen reference) means stop and
  investigate, not adjust the reference.
- `sizeof(dest)` is only correct when `dest` is an in-scope array. For pointer
  parameters, trace the real buffer size or defer.
- When touching code the regression tests do not exercise, say so in the commit
  and treat it as higher-risk.
- Do not add `Co-Authored-By` trailers to commits; AI involvement is recorded
  here instead.
