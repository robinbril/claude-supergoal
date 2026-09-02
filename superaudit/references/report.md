# Report template and calibration

## Template

```
# Superaudit: <range | PR #n | path>

**Mode: degraded.** <omit if the run was complete. Otherwise: no lens agents (all lenses
run yourself in a single pass), no toolchain (tests and migrations not run), no
node_modules (typecheck and unit tests not run), PR not fetched. What is labeled
"CONFIRMED" then rests on code reading, grep of callers, and scratchpad reproductions.>

**Verdict: MERGE | MERGE AFTER FIXES | DO NOT MERGE**
<One paragraph. What the change does in plain language, what is good about it, and the
reason for the verdict. No listing of files: that is in the diff.>

**Not verified:** <omit if everything ran. Otherwise: what could not run and why.>

## Findings

### P0 <title as a claim, not a question> — `path/file.py:123`
Failure scenario: <concrete state or input> -> <concrete wrong result>.
Evidence: <what you checked: callers, a missing/failing test, reproduction, docs>.
Fix: <smallest correct fix, or "design choice: A or B, because ...">.

### P1 ...

### P2 ...

### P3 (bundled)
- `path:line` <one line>

## Deliberately not reported
- <the suspicion a reader would have> : refuted because <reason>.
- <existing problem outside the blast radius> : out of scope, tracked at <place> as a
  follow-up.

## Evidence
- scope: <the summary lines from fastcheck.sh: range, shortstat, directories, migrations>
- fastcheck: <green/red; lint new/existing; which steps SKIPPED>
- reproductions: <scripts/tests you ran, with outcome>
- lenses: <per lens: agent or self, and "nothing" or the finding numbers>
- gap sweep: <what you searched for and whether it was empty>
```

## What a good finding is

**Good (P1):**

> ### P1 `invoice_ready()` marks an invoice as ready while the required PO is missing — `billing/invoice_ready.py:88`
> Failure scenario: client with `po_required=True` and a contract without `po_number`; the
> new `all(...)` check iterates over `checks` but `po_check` dropped out of the list in this
> diff (line 71). The invoice moves to "ready" and the posting in `invoice.py:214` uses an
> empty PO reference; that invoice is rejected by the client.
> Evidence: `tests_invoice_ready.py` has no case with `po_required=True`; scenario
> reproduced in the shell with a factory: `ready == True`.
> Fix: put `po_check` back in `checks`, plus a test with `po_required=True` without a PO
> that expects `ready is False`.

Claim in the title, concrete state, the path to the damage, evidence the reader can
retrace, a fix the author can apply directly.

**Bad:**

> `invoice_ready()` may possibly return True incorrectly in certain cases. Consider adding
> extra validation.

No state, no line, no damage, no evidence, and "consider" pushes the work onto the reader.

**Not a finding (omit, or put in "Deliberately not reported"):**

- "A Decimal is compared to an int": that is correct. Refuted.
- "The view has no login check": the route sits under a wrapper that enforces login and
  role. Refuted, belongs in "Deliberately not reported" because a reader would suspect this
  too.
- "Function is 60 lines, split it up": no failure scenario, no maintenance risk shown.
- "Use f-strings": linter territory.

## Severity calibration

Ask per finding: **what happens in production, to whom, and how quickly does someone notice?**

| Situation | Level |
|---|---|
| Wrong money amount, however small | P0 |
| Personal data in a log, a response beyond its purpose, or an unencrypted new field | P0 |
| View/endpoint without authz where it exists elsewhere | P0 |
| Migration that fails on prod (not-null without default on a populated table, unique on duplicate data) | P0 |
| New write path to an external system outside the agreed places | P0 |
| Wrong result in a real but non-daily scenario | P1 |
| Sync/job that creates duplicate records on repeat | P1 |
| Status transition that allows a forbidden path | P1 |
| Silent failure where the user sees a success message | P1 |
| Duplicate of an existing helper with slightly different semantics | P2 |
| Test that covers only the happy path on calculation logic | P2 |
| N+1 in a list that has hundreds of rows in prod | P2 (P1 if the page is already slow because of it) |
| Dead code, dead import, misleading comment | P3 |

Torn between two levels: pick the lower one and say in the failure scenario why it is not
one level higher. Overstating costs more trust than understating.

## Tone

Direct, factual, without "maybe", without "great work!" as filler, without repeating what
the diff already shows. In the language of the project.
