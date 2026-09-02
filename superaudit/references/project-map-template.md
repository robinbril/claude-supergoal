# Project map: template and workflow

The project map (`$SUPERAUDIT_ROOT/project-map.md`, default `.claude/superaudit/`) is what turns a
generic review into a review of *this* project. It holds the agreements that any diff can cross
without that diff's own tests noticing, and for each one, who guards it: a test, CI, the database,
or only the reviewer. Where the guard is "reviewer", the lens should look extra closely.

Build it once with an Explore agent (or yourself) in fifteen minutes, commit it, and update it as
soon as a diff adds, changes, or invalidates an agreement.

## How to build it

Have an Explore agent (breadth: very thorough) map the following and report with file paths and line
numbers:

1. **Test infra**: runner, settings, what the test suite deliberately does differently from prod
   (migrations off, debug on, auth off, mocks at external boundaries), invariant tests with their
   allowlists, factories, conventions around signals/hooks/fixtures.
2. **Lint, format, typecheck, CI**: exact commands, what is advisory and what blocks, coverage
   floors. Put the commands in `config.json` too (see below).
3. **Migrations and deploy**: how migrations run in prod, whether web and workers transition
   simultaneously, known caveats of the migration check.
4. **Money, time, period**: types, rounding, time-zone handling, period helpers.
5. **Domain models and statuses**: the core models, their constraints, the status enums and which
   sets "count" somewhere.
6. **Services and guarded querysets**: the layer where the business rules belong, and the
   querysets/filters that are mandatory (tenant scoping, accounting boundaries).
7. **Write boundaries to external systems**: which files may write to the accounting package, the
   ATS, the mail, and which test guards that.
8. **Access**: the house pattern for authz per view/endpoint/tool, the deliberately open surfaces,
   and the known gaps.
9. **Background tasks**: tasks, scheduling, lock and idempotency patterns, retry policy.
10. **Contracts**: API schemas, frontend types, MCP/agent tools, documents with external parties,
    and which of these are missing.
11. **Personal data**: which fields are sensitive, how they are encrypted/shielded, deletion paths.
12. **Known debt and open decisions**: what is deliberately not fixed and why.
13. **Documentation index**: ADRs and contract documents with keywords, so a reviewer opens only
    what bears on the diff.

## Template

```markdown
# Project map <repo> (updated <date>, commit <sha>)

Stack: <language/framework/db/queue/frontend>. Stack appendices: stack-django.md, stack-frontend.md.
Commands: see config.json (lint, typecheck, test, test-selector).

## Documentation index
| Document | Keywords |
|---|---|
| docs/adr/0001-... | ... |

## What the test suite does differently from prod
| Test/CI | Prod | Consequence for the review |
|---|---|---|
| migrations off in tests | migrate on deploy | migrations are never "tested by CI" |

## Invariants
### <domain 1, e.g. finance core>
| Agreement | Where | Guard |
|---|---|---|
| ... | path:line | test X / CI / DB / reviewer |

### Write boundaries to external systems
| Agreement | Where | Guard |

### Configuration and background tasks
### Access and personal data
### Tests and tooling
### Contracts (API, frontend, external parties)

## Known gaps and open decisions
- <gap>: <why open>, <who decides>

## Data-quality checks (read-only) for a codebase audit
- <query or shell snippet>: <what it proves>
```

## config.json

`fastcheck.sh` reads `$SUPERAUDIT_ROOT/config.json`. Without that file it detects the stack
(ruff/pytest/manage.py test/npm scripts) and states what it assumed.

```json
{
  "runner_prefix": "docker exec mijn_web_container",
  "lint": "ruff check --output-format concise",
  "typecheck": "cd frontend && npx vue-tsc --noEmit",
  "test": "python manage.py test {modules} --settings=project.settings.test",
  "test_all": "python manage.py test --settings=project.settings.test",
  "test_module_for": {"pattern": "^project/(modules/[^/]+|api)/", "template": "project.{1}", "dotted": true},
  "always_test": ["project.modules.core.tests_invariants"],
  "frontend_test": "cd frontend && npx vitest run {files}",
  "migration_check": "python manage.py makemigrations {app} --check --dry-run",
  "app_for": {"pattern": "^project/modules/([^/]+)/", "template": "{1}"}
}
```

`{modules}`, `{files}`, `{app}` are filled in from the scope; `runner_prefix` prefixes every command
that must run in a container. Leave a key out if the step does not exist; `fastcheck.sh` then reports
"SKIPPED (not configured)".
