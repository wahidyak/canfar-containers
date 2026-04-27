# syntax=docker/dockerfile:1
#
# CANFAR Firefly Image
#
# IPAC Firefly (https://github.com/Caltech-IPAC/firefly), launched by Skaha
# as a first-class "firefly" session type. Unlike the per-user CARTA / VS Code
# / marimo images, Firefly runs as a long-lived multi-user Tomcat service
# inside the cluster (one pod, Skaha proxies users to it). The image itself
# is the same shape as upstream `ipac/firefly` -- it listens on :8080 and
# starts Tomcat -- but ships an additional `cadc-sso-lib-*.jar` plugin
# inside Firefly's `WEB-INF/lib/` that implements the
# `org.opencadc.security.sso.TokenRelay` `sso.framework.adapter` extension.
# The plugin reads the `CADC_SSO` cookie on inbound requests and converts
# it into a `Bearer <token>` header for Firefly's outbound calls to CADC
# data services (YouCAT / VOSpace / etc.) so users see authenticated data.
#
# Vendored from opencadc/science-containers (upstream maintainer of the
# Java SSO plugin). The `cadc-sso/` directory is a self-contained Gradle
# multi-project build (Java 21, JUnit + Mockito + Spotless). Its
# `lib/build.gradle` clones Caltech-IPAC/firefly at a pinned tag during
# the build to obtain `firefly.jar` as a compile-time dependency for the
# SSO plugin -- the cloned tag is tracked separately by Renovate via a
# `# renovate:` annotation inside that build.gradle so a Caltech-IPAC
# release bumps the cadc-sso compile against the matching Firefly API.
#
# Trust model: TLS to Docker Hub for the two FROM bases (digest-pinned),
# TLS to GitHub for the in-build Caltech-IPAC/firefly clone, TLS to Maven
# Central for the Java dependency tree. Same posture as every other image
# in this repo -- no key fingerprint pinning, just transport-layer trust.

# Global ARGs declared before any FROM so they are visible to every stage's
# FROM instruction. Both pins are tracked by Renovate's `docker` datasource
# via the `# renovate:` annotations directly above each ARG.
#
# Builder pin is `8-jdk21-alpine`, NOT the floating `jdk21-alpine` (which
# tracks the latest gradle major). Gradle 9.x removed the
# `exec { ... }` API used inside the upstream `cadc-sso/lib/build.gradle`
# `doLast` blocks (they would need to migrate to `providers.exec` or the
# new `ExecOperations` service); pinning to gradle 8.x keeps the upstream
# build script working unmodified, which is the design goal -- the
# `cadc-sso/` directory is vendored from opencadc/science-containers with
# only minimal local edits: (1) `lib/build.gradle` lifts the Caltech-IPAC
# tag and the servlet-API dep into Renovate-tracked / jakarta-namespaced
# values; (2) `lib/src/{main,test}/.../TokenRelay*.java` imports
# `jakarta.servlet.http.Cookie` instead of `javax...`. Both edits track
# the Tomcat 9 -> Tomcat 11 migration upstream Firefly made in the
# 2025.x line; without them, the SSO plugin throws NoSuchMethodError at
# runtime when called from `ipac/firefly:2025.5`.

# renovate: datasource=docker depName=gradle
ARG GRADLE_VERSION=8-jdk21-alpine
# renovate: datasource=docker depName=ipac/firefly
ARG FIREFLY_VERSION=2025.5

# Stage 1: builder. Compiles cadc-sso-lib-*.jar from the vendored Gradle
# project. The build script clones Caltech-IPAC/firefly at the tag pinned
# inside lib/build.gradle (Renovate-tracked) so firefly.jar is available
# as a `fileTree`-resolved compile dependency.
FROM gradle:${GRADLE_VERSION}@sha256:916096451b720586f07b4754e153d5211656a34a7b08d41bd51cd2773b804531 AS builder

SHELL ["/bin/sh", "-eo", "pipefail", "-c"]

COPY cadc-sso /firefly/cadc-sso
WORKDIR /firefly/cadc-sso

# `gradle build` runs the cloneFirefly + buildFireflyJar + linkFireflyJar
# task chain (defined in lib/build.gradle) before compiling cadc-sso-lib.
# The final `ls` is a build-time assertion that the jar landed where the
# next stage's COPY expects it.
RUN gradle build --info && \
    ls -l lib/build/libs/cadc-sso-*.jar

# Stage 2: runtime. The upstream IPAC Firefly image (Tomcat + Firefly webapp
# pre-installed under /usr/local/tomcat/webapps-ref/firefly/). We add the
# CADC SSO plugin jar into that webapp's WEB-INF/lib/ so Tomcat picks it up
# at startup when the operator sets PROPS_sso__framework__adapter to
# `org.opencadc.security.sso.TokenRelay` (configured by Skaha at deploy
# time, not baked here -- see the Skaha operator's manifest).
FROM ipac/firefly:${FIREFLY_VERSION}@sha256:83425fdb6d36f05cf3e86bb42ea8017864ed881ccdf2df8aa92363201ed94c94

COPY --from=builder /firefly/cadc-sso/lib/build/libs/cadc-sso-*.jar /usr/local/tomcat/webapps-ref/firefly/WEB-INF/lib/

# Port 8080 is Firefly's upstream Tomcat default. Skaha's "firefly" session
# launcher proxies user traffic to this port; the upstream readiness /
# liveness probes (curl HEAD on /session/notebook/firefly/firefly/) also
# target 8080. Declarative only -- the upstream ipac/firefly image already
# EXPOSEs this; we re-state it to make the contract explicit at our layer.
EXPOSE 8080

LABEL org.opencontainers.image.title="cadc/firefly"
LABEL org.opencontainers.image.description="IPAC Firefly with CADC SSO TokenRelay adapter for CANFAR"
LABEL org.opencontainers.image.source="https://github.com/opencadc/canfar-containers"
LABEL org.opencontainers.image.licenses="GPL-3.0-or-later"

# CMD / ENTRYPOINT inherited from ipac/firefly. Skaha's "firefly" session
# launcher does not override CMD (Firefly is a shared Tomcat service, not
# a per-user session like CARTA), so the upstream Tomcat startup runs
# unchanged. Environment-driven configuration (PROPS_sso__framework__adapter,
# CADC_SSO_COOKIE_NAME, CADC_SSO_COOKIE_DOMAIN, CADC_ALLOWED_DOMAIN,
# baseURL, PROPS_FIREFLY_OPTIONS) is supplied by the Skaha-side Deployment
# manifest, not baked into the image.
