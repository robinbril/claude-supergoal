# Stack appendix: SPA frontends (Vue/React + TypeScript)

## Contract with the backend

- One typed `Api` interface; the HTTP layer does only I/O and error translation; adapters
  are pure, unit-tested shape translation; the mock implementation keeps satisfying the
  interface (the typecheck catches it, if it runs).
- Enum values (statuses, roles) come from the backend or a shared type, never hardcoded
  strings in components.
- Error state is visible; no automatic retry on 4xx; auth guard via a `me` endpoint; CSRF
  token sent on writes with session auth.
- Proxy prefixes (`/api`, `/admin`, ...) and `base` match the reverse proxy in prod; a
  route outside those prefixes never arrives.

## Reactivity and state

- `computed` without side effects; `watch` with `immediate` where the first value matters;
  `v-if` on a field that only exists after a fetch; optional chains (`?.`) that let
  `undefined` flow into a calculation.
- Query caches (TanStack) with the correct keys and invalidation after a mutation; stale
  data after a write is a finding.
- Persistent state (`localStorage`, `sessionStorage`): no tokens, no personal data; wrap in
  try/catch; render correctly with no stored value.

## UX contract

- Counts in headings match what is reachable; a `slice`/cap with no overflow route while
  the heading shows the total is a P2.
- Bulk actions operate on the displayed set; thresholds ("at least 3 identical actions")
  against the visible rows, and that is either deliberate or not.
- A removed field/button/endpoint leaves behind no setting that can no longer be set
  anywhere; docstrings and help texts that point at the old path come along too.

## Security

- `v-html`/`innerHTML`/`dangerouslySetInnerHTML` only on sanitized content (DOMPurify with
  an explicit config).
- No backend permission logic in the client as proof of security; the backend decides.

## Tests and tooling

- Typecheck (`vue-tsc`/`tsc`) and unit tests (vitest/jest) often do not run in CI; then run
  them locally and put that in "Evidence".
- New adapter, new calculation in a component, new cap: each gets a test with the concrete
  expectation (row count, label, link).

## CSS specificity (many missed "bugs")

- A new `:hover`/`:focus-within` rule with higher specificity overrides a state class
  (`--busy`, `--active`) that is less specific later in the cascade: the state disappears
  the moment the mouse is over it. Check the specificity, not just the order.
- A `transition` on a property that is never set is dead; `!important` is a symptom.
