# AI slop and spaghetti: signatures, and when it is a finding

A lot of code is written with model assistance. That is not a problem; the problem is the
residue a model leaves behind when nobody removes it. The core question is always: **does
this cost the next reader or the next change anything?** If yes, it is a finding. If no,
leave it; a review is not a beauty contest.

## Signatures of generated noise

| Signature | What it looks like | Finding? |
|---|---|---|
| Comment that restates the line | `# increment counter` above `counter += 1` | P3 bundled, only if it gets in the way. A *why* comment is not slop |
| Defensive layer on impossible input | `if not isinstance(x, dict): return {}` on an internal dict argument; try/except around code that cannot fail | P2 if it hides a real error, otherwise P3 |
| `except Exception: return None/[]/{}` | silent fallback that hands the caller an empty but "valid" value | **P1** if it makes a user see success on a failure; P2 otherwise. Ask: who notices the error? |
| Fallback cascade | `x = a or b or c or DEFAULT` where `b` and `c` are never populated | P2 |
| Configuration explosion | parameters/flags for variants no caller uses | P2 (a dead parameter is a lie about the contract) |
| Abstraction for a single case | base class with one subclass, strategy with one strategy, registry with one entry | P2 if new in the diff; leave existing ones unless the diff extends them |
| Helper that already existed | a new `to_decimal`, `parse_date`, `month_bounds`, or scoping calculation alongside the existing one | **P2** with the name of the existing helper |
| Near-duplicate | two functions that differ on one line or constant, with a copy-pasted docstring | P2, unless deliberately documented (and then: are both places changed identically in the diff?) |
| Type theater | `Optional[Any]`, `dict[str, Any]` everywhere, `cast()`/`as any` that hides an error | P3; P2 if a cast masks a real type error |
| Logging noise | `info` on every step; debug with f-strings containing personal data | P3; **P0** for personal data or tokens in the log line |
| Emoji, marketing adjectives ("robust", "seamless"), conversational artifacts ("Here is", "Note that") in code or commits | see left | P3 bundled; never the only finding |
| Test that tests the implementation | `called_once_with` without a result assertion; mock of the function under test | P2 |
| Happy-path-only test on calculation logic | one case, no empty/zero/boundary | P2 on money/compliance, P3 elsewhere |
| Suppression without a reason | `# noqa`, `# type: ignore`, `eslint-disable` without explanation | P3 |
| Reorganization mixed with behavior | moving and renaming 400 lines alongside a functional change | not a finding in itself; state in the verdict that the review is less reliable as a result, and ask for a split if it touches P0/P1 territory |
| Generated migration with surprises | ten `AlterField`s caused by a `help_text`, alongside the real change | P3; **P1** if there is a type, null, or length change among them that the author does not mention |
| Hallucinated dependency | a package that does not exist or is not in the lockfile | **P0** (slopsquatting risk); verify with the package manager |

## Spaghetti: code at the wrong altitude

| Signature | Finding? |
|---|---|
| Special case on shared infrastructure (`if client == "X"` in a service; a type check in a generic serializer) | P2; name where the generalization belongs |
| Business rule in a view/serializer while a service, rule engine, or setting exists for it | **P1** if a source already exists (two sources drift); P2 if it is the first place |
| A boundary hardcoded that should be configurable | P1 |
| Service that takes a `request` | P2 (API and page then not guaranteed to produce the same numbers) |
| Signal/hook doing work a service should do (network, external writes, mail) | P1 if new |
| Serializer/view running queries without prefetch, or `.objects.all()` where a guarded queryset belongs | P2 (N+1) / **P1** (scoping) |
| Frontend with backend knowledge (hardcoded enums, business rules in adapters) | P2 |
| God file grows further with a new responsibility | P3; P2 if the file thereby takes on two jobs |
| Three or more boolean parameters that branch behavior | P2 |
| Implicit ordering dependency without a check | P1 if the failure is silent, P2 if it fails loudly |

## Dead code

| Signature | How you prove it | Finding? |
|---|---|---|
| Function/class without callers | grep across all languages; watch for dynamic dispatch (routes, registries, admin, job names as strings, templates, tool registries) | P3; P2 if it is misleading |
| Parameter no one passes | grep the callers | P3 |
| Enum value without use, with rows in the database | code grep plus a read-only `count()` | P2 |
| Flag that is always set one way | setting never set anywhere, or always equal in tests and prod | P2 |
| Component/template without a route or import | grep the name | P3 |
| Data migration that references a removed field | read the migration | P1 (breaks `migrate` on a fresh database) |
| Dependency no one imports | manifest versus imports | not a finding in a PR review; but it is in "Structural patterns" in an audit |

## What is NOT slop

- Long *why* docstrings and comments that explain a decision. Never report them as
  "too many comments".
- A deliberately duplicated line with a comment that explains the duplication and names the
  other place (do check that both change identically in the diff).
- A broad `except` **with** a suppression reason on a boundary (network, subprocess,
  audit log) where fail-soft is the intent.
- A settings read with try/except and a constant fallback when that is the convention.
