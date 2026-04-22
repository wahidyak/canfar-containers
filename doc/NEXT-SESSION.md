# Next Session — Pick-Up Notes

> **Written:** 2026-04-22 (end of session). Fork `main` at `a1845bc`.
> If `git log --oneline -1 origin/main` no longer shows `a1845bc` when
> you read this, somebody pushed in the interim — reconcile before
> acting on the commit recipe below.

Short context dump to resume work without re-reading the full transcript.
Authoritative references: [`README.md`](../README.md) for architecture,
[`doc/HANDOFF.md`](HANDOFF.md) for operational detail,
[`doc/RELEASE-CADENCE.md`](RELEASE-CADENCE.md) for the release policy.
This file is a working scratchpad; delete or rewrite when no longer
needed.

---

## First 5 minutes tomorrow (bootstrap checklist)

Run these in order before touching anything:

```bash
cd /mnt/container-data/projects/canfar-containers
git log --oneline -1                              # expect: a1845bc (Merge PR #9)
git status --short                                # expect: 6 M + 2 ?? (below)
git fetch --all --prune && git log --oneline -1 origin/main   # confirm no drift
```

Expected `git status --short`:

```
 M .github/workflows/image-pipeline.yml
 M README.md
 M doc/HANDOFF.md
 M doc/NEXT-SESSION.md
 M docker-bake.hcl
 M renovate.json
?? doc/RELEASE-CADENCE.md
?? dockerfiles/carta/
```

If any of the above is wrong, **stop and reconcile** — the commit
recipe below assumes this exact starting point.

---

## TL;DR for tomorrow

1. The working tree has **three uncommitted change sets** (release
   cadence + CARTA image + age-based forced rebuild). Nothing is
   staged. Nothing has been pushed. `main` on both the fork and
   upstream is still at `a1845bc` (merge of PR #9, the NEXT-SESSION
   docs PR).
2. **All 5 CARTA blockers are resolved** as of 2026-04-22 — Shiny
   confirmed Harbor auto-create + coexistence with
   science-containers/carta + upstream-version tagging, we verified
   the PPA key fingerprint against 3 independent sources, and
   confirmed Skaha wiring is not our concern. See
   [§ Pending confirmations for Shiny](#pending-confirmations-for-shiny)
   for the as-implemented record.
3. Remaining blockers before the upstream PR: items 6–15 (supply
   chain + general Harbor/tag/Renovate-install ops). Those are
   lower-priority and can land as follow-ups — **you can open the
   upstream PR now** if you want, with 6–15 surfaced in the PR body.
4. Split the tree into **three commits on one branch** (A=cadence,
   B=CARTA, C=age-based-rebuild) and open the upstream PR. The
   exact commands are in
   [§ Ready-to-run commit recipe](#ready-to-run-commit-recipe) below.
5. Sanity-check the build graph before the PR:
   [§ Verification commands](#verification-commands) has one-liners
   already proven green this session.

---

## Current state (snapshot)

- Fork `main` at `a1845bc` (PR #9 merged — NEXT-SESSION scratchpad).
- Upstream `opencadc/canfar-containers` **has no open PRs from this
  fork yet**. Shiny green-lit opening one.
- Mend Renovate dashboard: zero `no-result` warnings at last check.
- Local tree: clean `git status` prior to this session, now has two
  logical change sets intermixed (below). **Nothing is staged.**

### Unstaged working-tree inventory (by file)

Live stats as of 2026-04-22 (from `git diff --stat HEAD`):

```
 M .github/workflows/image-pipeline.yml  (+409/-?   mixed: cadence + carta + age-based rebuild)
 M README.md                             (+40/-?   mixed: cadence + carta + tag policy)
 M doc/HANDOFF.md                        (+216/-?  mixed: cadence + carta + CARTA_TAG derivation + freshness rule)
 M docker-bake.hcl                       (+35/-?   carta target + CARTA_TAG variable)
 M renovate.json                         (+14/-?   mixed: cadence window + carta deb rule)
?? doc/RELEASE-CADENCE.md                (~145 lines, cadence + age-based rebuild — new file)
?? dockerfiles/carta/                    (77 lines, carta only — new directory)
```

`git status --short` verbatim:

```
 M .github/workflows/image-pipeline.yml
 M README.md
 M doc/HANDOFF.md
 M doc/NEXT-SESSION.md                   # (this file, updates each session)
 M docker-bake.hcl
 M renovate.json
?? doc/RELEASE-CADENCE.md
?? dockerfiles/carta/
```

### What's in each change set

**Change set A: Release cadence** (the larger, more structural one)

Files touched by A:
- `.github/workflows/image-pipeline.yml` — 3 crons (days 1/2/3) instead
  of 1; new "Determine release phase" step; new "Diff against previous
  release tag" step (git diff against `release/<last YY.MM>`); phase
  gate in "Resolve dependencies"; new `tag-release` job that pushes
  `release/YY.MM` on day-3 success.
- `renovate.json` — schedule changed from `"on the first day of the
  month"` to `"after day 5 and before day 28"`. Custom regex left
  unchanged in this change set.
- `README.md` — release-window prose, trigger list updated to match 3
  crons + tag-anchor diff + "only republish if changed" rule.
- `doc/HANDOFF.md` — triggers table, detect-changes description, new
  `tag-release` job in §4, §9 pending confirmation about
  `release/YY.MM` tag-push perms.
- `doc/RELEASE-CADENCE.md` — **NEW FILE.** The full policy: calendar,
  rules, dependency cascade, "what happens during merge window",
  caveats, adjusting the cadence.

**Change set B: CARTA image** (a pure addition layered on A)

Files touched by B:
- `dockerfiles/carta/Dockerfile` — **NEW FILE.** `FROM
  ubuntu:24.04@sha256:…`, cartavis-team PPA install with explicit GPG
  keyring under `/etc/apt/keyrings/`, `CARTA_VERSION=5.1.0~noble1`
  pinned via Renovate `deb` datasource against the PPA's Packages
  index, PPA key fingerprint manually pinned + verified (2021-03-16),
  port 5000, `CMD ["carta", "--no_browser", "--port", "5000"]`.
- `docker-bake.hcl` — new `CARTA_TAG` variable (default `local`),
  `carta` added to `group "default"`, new `target "carta"` block
  (no `contexts`, tagged as `cadc/carta:${CARTA_TAG}` — standalone leaf
  and standalone tag scheme).
- `.github/workflows/image-pipeline.yml` — `carta` added to:
  detect-changes outputs; fallback-rebuild list; diff block (as a
  leaf with no cascade); `dorny/paths-filter` filters; phase gate
  for schedule (interactive arm), workflow_dispatch, and push/PR;
  bake-target assembly. Plus a new **"Derive CARTA tag"** step in the
  `interactive-stack` job that greps `CARTA_VERSION` out of the
  Dockerfile, strips the `~noble1` suffix, and exports the result as
  `CARTA_TAG` for bake.
- `renovate.json` — regex `matchStrings` extended to accept optional
  `registryUrl=`; new `packageRules` entry with
  `matchDatasources: ["deb"]` and `versioning: "deb"`.
- `README.md` — project tree gains `carta/`; new architecture
  bullet 6 for CARTA (standalone, tag policy); trigger list and
  build/deployment prose mention CARTA's standalone status and
  `cadc/carta:<upstream version>` tag.
- `doc/HANDOFF.md` — tree; stack diagram gains an Ubuntu branch with
  `<CARTA_TAG>` annotation; image/port table gains a CARTA row; bake
  section expanded to 5 targets with CARTA called out as a leaf;
  `<CARTA_TAG>` derivation documented in §3 and in the
  `interactive-stack` description; §4 cascade rules updated;
  push-matrix updated to show CARTA's different tag scheme; §5.1 +
  §9 pending confirmations cover new `cadc/carta` Harbor repo + ACL.
- `doc/RELEASE-CADENCE.md` — day-3 calendar row clarifies CARTA's
  different tag scheme; cascade section notes CARTA is a leaf; new
  "CARTA uses a different tag scheme" caveat.

**Change set C: Age-based forced rebuild** (small, cross-cutting)

Logically a follow-up to A but belongs in its own commit for
bisectability. Files touched by C:
- `.github/workflows/image-pipeline.yml` — new
  `Force rebuild on aging release tag` step (scheduled-only) that
  measures the age of `release/<last YY.MM>` and emits
  `forced=true|false`. The `Resolve dependencies and apply phase
  gate` step consumes this output and, when `forced=true`, overrides
  `P=T=W=V=M=C=true` before the phase gate runs. Top-of-file comment
  block updated to document the rule. Default threshold
  `FORCED_REBUILD_AGE_DAYS=45` set inline on the step.
- `doc/HANDOFF.md` — new bullet in §4 `detect-changes` describing
  the override.
- `doc/RELEASE-CADENCE.md` — new "Age-based forced rebuild
  (freshness floor)" section replacing the prior "Caveats" bullet
  that described the problem without a mitigation.

C is ~30 lines of workflow + doc and can either be committed with
A or as its own third commit. Splitting into C feels cleaner for
bisect and for PR review ("here is the cadence, here is how we
prevent it from letting images go stale").

**Commit split recommendation.** Three commits on one branch, in
order A → B → C. Because the A/B bits are intermixed in 5 files,
plan to stage A and B with `git add -p`, not per-file. C is
self-contained (one workflow step + two doc additions) and clean
to stage with discrete `git add -p` hunks.

Heuristic for hunks:

- Hunks mentioning "phase", "release/<YY.MM>", "tag-release", "days
  1/2/3", "merge window", "Renovate window" → **commit A**.
- Hunks mentioning "carta", "cartavis", "ubuntu:24.04", "port 5000",
  "deb datasource", "CARTAvis PPA", "standalone leaf",
  "CARTA_TAG", "CARTA_VERSION", "Derive CARTA tag" → **commit B**.
- Hunks mentioning "forced_by_age", "FORCED_REBUILD_AGE_DAYS",
  "freshness floor", "aging release tag", "45 days" → **commit C**.
- `renovate.json` schedule-string change → A. Regex + deb rule → B.
- `README.md` project-tree `carta/` line → B. Release-tagging bullet
  about CARTA `<upstream version>` → B. All other README prose is
  split by subject per the heuristic above.
- `docker-bake.hcl` — entire diff (including the `CARTA_TAG`
  variable) is B.
- `doc/RELEASE-CADENCE.md` — base content is A; the CARTA-specific
  caveat bullet and day-3 row refinement are B; the "Age-based
  forced rebuild" section is C. Easiest concrete path: `git add`
  the file into A with neither the B nor C hunks, then `git add -p`
  the B hunks, then `git add -p` the C hunks. Alternative: attribute
  everything to A and call that out in A's commit message.
- `dockerfiles/carta/` — whole directory is B.
- "Derive CARTA tag" workflow step + `CARTA_TAG:` env line on
  bake-action → B.
- "Force rebuild on aging release tag" workflow step + the
  `FORCED="${{ steps.age.outputs.forced }}"` block in the filter
  step + the top-of-file comment update → C.

---

## Ready-to-run commit recipe

After Shiny's confirmations come in (and any diffs triggered by
those answers are applied), use these commands. **Do not run them
blindly tonight.**

```bash
# Sanity snapshot before splitting
git status --short
git diff --stat

# Create a working branch off main
git checkout -b feat/release-cadence-and-carta

# Stage commit A (release cadence) interactively
git add -p .github/workflows/image-pipeline.yml \
          README.md doc/HANDOFF.md renovate.json
git add doc/RELEASE-CADENCE.md   # if you chose the "clean split" path

git diff --cached --stat          # double-check only A's hunks are staged
git commit -m "feat(ci): staggered monthly release cadence with tag-anchored diff

Implements a non-overlapping merge-window (days 5-27) / release-window
(days 1-3) model, so Renovate updates and publishes never compete for
the same calendar days.

- Three scheduled crons replace the single monthly cron: day 1 publishes
  the Python matrix, day 2 the terminal base, day 3 the interactive
  stack. Day 4 is a buffer, days 5-27 are the merge window, day 28+
  is a soft freeze.
- detect-changes diffs HEAD against the previous month's release/<YY.MM>
  git tag instead of force-rebuilding everything. Images (and their
  cascade descendants) are republished only if something actually
  changed; the previous month's tag stays current in Harbor otherwise.
  Missing anchor tag falls back to a full rebuild.
- A phase gate restricts each scheduled day to its own subset of images
  so day 1 can't accidentally publish the interactive stack, etc.
  workflow_dispatch ignores the gate (escape hatch for hotfixes).
- New tag-release job pushes release/<YY.MM> on successful day-3 runs
  so next month's detect-changes has a diff anchor. Uses the default
  GITHUB_TOKEN with job-scoped contents:write.
- Renovate window shifted from 'on the first day of the month' to
  'after day 5 and before day 28' so PRs never open during release or
  soft freeze.

See doc/RELEASE-CADENCE.md for the full policy, calendar, and caveats."

# Stage commit B (CARTA)
git add dockerfiles/carta/
git add docker-bake.hcl
git add -p .github/workflows/image-pipeline.yml \
          README.md doc/HANDOFF.md renovate.json doc/RELEASE-CADENCE.md

git diff --cached --stat
git commit -m "feat(carta): add cadc/carta image as day-3 standalone session

Adds CARTA (Cube Analysis and Rendering Tool for Astronomy) as a new
CANFAR contributed-session image, published to images.canfar.net/cadc/carta.

- New dockerfiles/carta/Dockerfile on ubuntu:24.04 (digest-pinned). CARTA
  is distributed only via the cartavis-team Launchpad PPA, which ships
  builds for Ubuntu Jammy/Noble and nothing else; no Debian or RHEL
  equivalent exists, so this image cannot inherit from cadc/terminal.
- carta apt package pinned via Renovate 'deb' datasource against the
  PPA's Packages index. Catches both upstream bumps (5.1.0 -> 5.2.0)
  and PPA-internal rebuilds (~noble1 -> ~noble2).
- PPA signing key fingerprint manually pinned. Not Renovate-tracked:
  a change here is a security-relevant rotation event.
- Port 5000 (CANFAR contributed-session contract), overriding CARTA's
  upstream default of 3002 via --no_browser --port 5000.
- New standalone 'carta' target in docker-bake.hcl: no 'contexts'
  block, no cascade from terminal or python, no cascade into
  anything else.
- Workflow: carta wired into detect-changes outputs, release-tag diff
  (leaf: own dir + docker-bake.hcl only), path-filter for push/PR,
  phase gate on day 3 (interactive phase) plus workflow_dispatch and
  push/PR code paths, and the bake-target assembler. CARTA does NOT
  force terminal into the bake target list.
- renovate.json: regex extended to accept optional 'registryUrl=' in
  '# renovate:' comments so the PPA's Packages index URL can be
  passed to the deb datasource. New packageRule pins
  deb+custom.regex to versioning=deb.
- Docs: README architecture item 6, HANDOFF stack diagram and port
  table, RELEASE-CADENCE day-3 calendar row and cascade note.

Harbor repo cadc/carta auto-creates on first push per Shiny's
confirmation. Tag policy = upstream version (cadc/carta:5.1.0),
science-containers/carta remains in coexistence. PPA key
fingerprint verified against Launchpad HTML, Launchpad JSON API,
and keyserver.ubuntu.com (UID: 'Launchpad PPA for CARTAvis')."

# Stage commit C (age-based forced rebuild)
git add -p .github/workflows/image-pipeline.yml \
          doc/HANDOFF.md doc/RELEASE-CADENCE.md

git diff --cached --stat
git commit -m "feat(ci): force full phase rebuild when release tag is older than 45 days

Closes a freshness gap in the 'only republish if changed' rule:
unpinned apt packages inside our Dockerfiles only refresh when the
image rebuilds. When Canonical/Debian batch security patches without
re-publishing the base-image tag, Renovate sees no digest bump, no PR
opens, and the image would otherwise sit on stale apt state.

- New workflow step 'Force rebuild on aging release tag' measures the
  age of release/<last YY.MM> (scheduled runs only, not push/PR/
  workflow_dispatch) and emits forced=true when it exceeds
  FORCED_REBUILD_AGE_DAYS (default 45).
- The 'Resolve dependencies and apply phase gate' step, when
  forced=true, overrides its per-image diff outputs to all-true
  before applying the phase gate. So the day-3 cron rebuilds the
  entire interactive stack, etc., even if git diff says nothing
  changed.
- Does not apply to push / PR / workflow_dispatch. Those events
  rebuild on file changes only, as before.
- Documented in doc/RELEASE-CADENCE.md (new 'Age-based forced
  rebuild' section) and doc/HANDOFF.md (§4 detect-changes bullet)."

git push -u <fork-remote> feat/release-cadence-and-carta

# Then open the PR via `gh pr create` or the web UI
```

One-liner to abort cleanly if something looks wrong mid-split:

```bash
git reset HEAD .                # un-stage everything
git checkout main               # go back
# Working tree changes are preserved; nothing is lost.
```

---

## Verification commands (already green this session)

Run these any time to re-prove the build graph is coherent. Outcomes
recorded from today's session.

```bash
# 1) JSON syntax on renovate.json
python3 -c "import json; json.load(open('renovate.json'))"
# -> exits 0 (passed)

# 2) YAML syntax on the workflow
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/image-pipeline.yml'))"
# -> exits 0 (passed)

# 3) Bake graph resolves with all 5 targets
docker buildx bake --print
# -> Prints JSON with carta/marimo/terminal/vscode/webterm; carta has
#    no 'contexts' (standalone), the other three have the terminal
#    substitution block.

# 4) Hadolint on the new CARTA Dockerfile
docker run --rm -i hadolint/hadolint < dockerfiles/carta/Dockerfile
# -> empty output = clean pass

# 5) Renovate validator — KNOWN quirk, see below
npx --yes --package renovate -- renovate-config-validator --no-global renovate.json
# -> Exits 1 silently. This is NOT from our edits. The pre-existing
#    cadence work changed the schedule string to 'after day 5 and before
#    day 28'; the strict validator is conservative about natural-language
#    schedules but Renovate itself understands them at runtime. Bisecting
#    confirmed that isolating the regex extension + deb packageRule
#    additions (keeping the base schedule string) exits 0 with
#    'Config validated successfully'.
```

If tomorrow's investigation shows anything surprising here, that's a
real regression worth fixing before the PR opens.

---

## Pending confirmations for Shiny

These block the upstream PR. Each has a defined fallback if the answer
is "not yet." Ordered for a single outreach message (CARTA first since
that's the newest scope).

### CARTA-specific — status as of 2026-04-22

All five CARTA blockers have been resolved, either by Shiny's input
this session or by us verifying in-session. Kept here for PR-body
provenance.

1. **New Harbor repository `cadc/carta`** — **RESOLVED.** Shiny
   confirmed Harbor auto-creates the repo on first push under the
   existing `cadc/*` project ACL. No preemptive action needed.
   Document in PR body so nobody panics when the repo appears.

2. **CARTA tag policy** — **RESOLVED (upstream version).** Shiny
   chose `cadc/carta:<upstream version>` (e.g. `cadc/carta:5.1.0`),
   deliberately decoupled from the `YY.MM` cadence. Implemented via
   a `CARTA_TAG` bake variable (default `local`), derived in CI by
   greppping `ARG CARTA_VERSION=` from
   `dockerfiles/carta/Dockerfile` and stripping the `~noble1` PPA
   suffix (`5.1.0~noble1 → 5.1.0`). Single source of truth =
   Dockerfile; Renovate edits `CARTA_VERSION`, the tag follows. See
   `docker-bake.hcl` `target "carta"` and the workflow step
   "Derive CARTA tag".

3. **Skaha session wiring** — **RESOLVED (no action on our side).**
   Reviewed the Debian interactive stack (webterm/vscode/marimo):
   none of them carry `skaha.type` / `org.opencadc.skaha.*` labels
   either — the `"contributed session"` references are all
   code-comment docstrings, not `LABEL` instructions. Skaha
   discovers these images by image-name prefix or external config,
   not image metadata. CARTA matching the existing stack (port 5000,
   no special labels) is correct. Session-type wiring on the Portal
   side is Shiny's territory, not our Dockerfile's concern.

4. **Retiring `opencadc/science-containers/carta`** — **RESOLVED
   (coexist).** Two CARTA images ship in parallel. Under different
   registry paths (`images.canfar.net/cadc/carta` vs.
   `images.canfar.net/skaha/carta` — verify the skaha path before
   merge; if they collide we need to revisit), so tag-space overlap
   is avoided. PR framing: "separate deployment path for the Skaha
   contributed-session flow; science-containers' CARTA keeps serving
   its existing consumers."

5. **CARTAvis PPA signing-key fingerprint** — **VERIFIED in
   session.** Fingerprint `49CD6FAB8EA28584DBDCD04186B78FB18F11E91C`
   confirmed against three independent sources:
   - Launchpad HTML page (`Fingerprint:` field, matches)
   - Launchpad JSON API (`signing_key_fingerprint` in `LP.cache`,
     matches)
   - `keyserver.ubuntu.com` (UID: "Launchpad PPA for CARTAvis",
     4096-bit RSA, created 2021-03-16)
   Keep the hard-pinned fingerprint; it's strictly stronger than
   WenbinWL/science-containers' `add-apt-repository` approach,
   which implicitly trusts whatever Launchpad returns at build
   time. Corrected stale "Stable since 2017" comment to "Stable
   since 2021-03-16".

### Supply-chain scope (discussed, deliberately deferred)

6. **Does opencadc want SLSA L3 provenance + SBOM + keyless cosign
   signing on all `cadc/*` images?** If yes: one follow-up PR
   touching only `.github/workflows/image-pipeline.yml`
   (`docker/build-push-action` and `bake-action` both support SBOM +
   attestations at the action level — it's not per-image work). If
   no, or not yet: document the decision and move on.

7. **Verification-side tooling.** Is someone going to publish a
   `cosign verify` one-liner + the OIDC identity regex so consumers
   can actually check signatures, or is signing purely for transparency
   without enforcement?

### General (from HANDOFF.md §9, still open)

8. **Registry secret names.** Workflow uses
   `CANFAR_REGISTRY_USER` / `CANFAR_REGISTRY_PASSWORD`. Confirm these
   exact names match opencadc's Actions-secrets configuration.
9. **Harbor project + ACL** for the other five images (python,
   terminal, webterm, vscode, marimo) — should already exist but
   worth a drive-by confirmation.
10. **Tag format** (`YY.MM` vs. `vYY.MM` vs. `YYYY.MM` vs. semver).
11. **Python tag strategy** — in-place `cadc/python:3.12` overwrite vs.
    dated (`cadc/python:3.12-26.04`). Currently the former.
12. **Renovate install on opencadc/canfar-containers.** One-time admin
    step via https://github.com/apps/renovate; without it, pins go
    stale.
13. **Auto-merge policy for Renovate.** Mention as optional follow-up,
    don't push for a decision.
14. **Issues enabled on the upstream repo** so Renovate's Dependency
    Dashboard can post.
15. **`release/YY.MM` tag-push permissions** for `github-actions[bot]`.
    Default `GITHUB_TOKEN` with job-scoped `contents: write` covers it
    unless a ruleset on `main` blocks bot-authored tag pushes.

### Suggested outreach message to Shiny (copy-paste draft)

> Hey Shiny — two big changes queued up for the upstream PR, not
> committed yet because a few items need your sign-off:
>
> **Release cadence.** The workflow now runs on 3 crons (days 1-3) with
> a phase gate, diffs against the previous month's release tag so
> unchanged images are skipped, and pushes release/YY.MM on day-3
> success. Renovate moved to days 5-27. Fully documented in
> doc/RELEASE-CADENCE.md. This should be behavior-neutral for images
> that actually get Renovate bumps each month; the edge case is that
> a dormant image now can skip a month instead of being force-rebuilt
> with whatever unpinned apt deltas happen to be on the mirror. OK to
> accept that trade-off?
>
> **CARTA.** Added as cadc/carta, Ubuntu 24.04 + cartavis-team PPA,
> port 5000, day-3 standalone leaf. Needs from you:
>   1. cadc/carta Harbor repo + robot ACL.
>   2. Tag policy: YY.MM, upstream version, or both?
>   3. Confirm the Skaha 'carta' session type points at
>      images.canfar.net/cadc/carta.
>   4. Should this image become canonical, with
>      science-containers/carta deprecated?
>   5. Quick eyeball on the PPA key fingerprint I pinned:
>      49CD6FAB8EA28584DBDCD04186B78FB18F11E91C.
>
> **Also worth flagging, not blocking.** We could turn on SLSA L3
> provenance + SBOM + keyless cosign signing across all six cadc/*
> images in a separate PR. Worth doing? And if yes, who owns the
> verification side (publishing a `cosign verify` recipe for
> downstream users)?

---

## Decisions already made (do not relitigate)

- **`agent.md` deleted, not rewritten.** (PR #7 already landed.)
  README + HANDOFF cover everything it claimed to.
- **Time-bound release cadence.** Renovate days 5-27, releases days
  1-3, day 4 buffer. Day-3 push creates `release/YY.MM` anchor tag.
  Full policy in `RELEASE-CADENCE.md`.
- **"Only republish if changed" semantics, with a 45-day freshness
  floor.** Each release day diffs against previous month's
  `release/YY.MM` tag. Unchanged images skip; previous-month tag
  stays current in Harbor. To prevent indefinite apt-package
  staleness when Canonical/Debian batch security patches without
  re-publishing the base tag, the age of the release tag is also
  checked — if > 45 days old, the full phase rebuilds regardless
  of diff. Scheduled-runs only. Documented in RELEASE-CADENCE
  § "Age-based forced rebuild".
- **CARTA joins `canfar-containers` as `cadc/carta`.** Superseded the
  earlier "do not add" decision in prior NEXT-SESSION iterations.
  Built from `ubuntu:24.04` (mandatory — cartavis-team PPA is
  Ubuntu-only), port 5000, `deb`-datasource pinning against the PPA
  Packages index. Standalone leaf — no cascade in or out.
- **CARTA tag policy = upstream version, single source of truth in
  the Dockerfile.** `cadc/carta:<upstream version>` (e.g. `5.1.0`),
  deliberately decoupled from the `YY.MM` cadence. Derived in CI by
  stripping the `~noble1` PPA suffix from `ARG CARTA_VERSION` in
  `dockerfiles/carta/Dockerfile` → passed to bake as `CARTA_TAG`.
  Renovate edits `CARTA_VERSION`; the tag follows automatically. No
  separate variable to keep in sync.
- **No `cadc/ubuntu` base layer.** Considered (and architecturally
  attractive: `cadc/ubuntu` → `cadc/carta` would mirror
  `cadc/python` → `cadc/terminal` → `cadc/{webterm,vscode,marimo}`).
  Rejected for now under "rule of three": we have exactly one
  Ubuntu-based image, no clear second consumer on the horizon, and
  introducing the abstraction would cost a new Harbor repo + ACL +
  bake target + phase-gate wiring for a family of one. Revisit if a
  second Ubuntu-based image appears; the refactor is ~30 lines of
  diff.
- **PPA key fingerprint verified in-session (2026-04-22).** Confirmed
  `49CD6FAB8EA28584DBDCD04186B78FB18F11E91C` against Launchpad HTML,
  Launchpad JSON API, and keyserver.ubuntu.com. 4096-bit RSA, created
  2021-03-16, UID "Launchpad PPA for CARTAvis". Kept hard-pinned in
  the Dockerfile (strictly stronger than the `add-apt-repository`
  approach used by WenbinWL/science-containers, which implicitly
  trusts whatever Launchpad returns at build time).
- **Firefly stays in `opencadc/science-containers`.** Out of scope.
  Java source in `cadc-sso/` has its own lifecycle, two-stage Gradle
  build, Tomcat runtime, and its existing `firefly.yml` already does
  provenance + SBOM + cosign. Moving it here would be a downgrade
  until this repo's CI matches that baseline (see pending item 6).
- **Supply-chain hardening deferred.** Not included in the CARTA PR.
  If adopted, it lands as a single workflow-level change across all
  six `cadc/*` images. Awaiting Shiny's go/no-go.

---

## Risks and gotchas to watch for

- **Mid-month first run on an empty anchor.** The very first time the
  new workflow fires on day 1 after merge, `release/<last YY.MM>`
  won't exist, so the diff falls back to a full rebuild. That's by
  design, but it means the "only republish if changed" savings don't
  kick in until month 2. Document in the upstream PR so nobody's
  surprised.
- **Timing of the first CARTA push.** Harbor will auto-create
  `cadc/carta` on first push per Shiny's confirmation, so the repo
  itself isn't a concern. However, on push-to-main (not the day-3
  cron), the *entire* interactive stack rebuilds because
  `docker-bake.hcl` changes — that re-pushes `terminal`, `webterm`,
  `vscode`, `marimo` at whatever the current `YY.MM` tag is
  (overwriting that month's existing digest). Non-destructive but
  noisier than a pure additive CARTA push. Mitigation: let the PR
  merge during the merge window (days 5–27) — the first real CARTA
  push then happens on the following month's day-3 cron alongside
  the rest of the stack's normal monthly publish.
- **First CARTA tag overwrites on age-based rebuild.** On a
  month where the 45-day forced-rebuild kicks in but CARTA hasn't
  had an upstream version bump, bake will re-push
  `cadc/carta:5.1.0` (same tag, new digest). This is intentional —
  it's how security patches propagate when the upstream version
  doesn't change. It means consumers pinning to `5.1.0` get the
  new digest on their next pull. Document this in the Skaha
  session-type runbook if anyone depends on digest immutability
  for that tag.
- **`renovate.json` regex backward-compat.** The new `registryUrl=`
  capture is optional, so every existing `# renovate:` annotation
  still matches. If a future Dockerfile lists tokens in an unexpected
  order (e.g. `versioning=` before `registryUrl=`), the regex won't
  match — add a comment to future Dockerfiles keeping the order
  `datasource → depName → registryUrl → versioning`.
- **CARTAvis PPA availability.** The PPA occasionally goes quiet for
  a few weeks around upstream releases. If day 3 fires while the
  package is temporarily unavailable in `noble`, the workflow fails
  loudly. Previous month's `cadc/carta` tag stays current; acceptable
  for now, but note it as a known fragility.
- **Day-3 bake job runs two independent workloads.** webterm/vscode/
  marimo cascade from terminal via `contexts:`; carta is standalone.
  If the terminal portion fails, carta should still build. The bake
  invocation is a single step, so a catastrophic bake failure would
  take out both — verify on the first real day-3 run that they're
  actually independent in practice.
- **Age-based forced rebuild can mask "nothing should have rebuilt"
  bugs.** If the 45-day trigger fires frequently (e.g. because
  Renovate is misconfigured and PRs are stalling), it looks like
  the normal "only republish if changed" rule is working but
  actually everything is brute-force rebuilding every month. Watch
  the workflow logs for "Forcing full rebuild" messages — if they
  appear month after month without Renovate PRs filling the gaps,
  something in the diff-based path is broken.
- **Day-3 bake gets `CARTA_TAG` from a greppable convention in the
  Dockerfile.** The "Derive CARTA tag" step uses awk to pull out
  `ARG CARTA_VERSION=<value>`. If a future edit to the Dockerfile
  (or a hand-rolled format change by Renovate) produces something
  awk can't parse, the derivation falls back to `unknown` and CARTA
  gets tagged `cadc/carta:unknown` — visibly wrong, but still
  pushed. The `unknown` tag is the tripwire. If you see it in
  Harbor, inspect the Dockerfile ARG format.
- **`gh pr create` body length.** The outreach-message draft above is
  close to the practical limit for a PR body. If it needs to shrink,
  keep items 1-5 (CARTA) and push 6-7 (supply chain) into a separate
  GitHub issue referenced from the PR.

---

## Open questions to surface if Shiny is responsive

Beyond the blocking confirmations:

- Is there a CADC-wide convention for image labels (e.g. `skaha.type:
  carta`) that the Harbor label system expects? The current
  Dockerfile just sets OCI labels, not Skaha-specific ones.
- Python image tagging: `cadc/python:3.12` is overwritten each build.
  If any upstream consumer pins to a specific date-stamped Python
  tag, the current setup would have to change.
- Is it worth adding a forced-rebuild safety valve (e.g. "rebuild
  everything if last release is >3 months old") to guarantee unpinned
  apt security patches never stall?

---

## Reference — files worth re-reading first

- [`README.md`](../README.md) — architecture + pinning philosophy.
- [`doc/HANDOFF.md`](HANDOFF.md) — operational detail; §4 has the job
  breakdown, §5 external services, §9 pending confirmations.
- [`doc/RELEASE-CADENCE.md`](RELEASE-CADENCE.md) — merge/release
  policy, calendar, cascade rules, caveats.
- [`.github/workflows/image-pipeline.yml`](../.github/workflows/image-pipeline.yml)
  — 3 crons, phase gate, release-tag diff, `tag-release` job.
- [`renovate.json`](../renovate.json) — custom regex manager (now
  supporting optional `registryUrl=`), `deb` versioning rule, merge
  window schedule (days 5-27).
- [`dockerfiles/carta/Dockerfile`](../dockerfiles/carta/Dockerfile)
  — Ubuntu 24.04 + cartavis-team PPA, port 5000, `deb`-pinned.
- [`docker-bake.hcl`](../docker-bake.hcl) — 5 targets; `carta` is the
  standalone fifth (no `contexts` block).

## Transcript pointer

If any decision here looks ambiguous tomorrow, the full JSONL
transcript for this session is referenced from the agent's transcript
index; search for keywords like "CARTA", "cadence", "release window",
"deb datasource", or "Shiny" to reconstruct intent.

---

## Session-close checklist (what was and wasn't done — updated 2026-04-22 PM)

Done this session (cumulative across yesterday + today):

- [x] `dockerfiles/carta/Dockerfile` created (77 lines, hadolint clean,
      PPA key fingerprint comment updated to reflect 2021-03-16 + in-
      session verification).
- [x] `docker-bake.hcl` gained standalone `carta` target + new
      `CARTA_TAG` variable (default `local`); target tags
      `cadc/carta:${CARTA_TAG}`. `docker buildx bake --print` still
      resolves all 5 targets.
- [x] `.github/workflows/image-pipeline.yml` wired `carta` through
      detect-changes, phase gate, path filters, and bake-target
      assembly. New "Derive CARTA tag" step greps `CARTA_VERSION`
      from the Dockerfile and exports `CARTA_TAG` for bake. New
      "Force rebuild on aging release tag" step implements the
      45-day freshness floor. YAML validates.
- [x] `renovate.json` regex extended for optional `registryUrl=`;
      new `deb` versioning packageRule added; JSON valid, regex +
      rule pass validator (schedule-string validator quirk is
      pre-existing, see §Verification).
- [x] `README.md`, `doc/HANDOFF.md`, `doc/RELEASE-CADENCE.md`
      updated with CARTA (tree, architecture, ports, diagrams,
      cascade rules, upstream-version tag policy, `<CARTA_TAG>`
      derivation) and the age-based forced-rebuild mechanism.
- [x] `doc/NEXT-SESSION.md` (this file) updated through three
      sessions of work.
- [x] CARTAvis PPA key fingerprint verified in-session against three
      independent sources (Launchpad HTML, Launchpad JSON API,
      keyserver.ubuntu.com) — resolves Shiny confirmation #5.
- [x] Reviewed WenbinWL/science-containers CARTA Dockerfile: uses
      `add-apt-repository` (implicit trust). Our approach
      (`gpg --recv-keys <fingerprint>`) is strictly stronger.
      Verdict: keep ours as-is.
- [x] Considered extracting `cadc/ubuntu` base layer for CARTA.
      Rejected on "rule of three" — no second Ubuntu consumer
      exists. Revisit later if that changes.
- [x] All 5 CARTA-specific Shiny confirmations resolved (Harbor
      auto-create, upstream-version tagging, coexistence,
      no-labels-needed, PPA key verified).

Deliberately NOT done (scope-controlled):

- [ ] `git add` anything — tree is still fully unstaged.
- [ ] `git commit` — no commits created.
- [ ] `git push` — nothing went to any remote.
- [ ] Upstream PR to `opencadc/canfar-containers` — **unblocked**,
      but still not opened. Can be opened next session.
- [ ] Reach out to Shiny on items 6–15 (supply chain + ops) — these
      are follow-ups, not PR blockers. Can be done in PR review.
- [ ] Harbor repo `cadc/carta` creation — per Shiny, auto-creates
      on first push. No preemptive action.
- [ ] Any supply-chain (SLSA/SBOM/cosign) work — deliberately
      deferred.
- [ ] `cadc/ubuntu` base layer — deliberately not extracted.

If you (tomorrow) find anything in "Done" that doesn't match the
working tree, something drifted overnight — investigate before
proceeding to the commit recipe.
