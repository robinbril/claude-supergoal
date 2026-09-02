# The seven lenses: concrete checks per lens (stack-neutral)

Give each lens agent its section below, plus the diff, the context paragraph from phase 0,
the project map and the stack appendix (`stack-django.md`, `stack-frontend.md`, or a custom
`stack-<name>.md`). Each lens produces at most 8 candidates **before verification**, each with
a failure scenario; anything without a failure scenario does not make the list. (The cap of five
bundled P3's in the report applies **after** verification, across all lenses combined.)

Three reading rules for all lenses:

- **Read the enclosing function of every hunk**, not just the changed lines. A bug in an
  unchanged line of a touched function is in scope.
- **Audit what was removed.** For every deleted or replaced line: which invariant or guard did
  it enforce, and where is that enforced again? Not found: candidate. A removed test counts too.
- **Follow the callers.** Grep every changed function, property, serializer field and template
  variable. New precondition, different return shape, new exception, different ordering: check
  each call site, and whether a parallel change in the same PR makes a call unsafe.

Verification bias: `PLAUSIBLE` is the default for realistic runtime states (race, empty set,
missing optional field, cold cache, boundary date); refute only with evidence from the code.

---

## bugs

Ask per line: **which input, state, timing or environment makes this line wrong?**

- Inverted or incomplete conditions; precedence; `if x:` where `0`, `""`, an empty object or an
  empty list is a valid value (falsy-zero).
- Off-by-one on period and date boundaries (`<` vs `<=`, inclusive end date, week boundary).
- None/undefined paths: nullable relations, `.first()`/`.find()` returning nothing, a missing
  setting, `get()` on a dict from an external API.
- Wrong variable after copy-paste (rate A where rate B was meant; ids where codes belong).
- Exceptions that hide the error: a broad `except` that reports a programming error as an
  "external error"; `return None` in an except where the caller infers success.
- Ordering and timing: value read before it is set; hook firing before commit; job receiving an
  id that is not yet committed; status set and only then validated.
- "What if it runs twice?" Scheduled jobs without a lock, webhooks without idempotency, `save()`
  in a retry path, number assignment `max+1` without a lock.
- "What if the external call fails halfway?" External succeeded but not stored locally (or vice
  versa); mail sent and then a rollback.
- Language pitfalls: mutable default arguments, late-binding closures, `is` vs `==`, float
  equality, defaults evaluated once, iteration during mutation, `zip` on unequal lengths, a
  forgotten `await`, a promise without catch.
- Wrappers/adapters/decorators: do they route to the wrapped object or back through a
  registry/global (recursion)? Are all methods the callers use passed through?

## data

Data quality and integrity, measured against the real database (see `prod-parity.md`).

- Every model change has its migration in the same PR; risky operations assessed against real
  data and the deploy order; data migrations idempotent with a reverse.
- New field: null/blank/default consistent with how the code reads it; `""` vs `None` not mixed;
  enum with a deliberate default; relations with a deliberate on-delete; uniqueness that the
  domain requires also in the schema (otherwise `get_or_create` races).
- Money: decimal types, coercion via string, explicit rounding to the correct precision, sign
  conventions of the accounting package respected, never `float` in anything stored or posted.
- Time: timezone-aware now/today when stored or used as a day boundary; period attribution via
  the project's period helpers, not via the invoice date.
- Syncs: upsert on the external unique id; no duplicate rows on repeat; deleted at the source ->
  what happens locally; partial writes without a transaction; side effects on commit.
- Bulk paths bypass model hooks and validation; does that match what lives in the hooks?
- Query shape: N+1 (query in loop, `obj.fk.id`, serializer field with `.all()`), unbounded lists
  without pagination, `len()`/`bool()` on querysets, `distinct`+`order_by` on relations,
  iterators without chunking.
- Append-only or trigger-guarded tables: no `update()`/`delete()` in new code; the trigger
  catches it in prod, not in tests without migrations.

## domain

Does the code do what the domain says, at the place where the domain wants it?

- Test every changed line against the invariants in the project map (required querysets/filters,
  scoping, status sets that count, write boundaries, configurable boundaries).
- Requirement trace: what the PR description promises is COMPLETE, DEVIATED, OMITTED or UNPROVEN;
  **extra** behavior nobody asked for is a regression until it is deliberate.
- State machines: transitions via the service layer under a lock; forbidden paths not reachable
  through a "convenient" admin action.
- Altitude: an `if client == X` or `if type == Y` in shared infrastructure is a band-aid; does
  the rule belong in a model property, service, rule engine or setting?
- Hardcoded boundaries (minimum amount, percentage, term) where the project wants a configurable
  setting or rule: P1.
- Comments and docs: does the claim in a docstring, CLAUDE.md, ADR or contract still hold after
  this diff? A diff that makes a document sentence untrue takes the document with it.
- Calculations mirroring an external source (Excel, an old package) with open decision points: an
  "improvement" there is an owner's decision, not a PR.

## security

Only concretely exploitable or privacy-relevant findings, with an attack path. No theoretical
hardening, no DoS, no rate limiting without consequence.

First work out the project's existing patterns (permission classes, mixins, wrappers, scoping
helpers, encryption) and compare the diff to them; deviation from the house pattern is the best
predictor.

- **Authz**: new view/endpoint/tool without the house pattern; write action under a read
  permission; object-level: can user A read tenant B's object via an id? Tenant scoping missing
  on a new query.
- **Deliberately open surfaces** (portals, webhooks, uploads with a token in the URL): every
  change there is P0 territory; tokens have expiry and scope; no enumeration via error messages.
- **Injection**: raw SQL with interpolation on non-constant input; `mark_safe`/`v-html`/
  `innerHTML` on user data; subprocess with a shell; path traversal in upload/document paths;
  unsafe deserialization.
- **Secrets**: a new key/token in code, settings with a default, fixtures, migrations, tests, log
  lines; a secrets baseline that grows with something that is not a placeholder.
- **Personal data**: identity numbers, salary, IBAN, date of birth, medical or screening
  information in logs, `__str__`, admin lists, API responses beyond their purpose, exports, mail,
  agent-tool output, persistent frontend state. A new sensitive field without encryption; no
  deletion path for what must be deletable.
- **Write boundaries**: every new write to an external system outside the places the project map
  names, including via a helper (an AST test sees only direct calls).
- **Session/CSRF**: new `csrf_exempt`; empty authentication classes without a docstring; fetch
  bypassing the CSRF cookie.
- **External calls**: host/protocol from user input (SSRF); TLS verification disabled; missing
  timeouts (hanging worker).

Assumptions against noise: env vars and CLI flags are trusted; UUIDs are not guessable; modern
frontend frameworks escape by default; client-side checks are not security and are not reported;
a missing audit log is not a vulnerability.

## quality

Simplification, reuse, duplication, dead code, AI slop and spaghetti; see
`ai-slop-and-spaghetti.md`. Behavior-neutral improvements only; do not hunt for bugs.

- **Reuse**: grep the project's shared helpers (services, utils, adapters, factories) before
  accepting a new helper. Name the existing one.
- **Simplification**: derivable state kept separately; copy-paste with small variation; deep
  nesting that an early return resolves; dead branches; boolean parameters that branch behavior.
  Name the simpler form.
- **Efficiency**: repeated I/O or query in a loop; independent calls run sequentially; work on a
  hot path that is cacheable or prefetchable. Label perf claims as measured or not.
- **Altitude**: special case on shared infrastructure; rule in a view instead of a service; a
  service that takes a request; a hook that does work.
- **Dead code**: a definition without a caller (watch for dynamic dispatch: routes, registries,
  admin, job names as strings, templates, tool registries); a parameter nobody passes; an enum
  value with no use; a flag that is always set one way.
- **File growth**: a new responsibility in a file that is already too large belongs in a module
  beside it.

Never report: long why-docstrings, deliberately documented duplication, suppressions with a
reason, formatting the formatter handles.

## tests

Do the tests cover the **behavior** the diff promises, and do they fail when the code is broken?

- Every new branch, boundary and error path has a test; calculation logic has hand-computed
  asserts, not an assert on whatever the code happens to return.
- Negative cases: empty, zero, None, boundary date, duplicate input, second run (idempotency),
  wrong role, disabled flag.
- Tests that test the implementation: `called_once_with` without a result assert; mocking the
  function under test; mocking at the wrong layer (mock at the external boundary, not the
  service).
- Removed or weakened tests: which case did they cover?
- Test-settings drift (project map): a test that only passes because of such a deviation is not
  evidence. Hooks wiped without restoration make the suite order-dependent.
- Coverage floors: new code in a critical module without tests drags it below.
- Frontend: a new adapter/shape translation has a unit test; mock implementations keep satisfying
  the interface; typecheck green locally if CI does not run it.
- Per missing test: name the bug it would catch, otherwise no finding. Score 9-10 data
  loss/security, 7-8 business rule, 5-6 edge case; below 5 do not report.

## contract

Boundaries between components: API, frontend, MCP/agent tools, external parties.

- **API**: field removed/renamed/type changed -> who reads it (frontend types, adapters, MCP
  server, agent tools, other services)? Schema (OpenAPI) stays in line; pagination/filters
  consistent; endpoint registered where the project requires it; error shape consistent.
- **Frontend**: types and mocks follow; adapters pure; enum values from the backend, not
  hardcoded; error state visible; route guards; proxy prefixes match the reverse proxy; no
  backend knowledge in components.
- **UX contract**: a count in a header matches what the user can reach from that place; a cap
  without an overflow route while the header shows the total is a P2; comments that promise "the
  count follows the list" must still be true after a cap; a removed UI path leaves no setting or
  action that can no longer be set anywhere.
- **MCP/agent tools**: a tool per endpoint with the same scoping as the API; read-only unless
  explicit; output without personal data beyond its purpose.
- **External parties**: the contract document is the source; a change: document first, then code,
  and the other side named in the PR. Endpoints without a contract document: assumptions about
  stable fields are an open question in the report, not refuted or confirmed.
- **Templates (server-side)**: url names still exist; context variables the view no longer
  supplies; admin overrides that still match after a framework upgrade.
