# /superaudit

Production-grade PR review and bug hunt as a Claude Code / Codex skill. Seven parallel review
lenses, every finding adversarially verified before it is reported, checked against the real
environment where the code runs, ending in a merge verdict. Stack-neutral: it builds a project
map on first use so the review is specific to *your* repo instead of generic.

## What it does

You point it at a diff, a PR, a branch, or a path. It:

1. Scopes the change (range, touched files grouped by module, test targets, migrations, hard
   signals) and reports the **mode** — which toolchains are actually present, so "no errors"
   is never a silent "did not run".
2. Runs **seven lenses in parallel** (bugs, data integrity & migrations, business logic,
   security & privacy, quality/duplication/dead code/AI-slop, tests, API & frontend contracts).
3. **Adversarially verifies** every candidate finding — reads the callers, checks for an existing
   test, reproduces it where it can — and labels each `CONFIRMED`, `PLAUSIBLE`, or `REFUTED`.
   Refuted findings are dropped (listed in one line), so the report stays trustworthy.
4. Runs the project's own fast checks (`fastcheck.sh`: lint on new findings only, typecheck,
   the tests that belong to the touched code) and reports what it could not run.
5. Ends in a **verdict**: `MERGE` / `MERGE AFTER FIXES` / `DO NOT MERGE`, with findings graded
   P0–P3 and each one carrying a concrete failure scenario.

The rule the whole skill is built on: **a finding without a failure scenario does not exist.**
Every finding names file:line, the concrete input or state, and what goes wrong.

## Install

From the repo root:

```bash
./install.sh --only superaudit      # into ~/.claude/skills/ (all projects)
./install.sh --only superaudit --project   # into ./.claude/skills/ (this project only)
```

Or copy `superaudit/` to `~/.claude/skills/superaudit/` by hand. Start a new session; `/superaudit`
then appears as a slash command.

## Quickstart (2 minutes)

```bash
# 1. Optional but recommended: tell it your lint/test/typecheck commands.
cp superaudit/config.example.json .claude/superaudit/config.json
$EDITOR .claude/superaudit/config.json   # fill in your project's commands

# 2. Review. On the first run it builds a project map under .claude/superaudit/ (commit it).
```

```
/superaudit                 # your branch vs the default branch, plus the working tree
/superaudit #123 --comment  # a PR, posting findings as inline review comments
/superaudit main..HEAD      # an explicit git range
/superaudit src/billing     # codebase audit of a path (no diff needed)
```

`config.json` and the generated `project-map.md` live under `$SUPERAUDIT_ROOT`
(default `.claude/superaudit/`) and belong in git — they are the shared knowledge that turns a
generic review into a review of *this* repo.

## Flags

| Flag | Effect |
|---|---|
| `--fix` | apply the P0/P1 fixes and safe P2s, re-run `fastcheck.sh`, report what was fixed and what was left |
| `--comment` | post the findings as one pending GitHub review with inline comments (never APPROVE/REQUEST_CHANGES) |
| `--lens=name` | run only one lens (`bugs`, `data`, `domain`, `security`, `quality`, `tests`, `contract`) |
| `--fast` | one pass, no parallel agents, P0/P1 only — for small diffs (under ~100 changed lines) |
| `--recheck` | re-review after fixes: judge each earlier finding RESOLVED / NOT RESOLVED |

## Example verdict

```
# superaudit — main..HEAD (polpo_sync coupling)

**Verdict: MERGE AFTER FIXES** — two correctness bugs in the guid-coupling path;
both have a concrete trigger and a small fix. Everything else is green.

P1  coupling.py:196  A guid can land on two dossiers under a name correction.
    Scenario: ATS renames a candidate -> second pull matches on names, not guid ->
    two NewDeal rows share one polpo_deal_id -> status API returns the wrong one.
    Fix: check for an existing holder of the guid before update (added below).

P1  import_polpo_deals.py:117  Conflict path mutates the dossier before the guid check.
    ...

**Not verified:** migrations against real data — no DB in this session; see prod-parity.md.
```

## What's in here

```
SKILL.md                 the skill instructions (the tech-lead review method, phase by phase)
config.example.json      copy to .claude/superaudit/config.json and fill in your commands
references/
  lenses.md              the concrete checks per lens, stack-neutral
  lens-prompt.md         the template for the parallel lens agents, and what a full run costs
  project-map-template.md  what the project map must contain and how to build it once
  prod-parity.md         where test and prod diverge; checking a change against the real env
  ai-slop-and-spaghetti.md  signatures of generated noise and wrong-layer code
  report.md              the report template with calibration examples
  stack-django.md        pitfalls for Django/Python backends
  stack-frontend.md      pitfalls for TS/Vue/React frontends
scripts/
  scope.py               scope map + preflight (read-only; what the diff touches, which toolchains)
  fastcheck.sh           the fast checks a colleague runs before pushing, limited to the diff
```

A different stack? Write a `references/stack-<name>.md` in the same shape and point to it from
your project map. `scope.py` and `fastcheck.sh` are already stack-neutral and driven by
`config.json`.

## Works on

Claude Code and Codex. Where subagents aren't available, all seven lenses run in one pass instead
of in parallel; the report opens with a `Mode:` line saying so. The checks it redoes don't depend
on that context, so the substance holds.
