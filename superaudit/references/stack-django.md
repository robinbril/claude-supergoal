# Stack-appendix: Django, Postgres, Celery, DRF

Valkuilen die in een Django-backend telkens terugkomen. De lens noemt het mechanisme; de
projectkaart zegt waar het in dit project zit.

## Transacties en side-effects

- Geen exception vangen bínnen `transaction.atomic()` zonder een geneste `atomic`: de
  transactie is daarna kapot (`TransactionManagementError`).
- Netwerk, mail, Celery-`delay()` en bestandsoperaties horen buiten de transactie of in
  `transaction.on_commit`; `on_commit` wordt bij rollback weggegooid en vuurt in `TestCase`
  alleen met `captureOnCommitCallbacks`.
- `select_for_update()` alleen binnen `atomic`; niet op nullable joins zonder `of=`.
- `get_or_create`/`update_or_create` zijn alleen atomair met een unique constraint in de
  database.
- `update()`, `bulk_create()`, `bulk_update()` omzeilen `save()`, signals en `auto_now`.

## Signals

- Netwerk of externe writes in `pre_save`/`post_save` blokkeren de lokale save en laten bij
  rollback externe effecten achter. Nieuwe logica hoort in een service, niet in een signal.
- Tests die receivers wissen moeten ze herstellen (`setUpClass`/`tearDownClass` of
  `addClassCleanup`), anders is de suite volgorde-afhankelijk en bewijst een groene test
  niets over het gedrag met receivers.

## Querysets

- `obj.fk.id` -> `obj.fk_id`; `len(qs)`/`bool(qs)` -> `count()`/`exists()`.
- `SerializerMethodField` met `.all()` op een relatie is een N+1 tenzij de viewset precies
  die relatie prefetcht.
- `distinct()` + `order_by()` op een gerelateerd veld levert duplicaten; `values()` +
  `annotate()`: volgorde bepaalt de groepering.
- `iterator()` negeert `prefetch_related` zonder `chunk_size`.
- Guarded querysets (scoping op tenant/divisie, boekhoudkundige grenzen): een test die de
  service-laag bewaakt ziet een rechtstreekse `Model.objects` in een view of viewset niet.

## Migraties

- `makemigrations --check` per app als een vendored pakket globaal ruis geeft.
- `RunPython` met `apps.get_model` en `reverse_code`; schema en data gescheiden;
  `atomic=False` plus batches voor grote backfills.
- Not-null op een gevulde tabel in drie stappen; `AddIndexConcurrently` op grote tabellen;
  constraints eerst `NOT VALID` dan valideren; rename/drop in twee releases.
- `sqlmigrate` is de grondwaarheid; een gegenereerde migratie kan `AlterField`s meeliften
  die iets echts veranderen.
- Postgres-triggers (append-only, audit) bestaan in prod maar niet in een testsuite die
  migraties overslaat.

## Geld en tijd

- `DecimalField`, `Decimal(str(x))` aan de grens, `quantize` op de precisie van het domein;
  `float()` alleen op de laatste regel voor een JSON- of chart-respons.
- `USE_TZ=True` met `date.today()`/`datetime.now()` is server-lokaal (container draait
  meestal UTC): gebruik `timezone.now()`/`timezone.localdate()` voor opslag en daggrenzen.
- Factuurdatum is geen boekperiode; gebruik de periode-helpers van het project.

## Celery

- Ids doorgeven, geen objecten; enqueue via `on_commit`; taken idempotent (zeker met
  `acks_late`); nooit `.get()` in een taak; `autoretry_for` met backoff maar nooit op een
  auth-fout die een retry niet oplost; time limits.
- Beat-wijzigingen zijn beleidswijzigingen: de aan/uit-schakelaar hoort in de taak zelf
  (leest een setting, no-op't met logregel), niet in een UI die de beat niet raakt.
- Overlappende runs zonder lock: een beat die schrijft heeft een lock of idempotente upsert.

## DRF en toegang

- Default permission-classes plus een fail-closed endpoint-registry als het project dat
  heeft; een endpoint dat niet geregistreerd is, is uit (meld het als de auteur hem aan
  verwachtte).
- Bewust open endpoints (`AllowAny`, `authentication_classes = []`): elk met docstring en
  reden; wijzigingen daar zijn P0-gebied.
- `ReadOnlyModelViewSet` is hard read-only ongeacht de router; writes via de service-laag.
- Template-views: het huispatroon (`LoginRequiredMixin` + `UserPassesTestMixin`, of
  `admin_site.admin_view`) op elke nieuwe view; `admin.site.each_context()` authenticeert
  niet.
- Schemathesis/OpenAPI-fuzz vangt schema-drift; een serializer-wijziging die schema en
  respons uit elkaar trekt valt daar om.

## Testsettings

Typische afwijkingen om in de projectkaart te zetten: `MIGRATION_MODULES` uit, `DEBUG=1`
in CI, axes/lockout uit, MD5-hasher, mock-provider voor externe AI/extractie, vaste Fernet-
sleutel, feature-flags altijd aan, receivers gewist.
