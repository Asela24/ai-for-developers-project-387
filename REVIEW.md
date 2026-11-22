# REVIEW.md

Criteria for reviewing a pull request in this repository. The automatic reviewer (`.github/workflows/claude-review.yml`) applies them to every PR; human reviewers use the same list.

The reviewer is independent of the PR author, human or agent. It judges the diff and the code it touches, not the PR description: a claim such as "tests pass" or "no behaviour change" counts only when the diff shows it.

## Severity

| Level         | Meaning                                                      | Merge                   |
| ------------- | ------------------------------------------------------------ | ----------------------- |
| 🔴 Blocker    | Wrong behaviour, broken rule below, security hole, data loss | Not until fixed         |
| 🟡 Should fix | Missing test, unclear code, drift from domain language       | Fix or explain in reply |
| 🟢 Nit        | Style or naming the tools don't enforce; optional            | Author's call           |

Report each finding once, on the line it is about, with its level and a concrete fix. Do not report what `mise run check` already enforces (formatting, lint, types, knip, syncpack): CI catches it.

## 1. Correctness

- The change does what its ticket (`Refs #N`) and the agreed spec ask, and nothing they didn't ask for (section 7).
- Booking rules hold: Bookings for one Event type don't overlap (intervals are half-open, `start < end`), a Booking starts on an offered Slot inside the booking window, and only Upcoming Bookings are listed.
- Edge cases: empty input, boundaries (exactly at window start/end, back-to-back Bookings), time zones (everything is UTC on the wire), concurrent requests.
- Errors return the status and body the contract declares, not a bare 500.

## 2. Contract and generated files

- API changes start in `specs/*.tsp`; `openapi/openapi.yaml`, `apps/web/src/client/` and `apps/server/src/openapi.gen.ts` change only through `pnpm contract`, in the same PR.
- `apps/web/src/routeTree.gen.ts` is never edited by hand.
- The web app calls the API only through the generated SDK in `apps/web/src/client`, never with raw `fetch`.
- A breaking contract change (removed field, new required field, changed status code) is called out in the PR's risk section.

## 3. Tests

- New behaviour has a test that fails without the change. Server tests use `buildApp().inject(...)`; user-visible flows have a Playwright e2e test.
- A bug fix comes with a test that reproduces the bug.
- Tests are not weakened, skipped or deleted to make the change pass.

## 4. Domain language

- Code, UI text, tests and docs use the terms from `GLOSSARY.md` (Owner, Guest, Event type, Booking, Upcoming Booking, Slot) and avoid the words it lists under _Avoid_.
- A new domain term is added to `GLOSSARY.md` in the same PR; a significant design decision gets an ADR in `docs/adr/`.

## 5. Security

- No secrets, tokens or personal data in code, logs, fixtures or commits.
- Input from the Guest is validated at the API boundary (contract constraints) and escaped on output.
- Workflows: actions pinned to a full commit SHA, `permissions: {}` at the top and the minimum per job, no untrusted input (`github.event.*.title`, `body`, branch names) interpolated into `run:` scripts, no secrets in jobs that run fork code.

## 6. Repository rules (`AGENTS.md`)

- `.github/workflows/hexlet-check.yml` is untouched.
- No lint rule disabled or check weakened; any exception is narrow and commented.
- Commits follow Conventional Commits and implementation commits carry a `Refs #N` footer.
- The PR description fills in [`.github/pull_request_template.md`](.github/pull_request_template.md) for this change: checks actually run (ticked only if the diff or CI supports it), risk level with what can break, and a rollback path. Placeholders left in place are a 🟡.

## 7. Spec, scenarios and evidence

The agreed spec in GitHub Issues is the reference the result is checked against: the PR names it (`Спецификация: #N`), or the ticket from `Refs #N` links it (`спека: #N`). The scenarios are chosen in that spec, and `.github/workflows/verify.yml` checks them in a separate CI job without the model secret. The reviewer compares the result with the spec and reads the evidence. It does not run the scenarios itself.

- **Conformance:** read the whole spec and compare it with the diff, item by item:
  - **Solution** and **Implementation Decisions:** each decision is implemented as written (fields, limits, error codes, where things appear in the UI, what is reused). A deviation is a 🔴 unless the PR explains it and the spec was updated.
  - **User Stories:** every story the ticket covers is implemented and observable. List the ones you couldn't find in the diff.
  - **Testing Decisions:** the tests go through the seams the spec chose and cover the cases it lists.
  - **Out of Scope:** nothing listed there was implemented. Scope creep is a 🟡, or a 🔴 when it changes the contract.

- A `fix:` or `feat:` PR names its spec (`Спецификация: #N`). The main and adjacent scenarios in the PR match the spec's `## Verification Scenarios`, and the diff adds or extends the main scenario's e2e test. A missing spec, or scenarios that differ from it, are a 🔴. «Спецификация: нет» is fine only for docs and CI changes.
- **Bug fix:** the main test fails on the base commit and passes after the fix, and the adjacent one passes on both. **New feature:** the main test fails without the new behaviour and passes with it. Check that the test asserts the behaviour itself, so it fails on base for the right reason and not because of a typo or a missing selector.
- **Evidence:** the `verify` run for the current head SHA and its artifact `verification-pr<N>-<sha>`. Report its state as you find it: `pass`, `fail`, `not applicable`, or still running / not started. This review runs in parallel with CI, so the artifact may not exist yet. Then say so instead of guessing, and leave the check to the human, who compares the artifact SHA with the current head before merging. An artifact for an older SHA proves nothing about this version.

## 8. Maintainability

- Simple over clever; no dead code, unused exports or speculative abstractions.
- Names say what things are in domain terms; comments explain why, not what.
- The change is small enough to review; unrelated refactors go to their own PR.

## Verdict

End the review with one summary comment:

- **Verdict:** ✅ ready to merge, 💬 merge after "should fix" items are addressed or answered, or ⛔ blockers found.
- Counts per level and a one-line list of the blockers.
- Spec conformance: the spec number, decisions or stories that are missing or deviate, or «соответствует спецификации».
- The `verify` evidence state for the current head SHA (section 7).
- What was not reviewed (for example, large generated files) so a human knows where to look.
