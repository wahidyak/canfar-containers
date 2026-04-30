# Handoff Notes

This document describes how the repository is organized, how the CI/CD
pipeline operates, and what external services it depends on. It is
scoped strictly to what exists in this repository today — anything that
cannot be determined from the code, workflow, or configuration files is
called out as a **pending confirmation** item for whoever operates the
stack upstream.

For the user-facing architecture overview, image descriptions, and
pinning philosophy, see [`README.md`](../README.md). For the
merge-window / release-window cadence policy, see
[`RELEASE-CADENCE.md`](RELEASE-CADENCE.md). This document focuses on
operational and maintenance concerns.

---

## Table of contents

- [Glossary](#glossary)
- [1. Repository layout](#1-repository-layout)
- [2. Image stack and inheritance](#2-image-stack-and-inheritance)
  - [2.1. Inheritance overview](#21-inheritance-overview)
  - [2.2. `python` — the Debian Python foundation](#22-python--the-debian-python-foundation)
  - [2.3. `terminal` — interactive CLI environment](#23-terminal--interactive-cli-environment)
  - [2.4. `webterm`, `vscode`, `marimo` — three terminal-derived siblings](#24-webterm-vscode-marimo--three-terminal-derived-siblings)
  - [2.5. `carta` and `carta-psrecord` — standalone Ubuntu pair](#25-carta-and-carta-psrecord--standalone-ubuntu-pair)
  - [2.6. `firefly` — IPAC Firefly + CADC SSO plugin](#26-firefly--ipac-firefly--cadc-sso-plugin)
    - [Re-syncing `cadc-sso/` from upstream](#re-syncing-cadc-sso-from-upstream)
  - [2.7. Image tagging summary](#27-image-tagging-summary)
- [3. Build orchestration](#3-build-orchestration)
- [4. CI/CD workflow](#4-cicd-workflow)
- [5. External services and secrets](#5-external-services-and-secrets)
- [6. Local development](#6-local-development)
- [7. Adding a new image to the stack](#7-adding-a-new-image-to-the-stack)
- [8. Known state and orphans](#8-known-state-and-orphans)
- [9. Pending confirmation items (for upstream adopter)](#9-pending-confirmation-items-for-upstream-adopter)

---

## Glossary

Acronyms and product names used throughout this document and the rest
of the repo. If you've never worked on CANFAR before, skim this first.

| Term | Expansion / meaning |
|------|---------------------|
| **CANFAR** | Canadian Advanced Network for Astronomical Research. The umbrella platform that hosts all of these images. |
| **CADC** | Canadian Astronomy Data Centre (NRC Herzberg, Victoria BC). Operates CANFAR. The published images live under `images.canfar.net/cadc/`. |
| **Skaha** | The CANFAR **Science Platform** session manager — a Kubernetes-based service that launches per-user containers (notebooks, terminals, CARTA, Firefly, …) and proxies users to them. The images in this repo are consumed by Skaha as **session types**. |
| **Harbor** | The OCI image registry where these images are published, hosted at `images.canfar.net`. |
| **IPAC Firefly** | Server-side Java/Tomcat web app for astronomical image / table / catalog visualization, developed by IPAC at Caltech. Upstream: [`Caltech-IPAC/firefly`](https://github.com/Caltech-IPAC/firefly), reference image: `ipac/firefly` on Docker Hub. |
| **CARTA** | Cube Analysis and Rendering Tool for Astronomy. Standalone scientific viewer for radio-astronomy image cubes; distributed only via the [`cartavis-team/carta`](https://launchpad.net/~cartavis-team/+archive/ubuntu/carta) Ubuntu PPA. |
| **PPA** | Personal Package Archive — Launchpad-hosted apt repository. CARTA is published exclusively via the `cartavis-team/carta` PPA, which is why the CARTA images cannot inherit from our Debian-based `terminal`. |
| **TokenRelay** | The small Java SSO adapter we layer onto upstream Firefly (`org.opencadc.security.sso.TokenRelay`). Reads the `CADC_SSO` cookie from inbound requests and forwards it to outbound CADC service calls so users see authenticated data. Source vendored under `dockerfiles/firefly/cadc-sso/` (see §2.6). |
| **IVOA** | International Virtual Observatory Alliance — the standards body whose protocols (TAP, SIA, VOSpace, SSO) all CADC services implement. |
| **TAP** | IVOA Table Access Protocol. Astronomical-table query service exposed by CADC's [YouCAT](https://www.canfar.net/en/docs/services/) implementation. Firefly issues TAP queries on behalf of the logged-in user via TokenRelay. |
| **SIA** | IVOA Simple Image Access. Image-cutout / discovery service. Used the same way as TAP. |
| **VOSpace** | IVOA virtual-storage service. CADC's user data lives under `vos://cadc.nrc.ca!vault/<user>/`. |
| **YouCAT** | CADC's TAP service implementation. Hosted at `https://ws-cadc.canfar.net/youcat/`. |
| **`ivoa_cookie` / `ivoa_bearer`** | The two SSO challenge schemes IVOA defines. `ivoa_cookie` is what CADC services support natively; `ivoa_bearer` advertises an OIDC/JWT endpoint that Firefly's upstream `TokenRelay` *tries* to use, which is why the local edit (4) in §2.6 forwards the cookie instead. |
| **Renovate** | The dependency-update bot ([Mend](https://www.mend.io/)) that opens PRs to bump pinned versions. Configured in `renovate.json`; covered in §5.2. |
| **Repology** | Cross-distribution package version tracker ([repology.org](https://repology.org/)). Renovate's `repology` datasource queries it to find newer Debian / Ubuntu apt versions. |
| **`YY.MM` tag** | The two-digit-year, two-digit-month tag scheme (e.g. `26.04`) used for the Debian-based interactive stack. CARTA & Firefly use upstream version tags instead. |
| **`release/YY.MM`** | The annotated git tag pushed by the day-3 cron after a successful release. Used as the diff anchor for the next month's `detect-changes` step. |
| **AGPL-3.0** | GNU Affero General Public License v3.0 — the license declared in the repo's root `LICENSE` and inherited from `opencadc/canfar-containers`'s initial commit. |

---

## 1. Repository layout

```
canfar-containers/
├── .github/workflows/image-pipeline.yml  # Single CI/CD workflow
├── .gitignore
├── .hadolint.yaml                        # Hadolint ignore list (DL3008, DL3013)
├── README.md                             # Architecture + user-facing docs
├── docker-bake.hcl                       # Multi-target build config for the interactive stack
├── renovate.json                         # Renovate schedule + custom regex manager
├── doc/
│   ├── HANDOFF.md                        # This file
│   └── RELEASE-CADENCE.md                # Merge window / release window policy
└── dockerfiles/
    ├── python/{3.10,3.11,3.12,3.13,3.14}/Dockerfile
    ├── terminal/Dockerfile
    ├── webterm/Dockerfile
    ├── openvscode/Dockerfile
    ├── marimo/Dockerfile
    ├── carta/Dockerfile
    ├── carta-psrecord/Dockerfile
    └── firefly/
        ├── Dockerfile
        └── cadc-sso/             # vendored from opencadc/science-containers
            ├── settings.gradle
            ├── gradle.properties
            ├── gradle/{libs.versions.toml, wrapper/}
            ├── gradlew, gradlew.bat
            └── lib/{build.gradle, src/{main,test}/java/...}
```

Most image directories contain exactly one `Dockerfile`. The exception is
`firefly/`, which additionally vendors a small Gradle multi-project under
`cadc-sso/` to compile a Java SSO plugin layered onto upstream
`ipac/firefly`. The vendored sources come from
`opencadc/science-containers` and are owned upstream; we keep only four
narrowly scoped local edits — see §2.6 for the full list — three to
keep the plugin ABI-compatible with Firefly 2025.x (Tomcat 11), and one
to fix the auth scheme it sends to downstream CADC services (cookie
forwarding instead of the broken `Authorization: Bearer` path).

There are no separate `entrypoint.sh` / `startup.sh` files checked in for
the Debian-based images — all startup logic is written inline in the
Dockerfile via `RUN cat >…<<EOF` heredocs. Search for `startup.sh` in a
given Dockerfile to find the embedded script.

## 2. Image stack and inheritance

This section first sketches the dependency graph (§2.1), then walks
through how each image is actually built — base, key build steps, the
`ARG`s the workflow / Renovate care about, and what runtime contract
the image promises to Skaha (§2.2 – §2.7). If you only have time to
read one section, §2.1 is enough to operate the pipeline; the rest
matters when you're modifying a Dockerfile or debugging a build
failure.

### 2.1. Inheritance overview

All images are published to `images.canfar.net/cadc/` (CANFAR's Harbor
instance). The dependency chain is:

```
Docker Hub                        CANFAR Harbor
──────────                        ─────────────
python:<ver>-slim (pinned @sha) ▶ cadc/python:<ver>   (ver ∈ 3.10…3.14)
                                         │
                                         └─ (3.12 only) ▶ cadc/terminal:<RELEASE_TAG>
                                                                │
                                                                ├─ cadc/webterm:<RELEASE_TAG>
                                                                ├─ cadc/vscode:<RELEASE_TAG>
                                                                └─ cadc/marimo:<RELEASE_TAG>

ubuntu:24.04 (pinned @sha)      ▶ cadc/carta:<CARTA_TAG>
  + cartavis-team PPA             ▶ cadc/carta-psrecord:<CARTA_TAG>
                                  (both standalone; do NOT inherit from cadc/terminal;
                                   share CARTA_TAG -- upstream CARTA version, e.g. "5.1.0")

gradle:jdk21-alpine             ┐
  (builder, pinned @sha)        │
                                ├▶ cadc/firefly:<FIREFLY_TAG>
ipac/firefly:<ver> (pinned @sha)┘   (standalone; two-stage build; FIREFLY_TAG = upstream
  (final stage)                      ipac/firefly version, e.g. "2025.5")
```

- `cadc/python:<ver>` is tagged by Python version only (e.g.
  `cadc/python:3.12`). It is overwritten in place on every rebuild — no
  dated suffix.
- `cadc/terminal`, `cadc/webterm`, `cadc/vscode`, `cadc/marimo` are
  tagged with `<RELEASE_TAG>`, which the workflow generates as
  `$(date +'%y.%m')` — e.g. `26.04` for an April 2026 build.
- `cadc/carta` and `cadc/carta-psrecord` are both tagged with
  `<CARTA_TAG>`, the upstream CARTA version (e.g. `5.1.0`),
  **deliberately decoupled from `<RELEASE_TAG>`** so the tag reflects
  what astronomers install rather than our monthly cadence. CI derives
  `CARTA_TAG` from `dockerfiles/carta/Dockerfile`'s `ARG CARTA_VERSION`
  by stripping the `~noble1` PPA-rebuild suffix: `5.1.0~noble1 → 5.1.0`.
  Renovate updates `CARTA_VERSION` (via its `deb` datasource) in both
  `dockerfiles/carta/Dockerfile` and `dockerfiles/carta-psrecord/Dockerfile`
  in a single PR because the `# renovate:` annotation is identical; the
  shared tag follows automatically on the next rebuild.
- The `vscode` image is built from the `dockerfiles/openvscode/`
  directory (directory named `openvscode`, published image named
  `vscode`).
- Terminal is the only downstream image based on Python 3.12
  specifically. The other Python versions (3.10, 3.11, 3.13, 3.14) are
  published but not consumed elsewhere in this repo.
- `cadc/carta` and `cadc/carta-psrecord` are standalone leaves — they
  build from `ubuntu:24.04` (dictated by the cartavis-team PPA being
  Ubuntu-only) and do not inherit from `cadc/terminal`. `carta-psrecord`
  is a diagnostic sibling of `carta` (same CARTA binary, wrapped under
  `psrecord` for per-session CPU / memory / IO profiling); the two
  always track the same upstream CARTA version and retag together. The
  other images here are all Debian-based via `python:slim`.
- `cadc/firefly` is a third standalone leaf, with a two-stage build:
  a `gradle:jdk21-alpine` builder compiles `cadc-sso-lib-*.jar` from
  the vendored `cadc-sso/` Gradle project, and the final stage layers
  that jar into upstream `ipac/firefly:<FIREFLY_VERSION>`'s Tomcat
  webapp at `/usr/local/tomcat/webapps-ref/firefly/WEB-INF/lib/`. It
  does not inherit from `cadc/terminal` (Tomcat base, not Debian dev
  shell) and does not depend on the CARTA pair. The `cadc-sso/` sources
  are vendored from `opencadc/science-containers` with three small local
  edits, all narrowly scoped to keep the plugin ABI-compatible with
  upstream Firefly 2025.x (Tomcat 11): (1) the Caltech-IPAC firefly tag
  `cadc-sso` compiles against is lifted into a `def fireflyTag` with a
  Renovate annotation in `lib/build.gradle` and bumped to
  `release-2025.5.4`; (2) the servlet-API dep in `lib/build.gradle` is
  `jakarta.servlet:jakarta.servlet-api:6.1.0` (was
  `javax.servlet:javax.servlet-api:4.0.1`), matching what Firefly itself
  declares; (3) `TokenRelay.java` and its test import
  `jakarta.servlet.http.Cookie` (was `javax...`); (4)
  `TokenRelay#setAuthCredential` forwards the SSO token as a `Cookie`
  header (`ivoa_cookie` scheme) instead of as `Authorization: Bearer`,
  which CADC services reject as a malformed bearer. Without (2) and (3),
  the plugin hits a `NoSuchMethodError` on every outbound call inside
  `ipac/firefly:2025.5` because `RequestAgent.getCookie()` now returns
  `jakarta...Cookie`. Without (4), every TAP/SIA call hits a 401 from
  YouCAT and the user sees *"TAP service does not appear to exist or is
  not accessible"*. Tagged with the upstream `ipac/firefly` version
  (e.g. `2025.5`), same scheme as CARTA. **Pin invariant: `FIREFLY_VERSION`
  in the Dockerfile and `fireflyTag` in `lib/build.gradle` MUST stay in
  the same Firefly major-minor line; review their Renovate PRs together.**

Ports and entrypoints exposed by each interactive image:

| Image        | EXPOSE | ENTRYPOINT / CMD                                 |
|--------------|--------|---------------------------------------------------|
| `terminal`   | —      | inherits from `python` (no CMD override)          |
| `webterm`    | 5000   | `CMD ["/cadc/startup.sh"]`                        |
| `vscode`     | 5000   | `ENTRYPOINT ["/bin/bash", "-e", "/cadc/startup.sh"]` (runs as user `vscode`) |
| `marimo`     | 5000   | `ENTRYPOINT ["/bin/bash", "-e", "/cadc/startup.sh"]` |
| `carta`      | 3002   | `CMD ["carta", "--no_browser"]` (Skaha's `carta` session launcher overrides `CMD` and supplies `--port`, `--http_url_prefix`, `--top_level_folder`, `--debug_no_auth`, `--idle_timeout`, `--enable_scripting`, and the starting folder per-session) |
| `carta-psrecord` | 3002 | `CMD ["/carta/start.sh"]` (wrapper execs `psrecord carta … --include-io --include-children --interval 1`; re-specifies Skaha's flags from `SKAHA_TOP_LEVEL_DIR` / `SKAHA_PROJECTS_DIR` / `SKAHA_SESSION_URL_PATH` because `carta` is no longer PID 1) |
| `firefly`    | 8080   | inherited from `ipac/firefly` (Tomcat startup); environment-driven config (`PROPS_sso__framework__adapter`, `CADC_SSO_COOKIE_*`, `CADC_ALLOWED_DOMAIN`, `baseURL`, `PROPS_FIREFLY_OPTIONS`) is supplied by the Skaha-side Deployment manifest, not baked into the image |

### 2.2. `python` — the Debian Python foundation

**Source:** `dockerfiles/python/{3.10,3.11,3.12,3.13,3.14}/Dockerfile`.
The five files are copies of each other, differing only in the `FROM`
line (Python version + matching `@sha256:` digest) and the title
LABEL. There is no shared "base" Dockerfile — Renovate updates each
file independently, which deliberately decouples Python releases.

**Base:** `python:<ver>-slim` from Docker Hub, **digest-pinned** via a
`# renovate: datasource=docker depName=python` annotation. `slim` is
the minimal Debian-based variant (no build tools, no man pages).
3.14 currently uses `python:3.14-rc-slim` and a comment in the file
notes that the tag should be moved to `3.14-slim` once 3.14 GAs.

**Three-stage build:**

1. Stage `pixi` — `FROM ghcr.io/prefix-dev/pixi:<ver>@sha256:…`. Used
   only to extract the pre-compiled `pixi` binary.
2. Stage `uv` — `FROM ghcr.io/astral-sh/uv:<ver>@sha256:…`. Same
   trick for `uv` and `uvx`.
3. Stage `base` — the actual `python:<ver>-slim`. `COPY --from=…`
   pulls the `pixi`, `uv`, and `uvx` binaries into `/usr/local/bin/`.

The reason for the multi-stage shape (rather than `curl | sh`-style
installers) is that pixi and uv ship official OCI images of just
their static binaries, so we get a deterministic, digest-pinned copy
for free without having to reach for `wget`/`tar`/version negotiation
inside this image.

**Environment baked in:** `UV_PYTHON_INSTALL_DIR`, `UV_PYTHON_BIN_DIR`,
`UV_TOOL_DIR`, `UV_TOOL_BIN_DIR`, `PIXI_HOME`, `PIXI_BIN_DIR`,
`PIXI_CACHE_DIR` are all pointed at `/usr/local/...` so anything `uv`
or `pixi` install lands in a system-wide path visible to every user
in the container, not in `~/.local`.

**No CMD / ENTRYPOINT:** `python:slim`'s defaults are inherited.
Tags are overwritten in place each rebuild (no dated suffix); see
§4 "What pushes go where".

### 2.3. `terminal` — interactive CLI environment

**Source:** `dockerfiles/terminal/Dockerfile`. **Base:**
`${REGISTRY}/cadc/python:${PYTHON_VERSION}` (default `3.12`). When
built locally, this means the locally-built `cadc/python:3.12` is
required first; under bake (§3), the same trick that wires
webterm → terminal is *not* used here — `terminal` simply pulls
`cadc/python:3.12` from Harbor (or uses what's in the local Docker
image cache).

**Build steps in order:**

1. `ARG REGISTRY=images.canfar.net` and `ARG PYTHON_VERSION=3.12` are
   declared *before* the `FROM` so the registry and Python-major
   pin are interpolated into the parent image reference. (Standard
   Docker quirk: pre-`FROM` `ARG`s are only visible to `FROM` itself
   — they would need to be re-declared after `FROM` to be readable
   from later `RUN`s, but here the values aren't needed downstream.)
2. `apt-get install` a fixed set of CLI packages — `acl`,
   `bash-completion`, `ca-certificates`, `curl`, `git`, `htop`,
   `wget`, plus the unpinned `locales`. Each pinned package has a
   `# renovate: datasource=repology depName=debian_13/<pkg>
   versioning=deb` annotation directly above its `ARG`. Renovate
   queries Repology's `debian_13` (Debian Trixie, the base of
   `python:slim`) to bump the pin. `locales` is unpinned because
   Repology does not expose it as a standalone project (it ships
   from the `glibc` source package).
3. `locale-gen en_US.UTF-8` — without this, Python and curses-based
   tools warn about Unicode at startup.
4. Two large `printf > /etc/profile.d/terminal.sh` and
   `>> /etc/bash.bashrc` heredocs install:
   - shell aliases (`py`, `ll`, `la`, `..`, `...`, safe `rm`/`cp`/`mv`),
   - `dircolors` for `ls --color`,
   - `uv` and `pixi` bash completion (generated dynamically at shell
     startup, so a `uv` upgrade picks up new flags without a rebuild),
   - persistent bash history with `histappend`.

**Environment:** `LANG=en_US.UTF-8`, `LC_ALL=en_US.UTF-8`,
`TERM=xterm-256color`.

**No CMD / ENTRYPOINT:** users invoke `bash` themselves; on Skaha,
the platform launches whatever it likes against this image.

### 2.4. `webterm`, `vscode`, `marimo` — three terminal-derived siblings

All three live under their own `dockerfiles/<name>/Dockerfile` and
share the same shape: **`FROM ${REGISTRY}/cadc/terminal:${BASE_TAG}`**,
add a small fixed apt set on top, then drop in one application
binary plus a `/cadc/startup.sh`. Common build steps across all
three:

- `ARG REGISTRY` and `ARG BASE_TAG` are declared before `FROM` so
  the parent reference `${REGISTRY}/cadc/terminal:${BASE_TAG}` can
  interpolate. Bake substitutes the locally-built `terminal` target
  for that reference at build time (see §3).
- `apt-get install` a Renovate-pinned set: `emacs-nox`, `unzip`,
  `nano`, `tmux`, `vim-nox`, `procps`, `nodejs`, `npm`. (Marimo
  drops a few of those it doesn't need; vscode adds `jq` and
  `libatomic1`.)
- Install Starship 1.24.x via its official `install.sh` and write
  `/etc/starship.toml` with the same Gruvbox palette across all
  three — this keeps the in-app terminal's prompt visually identical
  whether the user lands in webterm, vscode's integrated terminal,
  or marimo's Ctrl+J terminal.

What differs:

- **`webterm`** — Adds a Stage 1 `FROM tsl0922/ttyd:<ver>` whose only
  purpose is `COPY --from=ttyd-bin /usr/bin/ttyd /usr/local/bin/ttyd`.
  Then `npm install -g` four AI CLIs (GitHub Copilot CLI,
  Claude Code, Gemini CLI, OpenAI Codex), `curl ... opencode.ai/install`
  for OpenCode, and `curl ... cursor.com/install` for the Cursor
  CLI agent. The runtime startup script execs
  `ttyd ... tmux new-session -A -s canfar`, which gives the user a
  reattachable bash login shell inside the browser. `EXPOSE 5000`,
  `CMD ["/cadc/startup.sh"]`. Six application-level
  `ARG <NAME>_VERSION` pins are tracked: `STARSHIP_VERSION`,
  `OPENCODE_VERSION`, `COPILOT_CLI_VERSION`, `CLAUDE_CODE_VERSION`,
  `GEMINI_CLI_VERSION`, `CODEX_CLI_VERSION` (datasources
  `github-releases` and `npm`).
- **`vscode`** — Downloads and untars
  `gitpod-io/openvscode-server` at a `# renovate: datasource=github-releases`-tracked
  tag into `/opt/openvscode-server`. Writes
  `/opt/openvscode-server/data/Machine/settings.json` to force
  bash as the integrated-terminal profile (works around CANFAR
  setting `SHELL=/sbin/nologin`). Startup script honours the
  `skaha_sessionid` env var by passing
  `--server-base-path /session/contrib/$skaha_sessionid` so the
  IDE's URLs match the session-scoped reverse proxy. `EXPOSE 5000`,
  `USER vscode` (UID 1000 — overridden by Skaha at runtime),
  `ENTRYPOINT ["/bin/bash", "-e", "/cadc/startup.sh"]`. **Directory
  named `openvscode/`, image published as `cadc/vscode`** — the
  bake target maps the two.
- **`marimo`** — Smaller. After the apt+starship base layer, just
  `uv pip install --system marimo==${MARIMO_VERSION}`
  (`renovate: datasource=pypi`). Startup script execs
  `marimo --log-level INFO edit --no-token --port 5000 --host 0.0.0.0
  --skip-update-check --headless`. `EXPOSE 5000`, `ENTRYPOINT
  ["/bin/bash", "-e", "/cadc/startup.sh"]`.

All three also do `WORKDIR /build_info && COPY Dockerfile
/build_info/ && uv pip freeze > /build_info/pip.list` so a running
container can be inspected with `cat /build_info/Dockerfile` to see
the exact recipe it was built from — useful when a user reports an
issue and the operator wants to reproduce locally.

**Why the same `terminal` image is the parent and not three
separate Python copies:** keeps the apt-base layer cached between
rebuilds and cuts ~150 MiB off each downstream image. The cost is
the bake-`contexts` indirection in §3, which has to substitute the
`FROM cadc/terminal:<tag>` reference at build time.

### 2.5. `carta` and `carta-psrecord` — standalone Ubuntu pair

Both Dockerfiles live under `dockerfiles/carta/` and
`dockerfiles/carta-psrecord/`. Neither inherits from `terminal`
because CARTA is distributed only via the cartavis-team PPA for
Ubuntu and the package is not rebuilt for Debian.

**Common base:** `ubuntu:24.04@sha256:…` (digest-pinned,
`# renovate: datasource=docker depName=ubuntu`). Both files share
the same digest because Renovate updates them in lockstep — the
annotation is identical.

**Common build steps:**

1. `apt-get install ca-certificates software-properties-common`.
   `ca-certificates` is pinned via
   `# renovate: datasource=repology depName=ubuntu_24_04/ca-certificates`
   (security-relevant: it's the trust root for the `add-apt-repository`
   HTTPS fetch of the PPA). `software-properties-common` is
   intentionally unpinned and purged in the same `RUN` — Repology
   does not expose it as a standalone Ubuntu project.
2. `add-apt-repository -y ppa:cartavis-team/carta` then
   `apt-get install carta=${CARTA_VERSION}`. `CARTA_VERSION` is
   tracked by **Renovate's `deb` datasource** pointed at
   `https://ppa.launchpadcontent.net/cartavis-team/carta/ubuntu`
   with `?suite=noble&components=main&binaryArch=amd64`. This is
   the only `datasource=deb` pin in the repo; everything else
   uses `repology`.
3. `apt-get purge -y --auto-remove software-properties-common` —
   keeps the final image lean.
4. `WORKDIR /carta && chmod -R a+rwx /carta`. `ENV HOME=/carta`,
   `ENV CARTA_DOCKER_DEPLOYMENT=1`.
5. `EXPOSE 3002` (CARTA's upstream default; Skaha re-specifies the
   port at runtime).

What differs:

- **`carta`** — Ends with a deliberately bare
  `CMD ["carta", "--no_browser"]`. Skaha's `carta` session launcher
  overrides this with a long flag list (`--port`,
  `--http_url_prefix`, `--top_level_folder`, `--debug_no_auth`,
  `--idle_timeout`, `--enable_scripting`, starting folder).
  **Adding any of those flags here has caused Bad Gateway / routing
  failures in the past** and is documented as a do-not-do in the
  Dockerfile's comments.
- **`carta-psrecord`** — Adds `python3-pip` to the apt set (kept in
  the final image because `psrecord` imports `psutil` and
  `matplotlib` at runtime), then
  `pip3 install --no-cache-dir --break-system-packages
  psrecord==${PSRECORD_VERSION} matplotlib==${MATPLOTLIB_VERSION}`
  (`# renovate: datasource=pypi` for both).
  `--break-system-packages` is required by Ubuntu 24.04's PEP 668
  marker; acceptable here because this is a single-purpose image
  with no other Python consumers. Then a BuildKit heredoc
  (`RUN <<RUN_EOF / cat > /carta/start.sh <<'SCRIPT' ... SCRIPT /
  RUN_EOF`) writes a wrapper that:
  - reconstructs the full `carta` argv from `SKAHA_TOP_LEVEL_DIR`,
    `SKAHA_PROJECTS_DIR`, `SKAHA_SESSION_URL_PATH`, `CARTA_PORT`,
    `CARTA_IDLE_TIMEOUT` (because `carta` is no longer PID 1, Skaha's
    CMD-override no longer reaches it directly),
  - execs `psrecord <argv> --log <ts>_carta-backend.log
    --plot <ts>_carta-backend.png --include-io --interval 1
    --include-children` writing under `${HOME}/.carta_logs/`,
  - optionally caps the run at `PSRECORD_DURATION_SECONDS`.
  The final `CMD ["/carta/start.sh"]` is the wrapper, not `carta`
  itself.

**`CARTA_TAG` derivation.** Both Dockerfiles pin
`CARTA_VERSION=5.1.0~noble1` (the `~noble1` suffix is the PPA
rebuild marker). The CI workflow's "Derive CARTA tag" step strips
the suffix and exports `CARTA_TAG=5.1.0`, which `docker-bake.hcl`
applies to both image tags. The two images therefore always carry
the same Harbor tag and are pushed together. Renovate updating
`CARTA_VERSION` in either file opens a single PR touching both
because the `# renovate:` annotation is identical.

### 2.6. `firefly` — IPAC Firefly + CADC SSO plugin

**Source:** `dockerfiles/firefly/Dockerfile` plus the vendored
`dockerfiles/firefly/cadc-sso/` Gradle multi-project (15 files —
`settings.gradle`, `gradle.properties`, `gradle/libs.versions.toml`,
`gradle/wrapper/`, `gradlew`, `gradlew.bat`, `lib/build.gradle`,
`lib/src/{main,test}/java/org/opencadc/security/sso/...`).
The image is the only one in the repo that ships compiled Java
code we built from source.

**Two-stage build:**

1. Stage `builder` —
   `FROM gradle:${GRADLE_VERSION}@sha256:…`, default
   `GRADLE_VERSION=8-jdk21-alpine`. **The 8.x pin matters.** Gradle
   9.x removed the `exec { ... }` API used inside the upstream
   `lib/build.gradle`'s `doLast { exec { commandLine 'git', 'clone',
   ... } }` block. The pin keeps the upstream build script
   working unmodified, which is the design goal — we want `cadc-sso/`
   to stay a clean fork of `opencadc/science-containers`. Renovate
   tracks this via `# renovate: datasource=docker depName=gradle`.
   The stage's single `RUN` is `gradle build --info && ls -l
   lib/build/libs/cadc-sso-*.jar`. Internally, `gradle build`
   triggers the task chain defined in `lib/build.gradle`:
   - `cloneFirefly` — `git clone --depth 1
     https://github.com/Caltech-IPAC/firefly.git
     --branch=${fireflyTag} <fireflyDir>`. **`fireflyTag` is a
     `def` literal in `lib/build.gradle` annotated with
     `// renovate: datasource=github-tags
     depName=Caltech-IPAC/firefly`** — picked up by the second
     custom-regex manager in `renovate.json` (§5.2). Currently
     `release-2025.5.4`.
   - `buildFireflyJar` / `linkFireflyJar` — produce `firefly.jar`
     and stage it under a `fileTree`-resolved `lib/` directory so
     `cadc-sso-lib` can `implementation` it as a compile-time
     dependency.
   - `compileJava` — compiles `TokenRelay.java` against
     `firefly.jar` plus
     `jakarta.servlet:jakarta.servlet-api:6.1.0`. Tests link
     `jakarta.platform:jakarta.jakartaee-web-api:10.0.0` and run
     under JUnit + Mockito.
   - `jar` — emits `lib/build/libs/cadc-sso-lib-0.1.jar` (~10 KiB).
2. Stage runtime —
   `FROM ipac/firefly:${FIREFLY_VERSION}@sha256:…`, default
   `FIREFLY_VERSION=2025.5`. Renovate tracks via
   `# renovate: datasource=docker depName=ipac/firefly`. Single
   `COPY --from=builder /firefly/cadc-sso/lib/build/libs/cadc-sso-*.jar
   /usr/local/tomcat/webapps-ref/firefly/WEB-INF/lib/`. Tomcat
   picks up the jar at startup; the `org.opencadc.security.sso.TokenRelay`
   class is then available to be selected by the
   `PROPS_sso__framework__adapter` env var that Skaha passes in.
   `EXPOSE 8080`. CMD/ENTRYPOINT inherited from upstream
   `ipac/firefly`.

**Critical pin invariant.** `FIREFLY_VERSION` (Dockerfile, runtime
stage) and `fireflyTag` (`lib/build.gradle`, builder stage) must
stay in the same Firefly major-minor line because they bracket the
same servlet API. `ipac/firefly:2025.5` runs on Tomcat 11
(`jakarta.servlet`); `release-2025.5.4` of the upstream Firefly
source declares `jakarta.servlet-api:6.1.0`. Compiling cadc-sso
against an older `release-2024.3.x` (Tomcat 9 / `javax.servlet`) and
running it inside `ipac/firefly:2025.x` produces
`NoSuchMethodError: 'javax.servlet.http.Cookie
edu.caltech.ipac.firefly.server.RequestAgent.getCookie(java.lang.String)'`
on every outbound call from TokenRelay — this is exactly the bug
that motivated the local edits to the vendored `cadc-sso/`. **Review
the two Renovate PRs together when both bump.**

**The four local edits to vendored `cadc-sso/`** (everything else
is verbatim from `opencadc/science-containers`):

1. `lib/build.gradle` — lifts the Caltech-IPAC tag into a
   `def fireflyTag = 'release-2025.5.4'` with a `// renovate:`
   annotation, so Renovate can bump it. Upstream hardcodes the tag
   inline.
2. `lib/build.gradle` — replaces
   `javax.servlet:javax.servlet-api:4.0.1` with
   `jakarta.servlet:jakarta.servlet-api:6.1.0`, and
   `javax.websocket:javax.websocket-api:1.1` with
   `jakarta.platform:jakarta.jakartaee-web-api:10.0.0`. Matches
   what Firefly 2025.x itself declares.
3. `lib/src/main/java/.../TokenRelay.java` and
   `lib/src/test/java/.../TokenRelayTest.java` — `import
   jakarta.servlet.http.Cookie;` instead of `import
   javax.servlet.http.Cookie;`.
4. `lib/src/main/java/.../TokenRelay.java#setAuthCredential` —
   forwards the SSO token to the downstream service as a **cookie**
   (`inputs.setCookie(SSO_COOKIE_NAME, token.getId())`) instead of as
   `Authorization: Bearer <token>`. The upstream Bearer path is
   incompatible with current CADC services: YouCAT (and friends)
   advertise their bearer endpoint as `WWW-Authenticate: ivoa_bearer
   ... HACK=temporary` and expect a real OIDC/JWT obtained from
   `https://ws-cadc.canfar.net/ac/login`. Sending the opaque
   `CADC_SSO` cookie value as a bearer triggers a hard `401` even on
   anonymous endpoints like `/capabilities`, which Firefly surfaces
   as *"TAP service does not appear to exist or is not accessible"*.
   The cookie path uses the `ivoa_cookie` SSO scheme that every CADC
   service supports natively, so anonymous endpoints stay anonymous
   and authenticated endpoints authenticate cleanly. The matching
   `TokenRelayTest#testSetAuthCredentialForwardsCookie` test pins the
   contract.

#### Re-syncing `cadc-sso/` from upstream

The `dockerfiles/firefly/cadc-sso/` tree is vendored from
[`opencadc/science-containers`](https://github.com/opencadc/science-containers/tree/main/science-containers/Dockerfiles/firefly/cadc-sso),
not pulled at build time. Upstream owns the design of the SSO
adapter; we only carry the four edits listed above. When upstream
publishes meaningful changes (a new Firefly major-minor line, a
servlet-API bump, a new task in `lib/build.gradle`, a refactor of
`TokenRelay.java`, etc.) we need to fold them in without losing our
edits. Use this recipe.

**Signals that a re-sync is due:**

- A new Firefly major-minor line is out (e.g. `2026.x`) and we want
  to bump `FIREFLY_VERSION` past it. Upstream `cadc-sso` typically
  ships an associated `fireflyTag` / servlet-API bump in the same
  cadence; staying behind risks compile or runtime drift.
- A CVE in a transitive dep (log4j, mockito, palantir-java-format,
  spotless) is announced. Renovate's `gradle` manager will normally
  open a PR; cross-check against upstream `libs.versions.toml` so we
  don't drift in the *opposite* direction from upstream.
- An issue is filed against `opencadc/science-containers` describing
  a TokenRelay bug (cookie domain handling, anonymous-endpoint regression,
  etc.) and the fix lands in their `cadc-sso/`.

There is no automation that *detects* upstream commits to `cadc-sso/`
— Renovate only tracks the `fireflyTag` literal and the Maven deps,
not the surrounding Java/Gradle source. Glance at upstream's
`science-containers` repo at least once per Firefly major-minor cycle
(roughly every 3 – 6 months in practice).

**Recipe:**

```bash
# 1. From a clean working tree on a fresh branch.
cd /path/to/canfar-containers
git checkout main && git pull
git checkout -b chore/cadc-sso-resync-<YYYYMM>

# 2. Snapshot upstream's cadc-sso into a scratch dir for diffing.
TMP=$(mktemp -d)
git clone --depth 1 https://github.com/opencadc/science-containers.git "$TMP/sc"
UPSTREAM="$TMP/sc/science-containers/Dockerfiles/firefly/cadc-sso"
LOCAL="dockerfiles/firefly/cadc-sso"

# 3. See exactly what changed since our last sync.
diff -urN "$LOCAL" "$UPSTREAM" | less
# Or, file-by-file:
diff -u "$LOCAL/lib/build.gradle"                        "$UPSTREAM/lib/build.gradle"
diff -u "$LOCAL/lib/src/main/java/.../TokenRelay.java"   "$UPSTREAM/lib/src/main/java/.../TokenRelay.java"
diff -u "$LOCAL/gradle/libs.versions.toml"               "$UPSTREAM/gradle/libs.versions.toml"

# 4. Identify which hunks are upstream changes vs. our four edits.
#    Our four edits are deterministic; everything else is upstream.
#    See the "four local edits" list immediately above this section.

# 5. Wholesale-replace cadc-sso/ with upstream, then re-apply our edits.
rm -rf "$LOCAL"
cp -a "$UPSTREAM" "$LOCAL"
```

Then re-apply the four local edits (the only divergence we carry):

| # | File | Change |
|---|------|--------|
| 1 | `lib/build.gradle` | Lift the hardcoded `--branch=release-…` argument inside the `cloneFirefly` task into a top-level `def fireflyTag = '<value>'` with a `// renovate: datasource=github-tags depName=Caltech-IPAC/firefly` annotation directly above it. Bump the value to the latest stable upstream Firefly tag matching `FIREFLY_VERSION` in `dockerfiles/firefly/Dockerfile`. |
| 2 | `lib/build.gradle` | In the `dependencies { … }` block: replace `javax.servlet:javax.servlet-api:4.0.1` with `jakarta.servlet:jakarta.servlet-api:6.1.0` (or whatever Firefly itself currently declares — check `Caltech-IPAC/firefly` `buildScript/dependencies.gradle` at the pinned tag). Replace `javax.websocket:javax.websocket-api:1.1` with `jakarta.platform:jakarta.jakartaee-web-api:10.0.0`. |
| 3 | `lib/src/main/java/org/opencadc/security/sso/TokenRelay.java` and `lib/src/test/java/.../TokenRelayTest.java` | Change `import javax.servlet.http.Cookie;` to `import jakarta.servlet.http.Cookie;` in both files. |
| 4 | `lib/src/main/java/.../TokenRelay.java` (`setAuthCredential` method) | Replace the upstream Bearer-token path with `inputs.setCookie(SSO_COOKIE_NAME, token.getId());`. The corresponding test `TokenRelayTest#testSetAuthCredentialForwardsCookie` pins the contract — keep it. |

```bash
# 6. Verify the build still compiles end-to-end (~5 min on a warm cache,
#    ~15-20 min from scratch — the in-build Caltech-IPAC clone dominates).
docker buildx bake firefly --no-cache --progress=plain

# 7. Smoke-test the resulting image: confirm the jar is in place and the
#    TokenRelay class compiled.
docker run --rm --entrypoint /bin/sh images.canfar.net/cadc/firefly:local \
  -c 'ls -la /usr/local/tomcat/webapps-ref/firefly/WEB-INF/lib/cadc-sso-*.jar'
# Expected: a single cadc-sso-lib-0.1.jar of ~3-10 KiB.

# 8. Commit. Keep the upstream-replay commit and the local-edits-replay
#    commit separate so future bisects can isolate which side broke.
git add dockerfiles/firefly/cadc-sso/
git commit -m "chore(cadc-sso): re-sync from opencadc/science-containers@<short-sha>"
# Then re-apply edits and:
git commit -m "chore(cadc-sso): re-apply 4 local edits (jakarta.servlet + cookie auth)"

# 9. Open the PR during the merge window (days 5–27, see RELEASE-CADENCE).
#    Cross-link the upstream commit so reviewers can see what we picked up.
```

**What can go wrong:**

- **Upstream removes the `cloneFirefly` / `buildFireflyJar` task chain
  in favor of a Maven Central artifact for `firefly.jar`.** Our `def
  fireflyTag` literal would no longer be needed; replace edit (1) with
  whatever annotation tracks the new dependency. Update §2.6's
  "Two-stage build" description to match.
- **Upstream removes the Gradle 8.x-only `exec { … }` block.** The
  `GRADLE_VERSION=8-jdk21-alpine` pin in the Dockerfile becomes
  optional; consider bumping to a 9.x line in the same PR.
- **Upstream switches servlet API again** (e.g. Tomcat 12 ships with
  a different namespace). Update the imports in `TokenRelay.java`
  *and* the dependency line in `lib/build.gradle` *and* the runtime
  `FIREFLY_VERSION` pin together — the three are coupled.
- **Upstream changes the `setAuthCredential` signature.** Our cookie
  path (edit 4) is method-body-local; if the method is renamed or
  splits into two, mirror the change but keep `inputs.setCookie(…)`
  in the relevant codepath. The `TokenRelayTest#testSetAuthCredentialForwardsCookie`
  test must still pass — that's the line in the sand.

If after a re-sync the only diff between `dockerfiles/firefly/cadc-sso/`
and upstream `opencadc/science-containers/.../cadc-sso/` is the four
edits above, the sync was clean. Anything else is either an upstream
change we haven't picked up yet (re-do the sync) or a local change that
should either be promoted to upstream as a PR or explicitly added to
this list.

**Runtime contract.** The image expects Skaha's Deployment manifest
to set `PROPS_sso__framework__adapter=org.opencadc.security.sso.TokenRelay`,
`CADC_SSO_COOKIE_NAME=CADC_SSO`, `CADC_SSO_COOKIE_DOMAIN=.canfar.net`,
`CADC_ALLOWED_DOMAIN=.canfar.net`, `baseURL=/session/notebook/firefly/`,
plus a `PROPS_FIREFLY_OPTIONS` JSON blob with TAP service
pre-configuration. None of those are baked into the image. See §9
item 10 for the full Skaha-side pending-confirmation list.

**Build cost.** ~10–20 minutes wall-clock on GitHub-hosted runners
(the Caltech-IPAC clone is the dominant cost, not the actual
compile). The `interactive-stack` job caches Docker layers via
`type=gha`, so a rebuild that doesn't touch `cadc-sso/` re-uses the
builder stage.

### 2.7. Image tagging summary

For quick reference, here is what tag each image carries and why:

| Image                      | Tag value     | Source of truth (file → ARG)                                                  | Overwritten in place? |
|----------------------------|---------------|-------------------------------------------------------------------------------|------------------------|
| `cadc/python:<ver>`        | Python ver    | filename suffix (`3.10`, ..., `3.14`)                                         | yes (no dated suffix)  |
| `cadc/terminal:<YY.MM>`    | release tag   | `setup` job: `date -u +'%y.%m'`                                                | no (per month)         |
| `cadc/webterm:<YY.MM>`     | release tag   | same                                                                          | no                     |
| `cadc/vscode:<YY.MM>`      | release tag   | same                                                                          | no                     |
| `cadc/marimo:<YY.MM>`      | release tag   | same                                                                          | no                     |
| `cadc/carta:<x.y.z>`       | upstream CARTA| `dockerfiles/carta/Dockerfile` → `CARTA_VERSION` (strip `~noble1`)            | per-version (overwritten on PPA rebuild) |
| `cadc/carta-psrecord:<x.y.z>` | upstream CARTA| same source as `carta` (shared tag)                                         | per-version            |
| `cadc/firefly:<x.y>`       | upstream Firefly | `dockerfiles/firefly/Dockerfile` → `FIREFLY_VERSION`                       | per-version            |

The two version-tagged images (`carta`/`carta-psrecord` and
`firefly`) *can* be re-pushed at the same tag if a Renovate PR bumps
something other than the upstream version (e.g. `psrecord`,
`matplotlib`, `cadc-sso` Java deps, or an apt security patch in the
underlying Ubuntu / Tomcat layer). This mirrors the Python-tag
overwrite policy and is documented in §4 "What pushes go where".

## 3. Build orchestration

Two build mechanisms coexist:

**a) `docker/build-push-action` for the Python matrix.**
The five Python version images are independent; they're built in
parallel as a matrix job in the workflow. Each version lives in its own
`dockerfiles/python/<ver>/Dockerfile` and has no dependency on the other
versions.

**b) `docker buildx bake` for the interactive stack.**
`docker-bake.hcl` defines seven targets (`terminal`, `webterm`, `vscode`,
`marimo`, `carta`, `carta-psrecord`, `firefly`). For webterm / vscode /
marimo the key mechanism is the `contexts` block, which wires each
downstream target to the locally-built terminal:

```hcl
target "webterm" {
  contexts = {
    "${REGISTRY}/cadc/terminal:${RELEASE_TAG}" = "target:terminal"
  }
  …
}
```

This tells bake: "when the webterm Dockerfile says
`FROM images.canfar.net/cadc/terminal:26.04`, substitute the
locally-built `terminal` target instead of pulling from the registry."

This trick is what allows the CI pipeline to build and push all four
terminal-derived interactive images in a single bake invocation without
ever pushing an intermediate terminal tag to the registry first. It also
means the workflow's `detect-changes` job must always include `terminal`
in the bake target list whenever any downstream target is selected, or
the bake substitution won't apply and the build will attempt a registry
pull. This invariant is enforced explicitly in the workflow; see §4.

The fifth and sixth targets, `carta` and `carta-psrecord`, are
standalone leaves — they have no `contexts` block and build directly
from `ubuntu:24.04` (plus the cartavis-team PPA). They do not force a
terminal rebuild and are not affected by terminal changes; selecting
them in isolation will not pull `terminal` into the bake target list.
`carta-psrecord` adds `psrecord` + `matplotlib` (pinned via PyPI) on
top of the same CARTA install and ships a `/carta/start.sh` wrapper
that runs `carta` under `psrecord`. Both carta targets share
`CARTA_TAG` and are rebuilt together whenever either directory (or
`docker-bake.hcl`) changes — the `detect-changes` job couples them so
Renovate bumping the shared `CARTA_VERSION` pin always updates both
Harbor repos in lockstep.

The seventh target, `firefly`, is also a standalone leaf, with a
distinct shape from everything else in the stack: it's a two-stage
Dockerfile where a `gradle:jdk21-alpine` builder compiles a small
Java SSO plugin (`cadc-sso-lib-*.jar`) from the vendored
`dockerfiles/firefly/cadc-sso/` Gradle project, and the final stage
layers that jar onto upstream `ipac/firefly:<FIREFLY_VERSION>`. The
gradle build step also clones `Caltech-IPAC/firefly` at a pinned tag
(tracked by Renovate via a `// renovate:` annotation in
`cadc-sso/lib/build.gradle`) to obtain `firefly.jar` as a compile-time
dependency for the SSO plugin. `firefly` does not cascade with any
other target; it tags as `cadc/firefly:<FIREFLY_TAG>` with `FIREFLY_TAG`
derived from the Dockerfile's `FIREFLY_VERSION` arg. Build cost is
the highest in the stack (~10–20 min wall-clock on GitHub-hosted
runners because of the in-build Caltech-IPAC clone + jar build), but
it only runs on day 3 when the Dockerfile, vendored Java sources, or
Caltech-IPAC tag pin actually change, which in steady state is at
most a few times per year.

## 4. CI/CD workflow

Single workflow: [`.github/workflows/image-pipeline.yml`](../.github/workflows/image-pipeline.yml).

### Triggers

| Trigger             | Condition                                                                             |
|---------------------|---------------------------------------------------------------------------------------|
| `schedule`          | Three crons: `0 6 1 * *`, `0 6 2 * *`, `0 6 3 * *` — days 1/2/3, 06:00 UTC            |
| `push`              | To `main`, only when `dockerfiles/**`, the workflow, or `docker-bake.hcl` change      |
| `pull_request`      | Same path filter as push (plus `renovate.json`)                                       |
| `workflow_dispatch` | Manual trigger from the Actions tab                                                   |

The three `schedule` crons implement a **staggered release window**
(day 1 → python, day 2 → terminal, day 3 → interactive stack
including `webterm`, `vscode`, `marimo`, the standalone `carta` /
`carta-psrecord` pair, and standalone `firefly`), with a release
anchor tag (`release/YY.MM`) pushed on day 3. On `schedule`, a
**phase gate** restricts each day to its own subset of images.

On `schedule` and `workflow_dispatch`, `detect-changes` diffs `HEAD`
against the previous month's `release/YY.MM` git tag to decide which
images actually need rebuilding. Unchanged images are skipped. If the
previous tag is missing (first run, or tag was deleted), the workflow
falls back to rebuilding everything in the current phase.

On `push` and `pull_request`, the existing `dorny/paths-filter`
cascade is used unchanged — no phase gate, no anchor-tag diff. PR
builds never push to the registry.

See [`RELEASE-CADENCE.md`](RELEASE-CADENCE.md) for the calendar,
rules, and rationale.

### Jobs

The workflow defines six jobs that fan out from a short setup stage:

1. **`setup`** — generates `RELEASE_TAG=$(date -u +'%y.%m')` once so
   every downstream job shares the same tag.
2. **`detect-changes`** — computes which images need to be built.
   Behavior depends on the trigger:
   - **schedule**: maps the cron that fired to a phase (`python` /
     `terminal` / `interactive`), diffs `HEAD` against the previous
     month's `release/YY.MM` git tag, and emits only the images in
     this phase that actually changed. If the previous tag is missing,
     falls back to rebuilding all images in the current phase.
   - **workflow_dispatch**: uses the same release-tag diff but emits
     every changed image across all phases (no phase gate).
   - **push** / **pull_request**: uses `dorny/paths-filter@v3` on the
     pushed commits (unchanged from the pre-cadence behavior).
   Resolves the dependency cascade in all modes:
   - A change under `dockerfiles/python/3.12/**` forces `terminal` +
     all Debian-based downstream (webterm/vscode/marimo) to rebuild
     (terminal is `FROM cadc/python:3.12`).
   - A change to `dockerfiles/terminal/**` or `docker-bake.hcl`
     cascades into `webterm` + `vscode` + `marimo`.
   - Other Python versions (3.10, 3.11, 3.13, 3.14) don't cascade.
   - **The CARTA subsystem (`carta` + `carta-psrecord`) is a standalone
     leaf.** Their rebuild trigger is either CARTA directory or
     `docker-bake.hcl`; they do not cascade from `terminal` or `python`,
     and changes to them do not cascade elsewhere. The two images
     share the upstream CARTA version pin and **always rebuild together**
     — a change to either `dockerfiles/carta/` or
     `dockerfiles/carta-psrecord/` flags both. They share day 3 of the
     release window with the terminal-derived interactive stack but
     are phase-gated independently.
   - **`firefly` is also a standalone leaf.** Rebuild trigger is
     `dockerfiles/firefly/**` (Dockerfile + vendored `cadc-sso/` Java
     sources + Renovate-tracked Caltech-IPAC tag pin in `build.gradle`)
     or `docker-bake.hcl`. No cascade in either direction; not coupled
     to the CARTA pair. Shares day 3 of the release window with the
     other interactive-stack images, phase-gated independently.
   - If any of `webterm`/`vscode`/`marimo` is selected, `terminal` is
     force-added to the bake target list (see §3). The CARTA subsystem
     and `firefly` do NOT force terminal; all three subsystems are
     independent.
   - **Freshness override (age-based forced rebuild).** On scheduled
     runs, if the previous month's `release/<YY.MM>` tag is older than
     `FORCED_REBUILD_AGE_DAYS` (default 45), every image in today's
     phase is rebuilt regardless of file diff. This guarantees apt
     security patches eventually propagate even when no Renovate PR
     has triggered a file change (e.g. Canonical batches security
     fixes without re-publishing the `ubuntu:24.04` tag's digest, so
     Renovate sees no bump and CARTA would otherwise sit stale). The
     phase gate still applies — so on day 3 only the interactive
     stack gets the force, on day 2 only terminal, etc. The override
     does **not** apply to push / PR / workflow_dispatch events.
   Emits a `bake_targets` output (newline-separated) consumed by the
   interactive-stack job, plus a `phase` output for diagnostics.
3. **`lint`** — runs `hadolint` recursively. Two rules globally ignored
   via [`.hadolint.yaml`](../.hadolint.yaml): `DL3008` (apt version
   pinning — we selectively unpin ABI-stable binaries) and `DL3013`
   (pip version pinning — we use `uv`/`pixi` for Python package
   management).
4. **`python`** (matrix 3.10–3.14) — builds each Python image with
   `docker/build-push-action@v6`. Runs only if `python=true`. On PRs,
   `push` is set to `false` and the registry login is skipped.
5. **`interactive-stack`** — runs only if `bake_targets` is non-empty.
   Before invoking bake, a "Derive CARTA tag" step greps
   `dockerfiles/carta/Dockerfile` for `ARG CARTA_VERSION=` and strips
   the `~noble1` PPA-rebuild suffix, exporting the result as
   `CARTA_TAG` (e.g. `5.1.0~noble1 → 5.1.0`). A second "Derive Firefly
   tag" step does the same for `dockerfiles/firefly/Dockerfile`'s
   `ARG FIREFLY_VERSION=` (no suffix to strip; upstream `ipac/firefly`
   tags are clean, e.g. `2025.5`), exporting `FIREFLY_TAG`. The single
   `CARTA_TAG` is applied to **both** `cadc/carta` and
   `cadc/carta-psrecord` (the carta Dockerfile is the single source
   of truth). Then executes `docker buildx bake` with the computed
   target list, `RELEASE_TAG` (monthly, for the Debian stack),
   `CARTA_TAG` (upstream version, shared by both CARTA targets), and
   `FIREFLY_TAG` (upstream `ipac/firefly` version) all in env. On PRs,
   `push` is `false` and the registry login is skipped.
6. **`tag-release`** — runs only on the day-3 scheduled cron, and only
   if `python` and `interactive-stack` didn't fail. Creates and pushes
   a `release/YY.MM` annotated git tag on the current commit. That tag
   is the diff anchor for next month's `detect-changes`. Requires
   `contents: write` permission on the default `GITHUB_TOKEN` (granted
   locally to this job, not at workflow scope). If the tag already
   exists (re-run of an already-tagged release), the job exits cleanly
   without retagging.

The `python` and `interactive-stack` jobs each cache Docker layers
using `type=gha` (GitHub Actions cache) to speed up rebuilds.

### What pushes go where

On a successful non-PR run, the pipeline pushes:

| Job                  | Tags pushed (assuming all targets selected)                      |
|----------------------|------------------------------------------------------------------|
| `python` (matrix)    | `images.canfar.net/cadc/python:{3.10, 3.11, 3.12, 3.13, 3.14}`   |
| `interactive-stack`  | `images.canfar.net/cadc/{terminal, webterm, vscode, marimo}:<YY.MM>`, `images.canfar.net/cadc/{carta, carta-psrecord}:<CARTA_VERSION>`, `images.canfar.net/cadc/firefly:<FIREFLY_VERSION>` |

Python tags are **overwritten in place** each build. Debian interactive-stack
tags (`terminal`, `webterm`, `vscode`, `marimo`) are **per-month**, so e.g.
`cadc/webterm:26.03` remains available after `cadc/webterm:26.04` is pushed.
`cadc/carta` and `cadc/carta-psrecord` tags are **per-upstream-version**
(e.g. `5.1.0`), so a month with no CARTA release doesn't push a new tag;
a month with a CARTA bump pushes a brand-new tag on **both** images and
the previous one stays available. If Renovate opens a PR that only
bumps `psrecord` or `matplotlib` (without a CARTA change), both CARTA
images still rebuild together but the tag stays the same (the new
`cadc/carta-psrecord:5.1.0` is overwritten in place, and
`cadc/carta:5.1.0` is re-pushed with identical content aside from any
apt security patches — acceptable, mirrors the Python-tag-overwrite
policy).

If an image's Dockerfile did not change between two consecutive
release windows, that image is **not republished** for the new month.
Its previous-month tag stays the newest in Harbor until something in
the image (or an upstream it depends on, or `docker-bake.hcl`)
actually changes.

## 5. External services and secrets

The pipeline depends on three external services. None of them are
provisioned or managed from this repo.

### 5.1. CANFAR Harbor registry

- **Endpoint:** `images.canfar.net` (hardcoded in the workflow `env` and
  in `docker-bake.hcl` default).
- **Auth:** Workflow uses `secrets.CANFAR_REGISTRY_USER` and
  `secrets.CANFAR_REGISTRY_PASSWORD` via `docker/login-action@v3`.
- **Pending confirmation (for upstream adopter):**
  - Exact secret names as configured in the destination repo (the
    workflow will silently skip login if the names don't match; the
    subsequent push step will fail with an auth error).
  - That the service account behind those credentials has push rights
    to the `cadc/` project for all eight image names
    (`python`, `terminal`, `webterm`, `vscode`, `marimo`, `carta`,
    `carta-psrecord`, `firefly`). Harbor is per-project + per-repo
    ACL'd; a newly-introduced image name may require the repo to be
    created and permissions widened. `cadc/carta`, `cadc/carta-psrecord`,
    and `cadc/firefly` are all new repositories for this project and
    will almost certainly need to be created explicitly before the
    first push.
  - Credential rotation policy (who rotates, how often, what notifies
    GitHub Actions of the new secret value).

### 5.2. Mend Renovate (GitHub App)

Renovate opens PRs that bump pinned dependency versions. It is a
GitHub App installed per-repository; installing it on `opencadc/canfar-containers`
is a one-time administrative step performed via
`https://github.com/apps/renovate`.

Configuration lives in [`renovate.json`](../renovate.json):

- Extends `config:recommended` (which activates Renovate's built-in
  `dockerfile`, `docker-compose`, `gradle`, and other managers
  automatically).
- Schedules update PRs for days 5–27 UTC (the merge window).
- Defines two custom regex managers:
  1. Extracts `ARG <NAME>_VERSION=…` values in any Dockerfile when
     annotated by a `# renovate: datasource=… depName=… [versioning=…]`
     comment on the line above. This is the workhorse used by every
     image's pinning.
  2. Extracts `def <name> = '<value>'` lines in any `build.gradle`
     when annotated by a `// renovate: datasource=… depName=…` comment
     on the line above. Used today by `cadc-sso/lib/build.gradle` to
     track the Caltech-IPAC/firefly tag whose `firefly.jar` is
     consumed as a compile-time dependency for the SSO plugin.
- Forces `versioning=pep440` for all `pypi` datasource pins and
  `versioning=deb` for all `deb` datasource pins, so PEP-440 / Debian
  semantics apply even though the regex managers default to semver.
- Renovate's built-in `gradle` manager (active via `config:recommended`)
  automatically tracks all Maven-Central dependency declarations in
  `cadc-sso/lib/build.gradle` and `cadc-sso/gradle/libs.versions.toml`
  (log4j-{api,core}, junit-jupiter, mockito, javax.servlet-api,
  javax.websocket-api, commons-math3, guava, palantir-java-format,
  spotless plugin, jacoco) without any per-line annotation needed.

Once installed, Renovate's behavior on this repo is:

- Opens an "Dependency Dashboard" issue (requires Issues enabled on the
  repo; if disabled, the dashboard is silently skipped but update PRs
  still open).
- On the 1st of each month, scans all `ARG *_VERSION` pins plus standard
  `FROM` references in every Dockerfile, queries each configured
  datasource, and opens a PR for any that have newer versions available.

### 5.3. Repology

Renovate's `repology` datasource queries the public Repology API at
`https://repology.org/api/v1/` to resolve the current version of each
Debian package pin. No credentials required; Repology is a free
read-only service.

Quirk that affects this repo: Repology identifies Debian 13 (Trixie) by
the repo key `debian_13`, **not** `debian_trixie`. The `# renovate:`
comments therefore use `depName=debian_13/<pkg>`. Additionally, some
Debian binary packages are not exposed as standalone Repology projects
(they're produced by a differently-named source package). Those cannot
be tracked via the repology datasource and are installed unpinned. See
the "Pinning philosophy" section of the README for the rationale and
the decision procedure.

## 6. Local development

There is no formal dev-setup script. The following commands are
supported by the files in the repo:

### 6.1. Build the interactive stack locally

```bash
docker buildx bake                          # All four interactive targets
docker buildx bake terminal                 # Just terminal
docker buildx bake webterm vscode           # Two specific targets
RELEASE_TAG=26.05 docker buildx bake        # Override the tag (default: "local")
```

No `push` happens unless `--push` is passed or the bake config is
modified. With `RELEASE_TAG` unset, images are built with the tag
suffix `local` (defined as the default value in `docker-bake.hcl`).

### 6.2. Build a Python base image locally

```bash
docker build -t images.canfar.net/cadc/python:3.12 ./dockerfiles/python/3.12
```

The Dockerfile does not take build args, so no extra flags are needed.

### 6.3. Lint

```bash
docker run --rm -i hadolint/hadolint < dockerfiles/terminal/Dockerfile
# or recursively:
docker run --rm -v "$PWD:/src" -w /src hadolint/hadolint \
  sh -c 'find . -name Dockerfile | xargs -n1 hadolint'
```

The repo's `.hadolint.yaml` ignores `DL3008` and `DL3013` globally; no
other overrides are in effect.

### 6.4. Validate the Renovate config without installing the app

```bash
npx --yes --package renovate -- renovate-config-validator renovate.json
```

To see what the custom regex manager actually extracts from a given
Dockerfile (useful when adding new `ARG *_VERSION` pins):

```bash
npx --yes --package renovate -- renovate \
  --platform=local --dry-run=extract 2>&1 | grep -E '"depName"|"currentValue"'
```

This runs Renovate against the current working directory without
touching any remote and without needing the GitHub App installed.

## 7. Adding a new image to the stack

Concrete steps, derived from how the existing images are wired:

1. Create `dockerfiles/<newimage>/Dockerfile`.
2. Decide the base: if it inherits from `terminal`, use
   `FROM ${REGISTRY}/cadc/terminal:${BASE_TAG}` and accept `REGISTRY`
   and `BASE_TAG` as `ARG`s (see `openvscode` and `marimo` for the
   pattern).
3. Add a `target "<newimage>"` block to `docker-bake.hcl`. If it
   inherits from terminal, include the `contexts` substitution block
   used by the other downstream targets.
4. Add `"<newimage>"` to the `group "default"` targets list so a plain
   `docker buildx bake` builds it.
5. In `.github/workflows/image-pipeline.yml`:
   - Add a filter entry under the `detect-changes` job's
     `dorny/paths-filter` configuration.
   - Add the filter output to the `detect-changes` job `outputs`.
   - Update the "Diff against previous release tag" step to compute
     a changed/unchanged boolean for the new image (and respect any
     cascade it introduces).
   - Update the "Resolve dependencies and apply phase gate" step so
     the new image is emitted on the right day of the release window.
     If it belongs to the interactive stack, add it to the
     `interactive` case arm. If it deserves its own release day, add
     a fourth cron to the `schedule:` block and a new phase arm.
   - Update the "Determine bake targets" step to include the new
     target.
6. Confirm the Harbor `cadc/<newimage>` repository exists and the
   service account has push permission (see §5.1).
7. If you added a new release-window day, update
   [`RELEASE-CADENCE.md`](RELEASE-CADENCE.md) so the documented
   calendar matches the crons.

## 8. Known state and orphans

These are observed as of this handoff. They are intentional mentions,
not hidden problems.

- **Two hadolint rules are globally ignored** (`DL3008`, `DL3013`) via
  `.hadolint.yaml`. The rationale is in the config file's comments:
  `DL3008` because some apt packages are deliberately unpinned
  (libatomic1, locales — see the pinning philosophy in the README) and
  pinning others is done via `ARG` which hadolint doesn't always
  recognize; `DL3013` because Python packages are managed with
  `uv`/`pixi`, not raw `pip`.

## 9. Pending confirmation items (for upstream adopter)

These are concrete questions that cannot be answered from the repo
itself. Each will surface as a real failure mode if left unaddressed.

1. **Registry secret names.** The workflow uses
   `secrets.CANFAR_REGISTRY_USER` and `secrets.CANFAR_REGISTRY_PASSWORD`.
   Confirm these exact names are provisioned in the destination repo's
   Actions secrets. If the existing convention uses different names,
   either rename the secrets or change the workflow.
2. **Harbor project layout and robot-account permissions.** Confirm
   the `cadc/` project exists on `images.canfar.net` and that the
    service account behind the secrets has push rights to
    `cadc/{python, terminal, webterm, vscode, marimo, carta, carta-psrecord, firefly}`.
    Any image name that has never been pushed before may require a new
    Harbor repo and/or updated ACL — in particular `cadc/carta`,
    `cadc/carta-psrecord`, and `cadc/firefly` are newly introduced by
    this stack and will likely need the robot account's ACL extended.
3. **Tag format.** The workflow publishes interactive-stack images
   with tag `YY.MM` (e.g. `26.04`). Confirm this matches the
   project's expected tagging scheme. Alternative common choices
   include `vYY.MM`, `YYYY.MM`, or semantic versions.
4. **Python image tagging strategy.** `cadc/python:3.12` is overwritten
   in place each rebuild. If dated tags are also desired (e.g.
   `cadc/python:3.12-26.04`), the `python` job in the workflow needs
   its `tags:` input extended — a two-line change.
5. **Renovate install decision.** Renovate is a GitHub App; installing
   it on `opencadc/canfar-containers` is a separate administrative
   action from merging this code. Without the install, the
   `renovate.json` in the repo is dormant and pins will not be
   updated automatically — the monthly cron will still run, but only
   refreshes unpinned surface area (apt security updates on top of
   the same pinned base).
6. **Auto-merge policy.** Out of scope for this repo but worth
   deciding once Renovate is active: should Renovate be allowed to
   auto-merge low-risk updates (patch + digest), or should every PR
   require human review? This is a Renovate configuration change, not
   a code change. Currently nothing is auto-merged.
7. **Issues-enabled check.** Renovate's Dependency Dashboard requires
   Issues to be enabled on the repo. If disabled, the dashboard is
   silently skipped (update PRs still open, but there's no single
   pane summary).
8. **Tag-push permission.** The `tag-release` job pushes
   `release/YY.MM` tags using the default `GITHUB_TOKEN` with
   `permissions: contents: write` granted at job scope. If the
   destination org restricts `GITHUB_TOKEN` default permissions to
   read-only (Settings → Actions → General → Workflow permissions),
   the job-scoped grant still applies, but any org-level branch/tag
   protection rule that forbids `github-actions[bot]` from pushing
   tags matching `release/*` will fail the job silently — the images
   publish fine on day 3, but next month's diff has no anchor and
   falls back to a full rebuild. Confirm the org policy allows the
   bot to push release tags.
9. **Merge-window enforcement.** The cadence policy in
   [`RELEASE-CADENCE.md`](RELEASE-CADENCE.md) says "do not merge on
   days 1 – 4." This is currently a convention, not enforced by
   branch protection or by the workflow. If stricter enforcement is
   wanted, add a GitHub ruleset on `main` that blocks merges on
   those days of the month.
10. **Firefly Skaha-side deployment manifest.** This repo publishes
    `cadc/firefly:<FIREFLY_VERSION>` to Harbor. The Skaha-side
    Kubernetes resources that actually run the image (Deployment,
    Service, Traefik IngressRoute, Middleware) are **not** shipped
    here and are owned by whoever operates the Skaha cluster. The
    upstream reference at `opencadc/science-containers/.../firefly/manifest.yaml`
    is a working starting point: a singleton Deployment with
    `replicas: 1`, `runAsUser: 91` (Tomcat UID), 4Gi/1CPU request +
    8Gi/2CPU limit, and the env vars `PROPS_sso__framework__adapter=org.opencadc.security.sso.TokenRelay`,
    `CADC_SSO_COOKIE_NAME=CADC_SSO`, `CADC_SSO_COOKIE_DOMAIN=.canfar.net`,
    `CADC_ALLOWED_DOMAIN=.canfar.net`, `baseURL=/session/notebook/firefly/`,
    plus a `PROPS_FIREFLY_OPTIONS` JSON blob with TAP service
    pre-configuration. The deployment image reference will need to be
    pointed at `images.canfar.net/cadc/firefly:<tag>` (the upstream
    reference points at `images.canfar.net/skaha/firefly:dev`).

---

Last updated alongside the handoff PR introducing this file. When the
pipeline, image stack, or external-service assumptions change, update
this file in the same PR as the code change.
