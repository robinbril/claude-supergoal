# Prod-pariteit: waar test en productie uit elkaar lopen

Een groene CI bewijst minder dan hij lijkt te bewijzen. De projectkaart noemt de concrete
afwijkingen van dit project; dit document zegt waar je naar zoekt en hoe je een wijziging
tegen de echte omgeving toetst zonder iets te schrijven.

## Wat je in de testsettings zoekt

| Afwijking (voorbeelden) | Gevolg voor de review |
|---|---|
| Migraties uitgeschakeld in tests (`MIGRATION_MODULES`, `--no-migrations`, schema uit modellen) | Een migratie kan in CI niet falen. Elke schema-operatie op een gevulde tabel apart beoordelen tegen echte data (hieronder). |
| `DEBUG`/dev-modus aan in CI | Code die op debug schakelt (foutpagina's, redirects, security-headers) heeft het prod-pad nooit gelopen. |
| Auth-lockout, rate-limiting, CSRF, 2FA uit | Login- en token-flows zien in tests geen lockout- of CSRF-gedrag. |
| Externe providers gepind op een andere branch dan prod (mock-provider, andere extractie-backend) | De prod-branch heeft een eigen suite nodig; een wijziging moet beide raken. |
| Feature-flags in tests altijd aan | Code kan in prod stil no-op'en. Check de flag-lezing op het smalste punt. |
| Signals/hooks/receivers gewist in tests | Een test die slaagt zonder receivers zegt niets over het gedrag met receivers. |
| `on_commit`-callbacks die in de test-transactie nooit vuren | Side-effects na commit (mail, jobs, webhooks) zijn in tests onzichtbaar tenzij expliciet gevangen. |
| Lint advisory (`allow_failure`, `continue-on-error`) | Lint-fouten blokkeren niets; nieuwe zijn een P3, bestaande niet. |
| Vaste sleutels/secrets in testsettings | Nieuwe versleutelde velden: check dat de sleutel-afleiding niet aan de testwaarde hangt. |

## Migraties beoordelen tegen echte data

Voor elke migratie in de diff, in deze volgorde:

1. **Wat staat er nu in de kolom/tabel?** Lees-only, via de app-shell in de container of een
   database-client: `count(*)` waar de kolom null is voor een nieuwe not-null;
   `GROUP BY <kolom> HAVING count(*) > 1` voor een nieuwe unique; rijen die een nieuwe
   check-constraint schenden. Nooit schrijven; geen `UPDATE`, geen `migrate` op een prod-URL.
2. **Laat de SQL zien** (`sqlmigrate`, `prisma migrate diff`, `alembic upgrade --sql`, ...).
   Let op `SET NOT NULL` zonder default, `ADD CONSTRAINT ... UNIQUE`, `DROP COLUMN` op een
   kolom die oude code nog leest, `CREATE INDEX` zonder `CONCURRENTLY` op een grote tabel.
3. **Deploy-volgorde**: gaan web en workers gelijktijdig over? Een `RemoveField` breekt de
   oude worker tot die herstart is; een not-null zonder default breekt de oude web tot de
   migratie klaar is. Op gevulde tabellen is de norm: nullable toevoegen, backfill,
   not-null; kolom pas verwijderen in de release ná de code die hem niet meer leest.
4. **Data-migraties**: idempotent, met reverse (of expliciet `noop`), via de historische
   modellen (niet de echte, die hebben al het nieuwe schema), gebatcht op grote tabellen,
   niet in één transactie met een schema-wijziging als de database dat niet aankan.
5. **Backfill die een business-regel kopieert** uit een service: drift op het moment van
   migreren. Check gelijkheid met de service.
6. **Meegelifte wijzigingen** in een gegenereerde migratie: welke `AlterField`s veranderen
   echt iets (type, null, lengte omlaag, choices die bestaande waarden uitsluiten)?

## De echte omgeving lezen zonder iets te raken

- App-shell in de container, read-only ORM-queries, `EXPLAIN` op een nieuwe query met
  echte tabelgroottes.
- MCP-tools van het project die de lokale database lezen: bewijzen iets over de lokale
  data, niets over het externe systeem zelf. Voor het externe systeem alleen zijn eigen
  status-/leestools.
- Prod-settings: check bij nieuwe env-vars of ze een default hebben of dat de deploy faalt
  bij het ontbreken; zeg dat in het rapport.
- Routing/proxy: een nieuwe route buiten de prefixen die de reverse proxy doorgeeft, komt
  in prod nooit aan.

## Datakwaliteit-checks bij een codebase-audit

Bij een audit op pad (geen PR) hoort een read-only datascan die de code niet kan laten zien:

- Kolommen `null=True` die in de praktijk nooit null zijn (en andersom: not-null gevuld
  met `""`/`0` als "geen waarde").
- Dubbele relaties (zelfde extern id, KvK, e-mail) waar het domein uniciteit verwacht.
- Statussen die het model niet meer kent (enum verwijderd, rijen bleven).
- Records "verstuurd/geboekt" zonder het externe id dat daarbij hoort.
- Rijen die buiten een boekhoudkundige of tijdsgrens vallen maar ergens toch meetellen.
- Datums zonder tijdzone in tijdzone-bewuste kolommen.

Rapporteer met de query en het aantal, nooit met een voorstel om data te "fixen" zonder
eigenaar: datacorrectie is een beslissing, geen PR.
