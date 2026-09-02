# Projectkaart: template en werkwijze

De projectkaart (`$SUPERAUDIT_ROOT/projectkaart.md`, standaard `.claude/superaudit/`) is wat
een generieke review omzet in een review van dít project. Hij bevat de afspraken die een
willekeurige diff kan overschrijden zonder dat de eigen tests van die diff het zien, met
per afspraak wie hem bewaakt: een test, CI, de database, of alleen de reviewer. Bij
"reviewer" hoort de lens extra scherp te kijken.

Bouw hem één keer met een Explore-agent (of zelf) in een kwartier, commit hem, en werk hem
bij zodra een diff een afspraak toevoegt, verandert of ongeldig maakt.

## Hoe je hem opbouwt

Laat een Explore-agent (breedte: zeer grondig) dit in kaart brengen en rapporteer met
bestandspaden en regelnummers:

1. **Test-infra**: runner, settings, wat de testsuite bewust anders doet dan prod
   (migraties uit, debug aan, auth uit, mocks op externe grenzen), invariantentests met
   hun allowlists, factories, conventies rond signals/hooks/fixtures.
2. **Lint, format, typecheck, CI**: exacte commando's, wat advisory is en wat blokkeert,
   coverage-vloeren. Zet de commando's ook in `config.json` (zie onder).
3. **Migraties en deploy**: hoe migraties draaien in prod, of web en workers gelijktijdig
   overgaan, bekende caveats van de migratie-check.
4. **Geld, tijd, periode**: types, afronding, tijdzone-afhandeling, periode-helpers.
5. **Domeinmodellen en statussen**: de kernmodellen, hun constraints, de status-enums en
   welke sets ergens "tellen".
6. **Services en guarded querysets**: de laag waar de business-regels horen, en de
   querysets/filters die verplicht zijn (tenant-scoping, boekhoudkundige grenzen).
7. **Schrijfgrenzen naar externe systemen**: welke bestanden mogen schrijven naar het
   boekhoudpakket, de ATS, de mail, en welke test dat bewaakt.
8. **Toegang**: het huispatroon voor authz per view/endpoint/tool, de bewust open
   oppervlakken, en de bekende gaten.
9. **Achtergrondtaken**: taken, planning, lock- en idempotentie-patronen, retry-beleid.
10. **Contracten**: API-schema's, frontend-types, MCP/agent-tools, documenten met externe
    partijen, en welke daarvan ontbreken.
11. **Persoonsgegevens**: welke velden gevoelig zijn, hoe ze versleuteld/afgeschermd zijn,
    verwijderpaden.
12. **Bekende schulden en open beslissingen**: wat bewust niet gefixt is en waarom.
13. **Documentatie-index**: ADR's en contractdocumenten met trefwoorden, zodat een reviewer
    alleen opent wat op de diff slaat.

## Template

```markdown
# Projectkaart <repo> (bijgewerkt <datum>, commit <sha>)

Stack: <taal/framework/db/queue/frontend>. Stack-appendices: stack-django.md, stack-frontend.md.
Commando's: zie config.json (lint, typecheck, test, test-selector).

## Documentatie-index
| Document | Trefwoorden |
|---|---|
| docs/adr/0001-... | ... |

## Wat de testsuite anders doet dan prod
| Test/CI | Prod | Gevolg voor de review |
|---|---|---|
| migraties uit in tests | migrate bij deploy | migraties zijn nooit "getest door CI" |

## Invarianten
### <domein 1, bv. finance-kern>
| Afspraak | Waar | Bewaker |
|---|---|---|
| ... | pad:regel | test X / CI / DB / reviewer |

### Schrijfgrenzen naar externe systemen
| Afspraak | Waar | Bewaker |

### Configuratie en achtergrondtaken
### Toegang en persoonsgegevens
### Tests en tooling
### Contracten (API, frontend, externe partijen)

## Bekende gaten en open beslissingen
- <gat>: <waarom open>, <wie beslist>

## Datakwaliteit-checks (read-only) voor een codebase-audit
- <query of shell-snippet>: <wat het aantoont>
```

## config.json

`fastcheck.sh` leest `$SUPERAUDIT_ROOT/config.json`. Zonder dat bestand detecteert hij de
stack (ruff/pytest/manage.py test/npm-scripts) en zegt wat hij aannam.

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

`{modules}`, `{files}`, `{app}` worden ingevuld vanuit de scope; `runner_prefix` gaat voor
elk commando dat in een container moet draaien. Laat een sleutel weg als de stap niet
bestaat; `fastcheck.sh` meldt dan "OVERGESLAGEN (niet geconfigureerd)".
