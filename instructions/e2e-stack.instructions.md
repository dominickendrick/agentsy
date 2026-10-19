---
applyTo: "e2e-tests/setup/**,e2e-tests/images/**,e2e-tests/scripts/**"
description: "Conventions for the e2e Testcontainers stack code, Dockerfiles and validation scripts."
---

# E2E stack conventions

Rules for the local-stack setup code under `e2e-tests/setup/` and the Dockerfiles
under `e2e-tests/images/`. Background and rationale live in the
`e2e-test-setup` skill's [reference playbook](../plugins/e2e-test-setup/skills/e2e-test-setup/reference/e2e-playbook.md).

## Dockerfiles
- Base app/backend images on `debian:bookworm-slim` (glibc). Do **not** use
  Alpine for images that run a JDK or use `apt-get`.
- Bake **only the toolchain** (via `mise` from a copied `.tool-versions`); never
  `COPY` application/backend source into the image — it is bind-mounted at
  runtime.
- Keep the build context tiny: build from a temp dir holding just
  `.tool-versions` + the Dockerfile.
- Start every Dockerfile with the `# syntax=docker/dockerfile:1` directive.
- Wrap `mise install` in a BuildKit cache mount
  (`--mount=type=cache,target=/mise/cache,sharing=locked`) so the toolchain is
  cached across image rebuilds.

## Container start code
- Create exactly one `Network` per stack run; stop it and every started
  container in the failure path and in `stopLocalStack`.
- Prefer stock images with bind-mounted fixtures/config over bespoke images
  (WireMock, LocalStack, Postgres, nginx).
- Run all mocks from the single shared WireMock image via `MOCK_WIREMOCK_CONFIGS`
  + `startMockWiremock`; add a mock by adding a fixture folder and a table entry,
  not a Dockerfile.
- Give each service a network alias matching the real upstream hostname so the
  app resolves it inside the Docker network without config overrides.
- Every container must have an explicit `Wait` strategy (log message or HTTP
  healthcheck) and a sensible `withStartupTimeout`.
- Bind-mount source read-write only where the toolchain writes (`target/`,
  `public/build`); mount fixtures read-only.
- Bind-mount the host's persistent coursier/ivy caches into every sbt container
  (`/root/.cache/coursier`, `/root/.ivy2`, read-write) via an env-gated helper
  (`DEVENV_COURSIER_CACHE_MOUNT_DIR` / `DEVENV_IVY_CACHE_MOUNT_DIR`) that adds no
  mounts when the vars are unset, so the stack still runs outside the
  devcontainer.
- Seed datastores from the host after the container is ready; seed the SQL DB
  only after the owning service's migrations have created the schema, parents
  before FK children.

## Safety
- Never commit real secrets, tokens or personal data into `e2e-tests/fixtures/`
  — use synthetic values.
- Keep the production app change footprint minimal (env-gated switches only).

## Validation scripts
- Make scripts non-interactive and return non-zero when any assertion fails.
- Clean up owned processes, containers and networks in a trap/finally block,
  including when startup or validation fails. Detect leaks by labels or recorded
  resource IDs; never remove unrelated Docker resources.
- Print the exact check being performed and a concise pass/fail summary so the
  same script is useful locally and in a PR's **How to validate** section.
- Keep validation on local/Testcontainers infrastructure. Use dummy credentials,
  reject real AWS endpoints, and never require production secrets.
- Document prerequisites and expose the script through the e2e workspace's
  package-manager scripts when it is intended for repeated use.

## Guiding principles
- The code lives at the dev-container root; when a Docker image runs the app
  (CI / `test:ci`), it **bind-mounts** the code, never copies it in.
- Run the app **natively** in dev; containerise only for CI / `test:ci`.
- Provide anything a browser needs (cookies, routing) **server-side** so `dev` /
  `dev:local` need no forced cookies or browser mocks.
