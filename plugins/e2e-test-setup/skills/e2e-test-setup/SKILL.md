---
name: e2e-test-setup
description: 'Set up an end-to-end (e2e) test suite following proven patterns: a self-contained Testcontainers stack driving Playwright/Cucumber-BDD tests, plus CI. Work phase by phase, running each phase''s decided validation and raising a separate, optionally stacked pull request after every phase. Use when asked to set up e2e tests, add Playwright + Testcontainers, stand up a local stack with mocked services, or apply these e2e patterns to a project. Delegates to the e2e-stack-setup, e2e-fixtures-and-mocks and e2e-ci-workflow skills.'
argument-hint: '<target project and its runtime dependencies, if known>'
---

# E2E test setup (umbrella)

Set up an e2e test suite by following the same patterns used to build the
reference e2e setup: Playwright + `playwright-bdd` running against a
self-contained Testcontainers stack (the app under test plus its dependencies,
each mocked or run for real), plus a GitHub Actions workflow to run it in CI. The
goal is to apply the *approach*, adapted to the project at hand — not to copy the
reference stack.

**Read [reference/e2e-playbook.md](reference/e2e-playbook.md) first.** It is the
source of truth for the patterns, decisions, ports and gotchas, and links to the
captured reference docs under `reference/` as worked examples. This skill only
orchestrates; the detail lives in the playbook and the phase skills.

## When to use
- "Set up end-to-end tests / Playwright + Testcontainers for this project."
- "Stand up a local stack with mocked upstream services for testing."
- "Use the same e2e patterns/approach as the reference setup here."

## Procedure

Work through the phases in order. Do not skip discovery — the stack shape is
driven entirely by the app's real dependencies.

Every numbered phase is a separate delivery boundary and must end in a pull
request. This includes separate PRs for Phase 1 scaffold and Phase 2 stack, even
though `e2e-stack-setup` owns both, and one PR per Phase 7 coverage increment.
The validation for each phase is **already decided** — follow the playbook's
**Phase pull requests and validation** table; do not offer options or ask the
user to choose. Run that phase's fixed check, then open the PR.

1. **Phase 0 — Discover** (do this before writing anything):
   - Identify the app's runtime: framework, language, how it's built/run in dev.
   - Identify the app's **JavaScript package manager** (npm, yarn or pnpm — check
     the lockfile / `packageManager` field). Use that same manager for the
     `e2e-tests/` workspace; if the app uses none of those, default to **npm**
     (playbook guiding principle 5).
   - Enumerate every dependency the app talks to: other services, databases
     (SQL / DynamoDB / etc.), object storage (S3), and each upstream HTTP API.
   - Identify the auth model (how a request is authenticated).
   - For each dependency version-controlled in a Guardian repository (private or
     public), **confirm with the user** whether to run the real service (checked
     out and built from source) or mock it with WireMock. Default to mocking
     unless real behaviour is needed.
   - **Check the recommended minimum versions** (playbook "Phase 0 prerequisites
     and recommended minimum versions"): AWS SDK **v2**, webpack **v5**, Node.js
     **v24**. If any is below its minimum, **strongly advise the user to upgrade
     before setting up e2e tests**.
   - **Advise the environment prerequisites:** the suite must run in a
     **devcontainer** with the **developer policy for AWS**, and the project must
     have a **`.tool-versions`** file managing the build tools.
   - Confirm Docker is available in the dev/CI environment.

2. **Phase 1–2 — Scaffold + stack** → use the **`e2e-stack-setup`** skill. Bake
   the build-speed optimisations (playbook §6) in here rather than as a separate
   pass.
3. **Phase 3 — Fixtures + mocks** → use the **`e2e-fixtures-and-mocks`** skill.
4. **Phase 4 — Tests** → use the **`feature-file-from-templates`** and
   **`feature-file-step-definitions`** skills. The goal here is only to **validate
   the setup**, not to cover the whole app. Cover two things: the app's **landing
   page** — **confirm with the user which page is the landing page** — so the
   stack is exercised end-to-end from the entry point, plus a small feature slice
   — **ask the user which part of the UI** to extract it for — and author just
   those.
5. **Phase 5 — Document** → write `e2e-tests/README.md` following
  [reference/docs.md](reference/docs.md). Put
  `<!-- guardian-agent-skill: e2e-test-setup/v1 -->` on its first line as a
  non-identifying adoption marker. Do this before CI, once the stack, fixtures
  and tests exist, so it describes what was actually built.
6. **Phase 6 — CI** → use the **`e2e-ci-workflow`** skill.

## Phase delivery gate

At the end of each phase:

1. Run the phase's **decided** validation from the playbook's "Phase pull requests
   and validation" table (adapt only the package manager). Do not offer choices.
   Record the result. For a GitHub-only check (Phase 6), provide the exact steps
   and mark the result pending rather than claiming it passed locally.
2. Keep the diff and commit limited to the current phase. Check in the phase's
   validation script where one is defined (`validate:stack`, `validate:fixtures`,
   the Phase 1 structural validator).
3. Push the phase branch and raise a PR. If its predecessor is unmerged, create a
   stacked PR based on the predecessor branch; identify the base, dependency and
   merge order clearly. Otherwise target the default branch.
4. Include `How to validate` and `Validation result` sections in the PR body,
   give the user the PR link, and stop. Begin the next phase only when asked.

The decided validation for the agent-led phases:

- **Phase 0:** create `plans/e2e-test-setup.md`, run `git diff --check`, and
  present its source-linked dependency/auth inventory and real-vs-mocked
  decisions for manual review.
- **Phase 5:** `git diff --check` plus a manual source/link verification of the
  README against the implemented stack, fixtures, commands, ports and CI design.
  No stack or tests.
- **Phase 7:** `cd e2e-tests && yarn test:ci` for the increment, with runtime-log
  inspection and any newly required fixture/mock probe.
- Never commit real secrets or personal data into fixtures.
- Preserve the key decisions in playbook §4 unless the target genuinely differs;
  when it does, follow playbook §8 (adapting to a different stack).
- Keep `e2e-tests/README.md` in sync: whenever a change alters the stack,
  fixtures/mocks, commands, folder layout or CI, update the matching README
  section in the same change (see [reference/docs.md](reference/docs.md)).

## Guardian-specific detail
Each phase skill ends with a **Guardian specifics** section covering pan-domain
auth, dev-nginx, the private `guardian/workflow` datastore and the GitHub App
token. Read it as part of that phase.
