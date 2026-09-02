# Prod parity: where test and production diverge

A green CI proves less than it appears to. The project map names the concrete
divergences for this project; this document says what you look for and how to test a change
against the real environment without writing anything.

## What you look for in the test settings

| Divergence (examples) | Consequence for the review |
|---|---|
| Migrations disabled in tests (`MIGRATION_MODULES`, `--no-migrations`, schema built from models) | A migration cannot fail in CI. Assess each schema operation on a populated table separately against real data (below). |
| `DEBUG`/dev mode on in CI | Code that branches on debug (error pages, redirects, security headers) has never run the prod path. |
| Auth lockout, rate limiting, CSRF, 2FA off | Login and token flows never see lockout or CSRF behavior in tests. |
| External providers pinned to a different branch than prod (mock provider, different extraction backend) | The prod branch needs its own suite; a change must touch both. |
| Feature flags always on in tests | Code can silently no-op in prod. Check the flag read at the narrowest point. |
| Signals/hooks/receivers wiped in tests | A test that passes without receivers says nothing about behavior with receivers. |
| `on_commit` callbacks that never fire inside the test transaction | Post-commit side effects (mail, jobs, webhooks) are invisible in tests unless explicitly captured. |
| Lint advisory (`allow_failure`, `continue-on-error`) | Lint errors block nothing; new ones are a P3, existing ones not. |
| Fixed keys/secrets in test settings | New encrypted fields: check that key derivation does not hang off the test value. |

## Assessing migrations against real data

For each migration in the diff, in this order:

1. **What is currently in the column/table?** Read-only, via the app shell in the container or a
   database client: `count(*)` where the column is null for a new not-null;
   `GROUP BY <column> HAVING count(*) > 1` for a new unique; rows that violate a new
   check constraint. Never write; no `UPDATE`, no `migrate` against a prod URL.
2. **Show the SQL** (`sqlmigrate`, `prisma migrate diff`, `alembic upgrade --sql`, ...).
   Watch for `SET NOT NULL` without a default, `ADD CONSTRAINT ... UNIQUE`, `DROP COLUMN` on a
   column that old code still reads, `CREATE INDEX` without `CONCURRENTLY` on a large table.
3. **Deploy ordering**: do web and workers cut over simultaneously? A `RemoveField` breaks the
   old worker until it restarts; a not-null without a default breaks the old web until the
   migration finishes. On populated tables the norm is: add nullable, backfill,
   not-null; drop the column only in the release *after* the code that no longer reads it.
4. **Data migrations**: idempotent, with a reverse (or an explicit `noop`), via the historical
   models (not the real ones, which already have the new schema), batched on large tables,
   not in one transaction with a schema change if the database cannot handle that.
5. **Backfill that copies a business rule** out of a service: drift at the moment of
   migrating. Check equality with the service.
6. **Changes carried along** in a generated migration: which `AlterField`s actually change
   something (type, null, length reduced, choices that exclude existing values)?

## Reading the real environment without touching anything

- App shell in the container, read-only ORM queries, `EXPLAIN` on a new query with
  real table sizes.
- Project MCP tools that read the local database: prove something about the local
  data, nothing about the external system itself. For the external system, only its own
  status/read tools.
- Prod settings: for new env vars, check whether they have a default or whether the deploy fails
  when they are missing; say so in the report.
- Routing/proxy: a new route outside the prefixes the reverse proxy forwards never
  reaches prod.

## Data-quality checks in a codebase audit

An audit on a path (not a PR) includes a read-only data scan that the code cannot show:

- Columns `null=True` that are in practice never null (and the reverse: not-null filled
  with `""`/`0` as "no value").
- Duplicate relations (same external id, chamber-of-commerce number, email) where the domain
  expects uniqueness.
- Statuses the model no longer knows (enum removed, rows remained).
- Records "sent/booked" without the external id that belongs with them.
- Rows that fall outside an accounting or time boundary but still count somewhere.
- Datetimes without a timezone in timezone-aware columns.

Report with the query and the count, never with a proposal to "fix" data without an
owner: data correction is a decision, not a PR.
