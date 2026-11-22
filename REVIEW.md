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

- The change does what its ticket (`Refs #N`) asks, and nothing the ticket didn't ask for.
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
- The PR description fills in the template: checks run, risk, rollback.

## 7. Maintainability

- Simple over clever; no dead code, unused exports or speculative abstractions.
- Names say what things are in domain terms; comments explain why, not what.
- The change is small enough to review; unrelated refactors go to their own PR.

## Verdict

End the review with one summary comment:

- **Verdict:** ✅ ready to merge, 💬 merge after "should fix" items are addressed or answered, or ⛔ blockers found.
- Counts per level and a one-line list of the blockers.
- What was not reviewed (for example, large generated files) so a human knows where to look.
