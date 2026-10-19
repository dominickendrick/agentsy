---
name: feature-file-from-templates
description: "Generate a Cucumber/Gherkin .feature file that captures all behavioural scenarios of HTML templates and their related JavaScript/TypeScript, using the workflow-frontend evidence-annotated format. Use when asked to write a feature file, BDD scenarios, or Gherkin from a template/component; to capture UI behaviour as scenarios; or to verify that a feature file covers everything a template and its scripts do."
argument-hint: "<path to the HTML template (and optionally the related JS/TS)>"
---

# Feature File From Templates

Produce a `.feature` file (Cucumber/Gherkin) that captures every observable behaviour of one or more HTML templates and the JavaScript/TypeScript that drives them, in the repo's evidence-annotated format.

## When to Use

- "Write a feature file / BDD scenarios / Gherkin for this template/component."
- "Capture all the scenarios of this HTML file, including the related JS."
- "Check that this feature file covers everything the template and scripts do."

## Inputs

- One or more HTML template files (the primary source of UI behaviour).
- The related JS/TS: controllers, directives, services, models, event handlers, and any Scala/API endpoints the frontend calls.

## Procedure

1. **Read the template(s) fully.** Note every interactive element and binding:
   - Controllers/directives (`ng-controller`, custom directives), event bindings (`ng-click`, `ng-mousedown`, `ng-keydown`, etc.).
   - Conditional rendering / state classes (`ng-if`, `ng-show`, `ng-class`, `*--hidden` toggles).
   - Repeated content (`ng-repeat`) and what each row renders (icons, labels, ids).
   - Static labels and headings users can see.

2. **Trace the related JS/TS.** For each binding found in the template, follow it into code:
   - What each handler does (emitted events, service calls, state changes).
   - What data populates the view (service methods, models, feature switches).
   - Where emitted events are handled (e.g. modal openers) and what mode/result they produce.
   - Any permission checks or backend endpoints involved.
   - Use `grep_search` for event names and function names to find both emitters and listeners.

3. **Derive scenarios.** Create one scenario per distinct, observable behaviour or branch:
   - Default/initial state, opening/closing, toggling.
   - Each user action and its outcome.
   - Data-driven variations (e.g. feature switch on vs off, permission present vs absent).
   - Rendering details worth asserting (icon + label present, disabled states).
   - Keep steps behaviour-focused (what the user sees/does), not implementation-focused.
   - Note which login permission type each scenario needs.

4. **Ask how to group by login permission.** If the scenarios need more than one login permission type, stop and ask the user before writing anything:
   - Present the permission types found and which scenarios need each.
   - Ask whether to **split into one feature file per permission type** (sign-in with that permission in each file's `Background`) or **keep a single file** (sign-in with the permission as the first `Given` of each scenario that needs it).
   - Ask what file name(s) they want, suggesting defaults such as `<name>-with-<permission>.feature`.
   - Skip this step if every scenario needs the same permission type.

5. **Write the feature file(s)** following the [format](#format) below and the user's choice from step 4. After every scenario, add `# Evidence:` comment lines listing the workspace-relative paths of the files that justify that scenario. Give line number ranges for each comment line prefaced by `lines` - we support single lines and line ranges, e.g. `# Evidence: public/path/to/template.html lines 14, 101-120`

6. **Verify coverage.** Cross-check the finished file against the template and evidence files. Build a mental table of each template element/behaviour → scenario. Report any element not represented (call out purely decorative gaps explicitly rather than inventing trivial scenarios).

When this skill is used for Phase 4 or a Phase 7 coverage increment, do not open
a PR for the `.feature` file alone. Complete its step definitions, run the decided
validation in the `feature-file-step-definitions` skill (`yarn test:ci`), and
include the feature and runnable steps in the same phase/increment PR.

## Format

- Save as `e2e-tests/features/<name>.feature`, using the file name(s) the user chose in step 4.
- `Feature:` title on the first line, followed by 1–3 indented plain-English lines describing intent.
- Always use these standard `Background:` steps; the "opened" line names the relevant page, and when scenarios need specific permissions the sign-in line names them (e.g. `with publish permission`):
  ```
  Background:
    Given the application stack is running
    And I am signed in through pan-domain auth
    And I have opened <the relevant page>
  ```
- How scenarios needing different login permissions are grouped is the user's choice (step 4): either one feature file per permission type with sign-in in the `Background`, or a single file with the permission sign-in as each affected scenario's first `Given`.
- One `Scenario:` per behaviour, using `Given` / `When` / `Then` / `And` steps.
- Immediately after each scenario, list the sources as comments:
  ```
  # Evidence: public/path/to/template.html lines 14, 44, 71, 101, 124, 152, 173-174
  # Evidence: public/path/to/controller.js lines 52, 74-6
  ```
- Only cite files you actually inspected; use real workspace-relative paths.

- Follow the [Gherkin style guide](./references/gherkin-style-guide.md) (isolation, declarative steps, one behaviour per scenario, universal `Background`, grouping by login permission type, playwright-bdd specifics).

## Example (excerpt)

```gherkin
Feature: Create new content from the dashboard "Create new" dropdown
  This lets an editor start a new piece of content, or import existing content,
  by choosing a content type from the dashboard toolbar

  Background:
    Given the application stack is running
    And I am signed in through pan-domain auth
    And I have opened the workflow dashboard

  Scenario: Choosing a content type opens the stub modal in create mode
    Given the "Create new" dropdown is open
    When I choose a content type from the list
    Then a stub creation should be requested for that content type
    And the stub modal should open in create mode
  # Evidence: public/layouts/dashboard/dashboard-create.js lines 14, 44
  # Evidence: public/components/stub-modal/stub-modal.js lines 71-73
```

## Quality Checklist

- Every interactive element and state branch in the template maps to at least one scenario.
- Data-driven branches (feature switches, permissions) each have on/off scenarios.
- Steps read as user behaviour, not code.
- Each scenario carries accurate `# Evidence:` paths for every file relied upon.
- Uncovered template elements are reported; decorative-only gaps are noted, not padded with filler scenarios.
