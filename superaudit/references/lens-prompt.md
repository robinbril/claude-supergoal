# Prompt template for a lens agent

Use this template for each of the seven agents in phase 1. Fill in the `<...>` fields;
leave the rest as-is. Its strength comes from three things: the agent reads the lens
section and the project map itself (not your summary), it receives the context paragraph
with the invariants that must hold, and it receives a list of concrete locations and
questions that sharpen the lens for this specific case. Without that third point an agent
searches generically; with it, it searches where the diff can actually break.

```
You are the lens **<name>** of a /superaudit review. Repo: <path> (<stack>). Do not modify any files.

Read first: (1) the section "## <name>" plus the three reading rules at the top of
<SUPERAUDIT_DIR>/references/lenses.md, (2) <the applicable stack appendix/appendices>,
(3) the project map <SUPERAUDIT_ROOT>/project-map.md (<which tables are most relevant>),
(4) the full diff in <scratchpad>/diff-<ref>.patch (range <a..b>).

Context (what the author intended, what must hold): <the context paragraph from phase 0,
including the invariants as standalone sentences: "never overwrite X", "at most one row per
Y", ...>.

Also read the surrounding code, not just the diff: <files and functions from the blast
radius: callers, models with field types and constraints, tests, contract documents>.
Follow callers with grep.

Investigate specifically: <five to ten concrete questions for this lens on this diff, e.g.
"is the update inside the same transaction as the create?", "is the field unique in the
schema and what does .first() do on two matches?", "which branch of function F is
uncovered?", "does doc line R still match code C?">.

Deliver at most 8 candidates, exclusively as a JSON array in this format, each with a
concrete failure scenario; no failure scenario, no candidate. No style notes, no "consider".
Then give, in one paragraph, which suspicions you investigated and refuted (for
"Deliberately not reported").

[{"lens": "<name>", "file": "path", "line": 42, "severity": "P0|P1|P2|P3",
  "summary": "one sentence, the claim itself",
  "failure_scenario": "concrete input/state -> concrete wrong result",
  "evidence": "what you checked: file:line, callers, test, docs",
  "fix": "smallest correct fix or 'design choice: ...'",
  "confidence": "CONFIRMED|PLAUSIBLE"}]
```

Per lens, the extra line that makes the difference:

| Lens | Add to "Investigate specifically" |
|---|---|
| bugs | "What if it runs twice? What if the external call fails halfway? Which guard was removed or made one-way?" |
| data | "Transaction context of every write; unique constraints behind every exists()+create() and get_or_create; `.first()` on a non-unique field; serialization of new types in dicts that go to JSON/Celery; does a migration belong with it?" |
| domain | "Requirement trace per claim from the commit message (COMPLETE/DEVIATED/OMITTED/UNPROVEN); does every document that serves as a contract still hold; where is the outcome visible to a human?" |
| security | "Work out the house patterns first and compare; PII in log, error and response fields; can external input claim an existing object; does the diff touch a write boundary?" Plus the assumptions against noise from lenses.md. |
| quality | "Does the helper already exist (grep the core line, e.g. sha256/idempotency_key/parse); is the docstring reason true; dead defaults and unreachable branches." P2/P3 only. |
| tests | "Which branches of the new code does no test touch; which bug would each missing test catch (score 5-10); does the test mock the boundary or the subject; does it rely on test-settings drift from the project map?" |
| contract | "Is every assumption about an external payload proven in this repo (fixture, doc, real call)? Who reads each changed or new field (types, adapters, MCP, agent tools)? Does the contract document hold after this diff, explicit yes/no?" |

## Cost and when you incur it

A full run with seven agents on a diff of ~250 lines cost in practice around 800k tokens
and five to six minutes wall-clock, and surfaced two P1s that a single pass had missed
(five lenses converged on the same bug, which raised the confidence from PLAUSIBLE to
CONFIRMED). That price is worth it for a merge to production, not for a ten-line commit:
there, `--fast` or the single-pass mode applies. Verify agents are only needed when a
candidate was found by a single lens and the trigger rests on data or timing; candidates
that two or more lenses converge on you verify yourself by reading the cited lines.
