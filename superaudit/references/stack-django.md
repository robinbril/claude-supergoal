# Stack appendix: Django, Postgres, Celery, DRF

Pitfalls that recur in a Django backend. The lens names the mechanism; the project map says
where it lives in this project.

## Transactions and side effects

- Do not catch an exception *inside* `transaction.atomic()` without a nested `atomic`: the
  transaction is broken afterwards (`TransactionManagementError`).
- Network, mail, Celery `delay()`, and file operations belong outside the transaction or in
  `transaction.on_commit`; `on_commit` is discarded on rollback and, in `TestCase`, only
  fires with `captureOnCommitCallbacks`.
- `select_for_update()` only inside `atomic`; not on nullable joins without `of=`.
- `get_or_create`/`update_or_create` are atomic only with a unique constraint in the
  database.
- `update()`, `bulk_create()`, `bulk_update()` bypass `save()`, signals, and `auto_now`.

## Signals

- Network or external writes in `pre_save`/`post_save` block the local save and leave
  external effects behind on rollback. New logic belongs in a service, not in a signal.
- Tests that disconnect receivers must restore them (`setUpClass`/`tearDownClass` or
  `addClassCleanup`), otherwise the suite is order-dependent and a green test proves nothing
  about the behavior with receivers.

## Querysets

- `obj.fk.id` -> `obj.fk_id`; `len(qs)`/`bool(qs)` -> `count()`/`exists()`.
- `SerializerMethodField` with `.all()` on a relation is an N+1 unless the viewset prefetches
  exactly that relation.
- `distinct()` + `order_by()` on a related field yields duplicates; `values()` +
  `annotate()`: the ordering determines the grouping.
- `iterator()` ignores `prefetch_related` without `chunk_size`.
- Guarded querysets (scoping on tenant/division, accounting boundaries): a test that guards
  the service layer does not see a direct `Model.objects` in a view or viewset.

## Migrations

- `makemigrations --check` per app when a vendored package produces global noise.
- `RunPython` with `apps.get_model` and `reverse_code`; schema and data separated;
  `atomic=False` plus batches for large backfills.
- Not-null on a populated table in three steps; `AddIndexConcurrently` on large tables;
  constraints first `NOT VALID` then validate; rename/drop across two releases.
- `sqlmigrate` is the ground truth; a generated migration can carry along `AlterField`s that
  change something real.
- Postgres triggers (append-only, audit) exist in prod but not in a test suite that skips
  migrations.

## Money and time

- `DecimalField`, `Decimal(str(x))` at the boundary, `quantize` to the precision of the
  domain; `float()` only on the last line before a JSON or chart response.
- `USE_TZ=True` with `date.today()`/`datetime.now()` is server-local (the container usually
  runs UTC): use `timezone.now()`/`timezone.localdate()` for storage and day boundaries.
- Invoice date is not an accounting period; use the project's period helpers.

## Celery

- Pass ids, not objects; enqueue via `on_commit`; tasks idempotent (especially with
  `acks_late`); never `.get()` inside a task; `autoretry_for` with backoff but never on an
  auth error that a retry cannot resolve; time limits.
- Beat changes are policy changes: the on/off switch belongs in the task itself (reads a
  setting, no-ops with a log line), not in a UI that never touches the beat.
- Overlapping runs without a lock: a beat that writes needs a lock or an idempotent upsert.

## DRF and access

- Default permission classes plus a fail-closed endpoint registry if the project has one; an
  endpoint that is not registered is off (report it if the author expected it to be on).
- Deliberately open endpoints (`AllowAny`, `authentication_classes = []`): each with a
  docstring and a reason; changes there are P0 territory.
- `ReadOnlyModelViewSet` is hard read-only regardless of the router; writes go through the
  service layer.
- Template views: the house pattern (`LoginRequiredMixin` + `UserPassesTestMixin`, or
  `admin_site.admin_view`) on every new view; `admin.site.each_context()` does not
  authenticate.
- Schemathesis/OpenAPI fuzzing catches schema drift; a serializer change that pulls the
  schema and the response apart fails there.

## Test settings

Typical deviations to record in the project map: `MIGRATION_MODULES` off, `DEBUG=1` in CI,
axes/lockout off, MD5 hasher, mock provider for external AI/extraction, fixed Fernet key,
feature flags always on, receivers disconnected.
