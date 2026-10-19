---
name: setup-e2e-tests
description: 'Set up an e2e test suite (Testcontainers stack + Playwright/BDD + CI) with a decided validation per phase and a separate, optionally stacked pull request after every phase.'
disable-model-invocation: true
---

# Set up e2e tests

Set up a self-contained end-to-end test suite on this project by following the
same patterns used to build a reference e2e setup, per the
**`e2e-test-setup` skill** and its
[reference playbook](../e2e-test-setup/reference/e2e-playbook.md). Use the
`e2e-test-setup` agent's phased approach, adapting each pattern to this project's
stack rather than copying the reference stack.

Before scaffolding anything, run **Phase 0 discovery** and confirm findings with
me. Establish:

1. **App runtime** — framework/language and how the app is built and run in dev.
2. **Dependencies** — every service and store the app talks to:
   - other services, and whether each is version-controlled in a Guardian
     repository (private or public);
   - databases (SQL, DynamoDB, …);
   - object storage (S3);
   - each upstream HTTP API.
   For each Guardian-repo dependency, I'll confirm with you whether to run the
   real service (checked out and built from source) or mock it with WireMock.
3. **Auth model** — how a request is authenticated (cookie/JWT/OIDC/pan-domain).
4. **Environment** — is Docker available in the dev container and in CI? Confirm
   the suite will run in a **devcontainer** with the **developer policy for AWS**,
   and that the project has a **`.tool-versions`** file managing the build tools.
5. **Recommended minimum versions** — check AWS SDK **v2**, webpack **v5** and
   Node.js **v24**. If any is below its minimum, I'll **strongly advise you to
   upgrade before setting up e2e tests**.
6. **Scope** — which of these phases to do now: scaffold, stack, fixtures+mocks,
   feature tests, docs, CI workflow. (Scaffold and stack use the same skill but
   remain separate PR phases; build-speed optimisations are baked into the stack
   build, not a separate phase.) The feature-tests phase only **validates
   the setup** — tell me which part of the UI to extract a small set of features
   for, rather than covering the whole app.

Infer as much as possible from the codebase first, then ask me only what's left.
Once I confirm the discovery summary, proceed phase by phase, delegating to the
`e2e-stack-setup`, `e2e-fixtures-and-mocks` and `e2e-ci-workflow` skills, and
using separate delivery boundaries for scaffold (Phase 1) and stack (Phase 2).
The validation for each phase is **already decided** — don't ask me to choose.
Run that phase's fixed check from the playbook's "Phase pull requests and
validation" table (adapting only the package manager):

- Phase 0: create `plans/e2e-test-setup.md`, run `git diff --check`, present the
  source-linked inventory for manual review.
- Phase 1: `yarn install` succeeds and `yarn test` exits with a clean "no tests"
  message while no feature files exist; add a checked-in structural validator.
- Phase 2: `cd e2e-tests && yarn validate:stack`.
- Phase 3: `cd e2e-tests && yarn validate:fixtures`.
- Phase 4 / Phase 7: `cd e2e-tests && yarn test:ci`.
- Phase 5: `git diff --check` plus manual source/link verification.
- Phase 6: open the stacked PR, then watch `e2e-tests.yml` on `ubuntu-22.04`.

After running the decided validation, commit only that phase's changes, push the
phase branch and open a pull request whose body states the decided how-to-validate
commands and what was actually run. Create a stacked PR based on the preceding
unmerged phase branch when there is a dependency; identify that dependency and
merge order clearly. Give me the PR link and stop for review before starting the
next phase. Phase 0 and every Phase 7 coverage increment also require their own PR.

Follow the standard command set and guiding principles in the playbook (§9–§11):
the app runs natively in dev and is containerised only in CI; provide anything
the browser needs server-side (no forced cookies or browser mocks for dev).

Each phase skill ends with a **Guardian specifics** section (pan-domain auth, the
private `guardian/workflow` datastore, the GitHub App token) — read it as part of
that phase.
