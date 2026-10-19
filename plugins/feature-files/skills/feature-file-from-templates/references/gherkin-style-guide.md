# Gherkin Style Guide: Playwright-BDD

Applies to `.feature` files compiled by
[playwright-bdd](https://github.com/vitalets/playwright-bdd) into native
Playwright specs. Further reading on the standards behind each rule is linked
inline; start with [BDD 101](https://automationpanda.com/bdd/) and the
[Gherkin reference](https://cucumber.io/docs/gherkin/reference/) if you're new
to this.

The examples below use a generic "draft article" domain; substitute the
entities of the repo you're working in.

---

## 1. Isolation, not sequence

Unlike legacy Cucumber/Selenium runners, `playwright-bdd` shards scenarios
across parallel, asynchronous workers — there is no shared browser session to
lean on. Every scenario must set up its own state and stand on its own.

- **Don't** rely on data created by a previous scenario still existing.
- **Do** create the data you need inside the scenario's own `Given`, via the
  repo's API/seeding helpers or fixtures rather than the UI.

---

## 2. Declarative over imperative

Capture _what_ the system does, not _how_ the UI is driven. Push clicks,
field-filling and URL navigation down into step definitions/fixtures. See
[Cucumber's guidance on BDD](https://cucumber.io/docs/bdd/) for the underlying
rationale.

### ❌ BAD — imperative, brittle

```gherkin
Scenario: Publishing an article
  Given I navigate to "/drafts/new"
  And I fill in "title" with "Weekend Reading"
  And I click "Save and continue"
  ...
  When I click "Publish"
  Then I should see "published"
```

_Why it fails:_ every copy tweak to a button label or URL breaks this file,
even though "a draft can be published" hasn't changed.

### ✅ GOOD — declarative, fixture-driven

```gherkin
Scenario: Publishing an article that is ready
  Given a draft article with all required fields
  When the editor publishes it
  Then the article's status becomes published
```

The fixture behind `Given` seeds the draft through an API helper, bypassing
the UI entirely.

---

## 3. One scenario, one behaviour

The [Cardinal Rule of BDD](https://automationpanda.com/bdd/): _one scenario,
one behaviour_. No "super-scenarios" stacking multiple `When`/`Then` pairs.

- Keep scenarios to **3–5 steps**; treat 8 as a hard ceiling.
- **Given** = past state, **When** = the action, **Then** = the assertion.

### ❌ BAD — multi-behaviour monolith

```gherkin
Scenario: Editing article settings
  Given a draft with default settings
  When the editor sets the contact email
  Then the contact email is saved
  When the editor sets the series tag
  Then the series tag is saved
```

### ✅ GOOD — singular focus

```gherkin
Scenario: Contact email is saved after a reload
  Given a draft with default settings
  When the editor sets the contact email and reloads the page
  Then the saved contact email is shown
```

Narrow scenarios like this catch field-specific bugs (e.g. a value that only
fails to persist on reload); a monolith re-asserting several fields at once
tends to miss them.

---

## 4. Background must be universal

Because scenarios run out of order across workers, nothing may depend on data
another scenario created.

- `Background` steps must apply to **every** scenario in the file — drop it
  rather than force a fit.

### ❌ BAD — leaking state

```gherkin
Feature: Article drafts

Scenario: Create a draft
  When the editor creates an article "Weekend Reading"
  Then it appears in the drafts list

Scenario: Publish the draft
  When the editor publishes "Weekend Reading"
  Then its status becomes published
```

This only passes when scenarios run serially in file order (e.g. `workers: 1`);
it fails the moment they run out of order or on different workers.

### ✅ GOOD — atomic via fixtures

```gherkin
Feature: Article drafts

Background:
  Given an existing draft article

Scenario: Publish a ready draft
  When the editor publishes it
  Then the article's status becomes published
```

`Background` steps run before **every** scenario in the file, so this one
creates a fresh, isolated draft for each scenario (see rule 1) rather than
depending on state left behind by another scenario or worker.

---

## 5. Grouping by login permission type

Whether to split scenarios by login permission type is decided case by case:
ask the user before writing, and ask what file names they want.

When splitting, the login (and its permissions) belongs in the feature's
`Background`, not in a `Given` at the start of each scenario, with one feature
file per permission type so each file's `Background` stays universal (rule 4).
When keeping a single file, put the permission sign-in as the first `Given` of
each scenario that needs it, and keep it out of `Background`.

### Single file — permissions per scenario

```gherkin
Feature: Article publishing

Scenario: Editor publishes a ready draft
  Given I am signed in with publish permission
  And a draft article with all required fields
  When the editor publishes it
  Then the article's status becomes published

Scenario: Contributor cannot publish
  Given I am signed in without publish permission
  And a draft article with all required fields
  Then the publish action is not available
```

### Split — one file per permission type, login in `Background`

```gherkin
# article-publishing-with-publish-permission.feature
Feature: Article publishing with publish permission

Background:
  Given I am signed in with publish permission

Scenario: Publishing a ready draft
  Given a draft article with all required fields
  When the editor publishes it
  Then the article's status becomes published
```

```gherkin
# article-publishing-without-publish-permission.feature
Feature: Article publishing without publish permission

Background:
  Given I am signed in without publish permission

Scenario: The publish action is hidden
  Given a draft article with all required fields
  Then the publish action is not available
```

When splitting, name each file (and its `Feature:` title) as the user chose,
defaulting to the permission type it covers.

---

## 6. Playwright-BDD specifics

### Scenario Outline titles

Row-index titles (`Example #1`) break test-history tracking when rows are
reordered. Always pin titles with
[`# title-format:`](https://vitalets.github.io/playwright-bdd/#/writing-features/customize-examples-title):

```gherkin
Scenario Outline: Publish readiness depends on article type
  Given a draft article of type "<type>"
  When the editor checks publish readiness
  Then a main image is "<required>"

  # title-format: <type> articles require a main image: <required>
  Examples:
    | type     | required |
    | feature  | yes      |
    | liveblog | no       |
```

### Native tags

Use playwright-bdd's built-in
[special tags](https://vitalets.github.io/playwright-bdd/#/writing-features/special-tags)
instead of custom skip/config step logic: `@skip`/`@fixme`, `@only`, `@slow`,
`@retries:N`.

```gherkin
@slow @retries:3
Scenario: Completing the full creation wizard
  Given the editor starts a new article in the wizard
  When the editor completes every step through to review
  Then the draft is saved with all submitted data
```

---

## Further reading

- [Cucumber: What is BDD?](https://cucumber.io/docs/bdd/)
- [Gherkin reference](https://cucumber.io/docs/gherkin/reference/)
- [Automation Panda: BDD 101](https://automationpanda.com/bdd/)
- [playwright-bdd documentation](https://vitalets.github.io/playwright-bdd/)
