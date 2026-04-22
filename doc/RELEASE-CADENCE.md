# Release Cadence

This repository operates on a **non-overlapping merge window / release
window** model. The goal is to keep dependency churn (Renovate) and
publishing (Harbor pushes) from competing for the same calendar days, so
every monthly `YY.MM` tag is cut from a stable, deliberately-frozen tree.

## Calendar

| Day(s) of month | Window              | What happens                                                                                 |
|-----------------|---------------------|----------------------------------------------------------------------------------------------|
| 1  (06:00 UTC)  | Release: python     | `cadc/python:{3.10, 3.11, 3.12, 3.13, 3.14}` rebuilt & pushed (if changed)                   |
| 2  (06:00 UTC)  | Release: base       | `cadc/terminal:YY.MM` rebuilt & pushed (if changed)                                          |
| 3  (06:00 UTC)  | Release: stack      | `cadc/webterm:YY.MM`, `cadc/vscode:YY.MM`, `cadc/marimo:YY.MM` rebuilt & pushed (if changed); `cadc/carta:<upstream version>` rebuilt & pushed on CARTA version bump |
| 3  (post-build) | Release: mark       | `release/YY.MM` git tag pushed on the commit we built from                                   |
| 4               | Buffer              | No publishes, no merges. Absorbs day-3 re-runs and bakes in a freeze gap                     |
| 5 – 27          | Merge window        | Renovate opens PRs; humans review & merge. PRs lint + build but do **not** push              |
| 28 – end        | Soft freeze         | No new Renovate PRs open. Merges still legal but discouraged                                 |

All times are UTC. The crons live in
[`.github/workflows/image-pipeline.yml`](../.github/workflows/image-pipeline.yml);
the Renovate window is configured in [`../renovate.json`](../renovate.json).

## Rules

1. **Do not merge to `main` on days 1 – 4.** The release builds off whatever
   commit is `HEAD` when the cron fires; merging during release days
   ships un-tested combinations.
2. **Images are republished only if something changed.** On each release
   day the workflow diffs `HEAD` against the previous month's
   `release/YY.MM` git tag. Images whose Dockerfile (or an upstream it
   depends on, or `docker-bake.hcl`) hasn't changed are skipped. The
   previous month's tag in Harbor remains the current tag for that image;
   no new `YY.MM` is published for it.
3. **After day 3's publish succeeds**, CI creates `release/YY.MM` on the
   commit it built from and pushes it to the repo. That tag is the
   anchor for next month's diff.
4. **`workflow_dispatch` is the escape hatch.** It uses the same
   release-tag diff but ignores the day-of-month phase gate, so it
   rebuilds everything that has changed across all phases at once.
   Useful for out-of-band hotfixes.
5. **Renovate runs days 5 – 27 only.** It is explicitly silent during
   the release window and the pre-release soft freeze, so no dependency
   bump PR can race a release.

## Dependency cascade (unchanged)

Within a single phase, the existing cascade still applies:

- Any change under `dockerfiles/python/3.12/**` counts as a terminal
  change (terminal is `FROM cadc/python:3.12`), which in turn counts as
  a webterm / vscode / marimo change.
- Any change to `dockerfiles/terminal/**` or `docker-bake.hcl` cascades
  into webterm / vscode / marimo.
- Changes to other Python versions (3.10, 3.11, 3.13, 3.14) do not
  cascade — those images are published standalone.
- **CARTA does not participate in the cascade.** It is a standalone leaf
  built from `ubuntu:24.04` (dictated by the cartavis-team PPA being
  Ubuntu-only), not from `cadc/terminal`. A change to `dockerfiles/carta/`
  or `docker-bake.hcl` rebuilds CARTA; changes elsewhere do not.

The cascade is evaluated during each phase's diff. So a `python/3.12`
change merged during the previous merge window gets published on day 1
(as part of the python matrix), triggers a terminal rebuild on day 2,
and cascades into the interactive stack on day 3.

## What happens during the merge window (days 5 – 27)

- Renovate opens PRs bumping any pinned `ARG *_VERSION=…` declaration.
- Humans open PRs for Dockerfile edits, workflow tweaks, etc.
- Every PR runs lint (hadolint) and builds the affected images with
  `push: false`. Broken builds are caught before merge.
- Merged PRs land on `main`. Nothing is pushed to Harbor.
- Main can accumulate multiple weeks of merged changes; all of them
  ship together in the next release window.

## What happens during the release window (days 1 – 3)

- Each cron day the `detect-changes` job computes the release phase
  (python / terminal / interactive) based on which cron fired.
- It diffs `HEAD` against `release/<last month>`.
- It emits only the images (a) in this phase and (b) whose files
  actually changed.
- The build / push jobs run for that subset.
- On day 3 only, if both prior builds succeeded (or were legitimately
  skipped), `release/<this month>` is tagged and pushed.

## Caveats

- **The diff anchor is a git tag, not a registry tag.** Losing the
  `release/YY.MM` git tag (force-push to an orphan, tag retention
  policy, etc.) makes `detect-changes` fall back to a full rebuild of
  the current phase. That's a safe fallback but noisy.
- **`workflow_dispatch` does not tag a release.** Only the day-3
  scheduled run tags. Manual runs are treated as hotfixes and do not
  alter the monthly anchor.
- **CARTA uses a different tag scheme.** `cadc/carta:<upstream
  version>` (e.g. `5.1.0`), not `cadc/carta:<YY.MM>`. A month with no
  CARTA bump publishes no new CARTA tag.

## Adjusting the cadence

If a new image is added that should go in its own release day, add
another cron line to the `schedule:` block and another `case` arm to
the "Determine release phase" step in the workflow. Keep at least one
buffer day before the merge window reopens.

If Renovate's window needs to shift, edit the `"schedule"` value in
`renovate.json`. It uses the [later.js](https://bunkat.github.io/later/parsers.html)
natural-language syntax that Renovate vendors.
