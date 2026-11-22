# Triage Labels

Two labels carry the whole triage state; `wontfix` is GitHub's default label. An open issue with none of them is an incoming request that nobody has triaged yet.

| Label in our tracker | Set by                                           | Meaning                                     |
| -------------------- | ------------------------------------------------ | ------------------------------------------- |
| `ready-for-agent`    | `to-spec`, `to-tickets`, or a human after triage | Fully specified, an agent can implement it  |
| `needs-info`         | `triage`                                         | Waiting on the reporter to answer questions |
| `wontfix`            | a human                                          | Will not be actioned                        |

Roles the mattpocock/skills name map onto these:

- `needs-triage`: no label. Absence of every label above means "not triaged".
- `ready-for-human`: not used. A human picks up any open issue without `ready-for-agent`.

The auto-triage workflow (`.github/workflows/claude-triage.yml`) skips an issue that already has any label from the table, so tickets from `to-tickets` and specs from `to-spec` are never triaged again.
