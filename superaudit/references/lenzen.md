# De zeven lenzen: concrete checks per lens (stack-neutraal)

Geef elke lens-agent zijn sectie hieronder mee, plus de diff, de context-alinea uit fase 0,
de projectkaart en de stack-appendix (`stack-django.md`, `stack-frontend.md`, of een eigen
`stack-<naam>.md`). Elke lens levert maximaal 8 kandidaten **vóór verificatie**, elk met een
faalscenario; wat geen faalscenario heeft, komt niet in de lijst. (Het plafond van vijf
gebundelde P3's in het rapport geldt ná verificatie, over alle lenzen samen.)

Drie leesregels voor alle lenzen:

- **Lees de omsluitende functie van elke hunk**, niet alleen de gewijzigde regels. Een bug
  in een ongewijzigde regel van een geraakte functie is in scope.
- **Audit wat verwijderd is.** Voor elke verwijderde of vervangen regel: welke invariant of
  guard handhaafde die, en waar wordt die opnieuw afgedwongen? Niet gevonden: kandidaat.
  Een verwijderde test telt ook.
- **Volg de aanroepers.** Grep elke gewijzigde functie, property, serializer-veld en
  template-variabele. Nieuwe preconditie, andere return-vorm, nieuwe exception, andere
  volgorde: check elke call site, en of een parallelle wijziging in dezelfde PR een aanroep
  onveilig maakt.

Verificatie-bias: `PLAUSIBEL` is de default voor realistische runtime-toestanden (race,
lege set, ontbrekend optioneel veld, koude cache, grensdatum); weerleg alleen met bewijs uit
de code.

---

## bugs

Vraag per regel: **welke input, toestand, timing of omgeving maakt deze regel fout?**

- Omgekeerde of onvolledige condities; precedentie; `if x:` waar `0`, `""`, een leeg
  object of een lege lijst een geldige waarde is (falsy-zero).
- Off-by-one op periode- en datumgrenzen (`<` vs `<=`, inclusieve einddatum, weekgrens).
- None/undefined-paden: nullable relaties, `.first()`/`.find()` die niets geeft, een
  setting die ontbreekt, `get()` op een dict uit een externe API.
- Verkeerde variabele na copy-paste (rate A waar rate B bedoeld is; ids waar codes horen).
- Exceptions die de fout verbergen: een brede `except` die een programmeerfout als
  "externe fout" rapporteert; `return None` in een except waar de aanroeper succes afleidt.
- Volgorde en timing: waarde gelezen vóór hij gezet is; hook die vuurt vóór commit; job die
  een id krijgt dat nog niet gecommit is; status gezet en daarna pas gevalideerd.
- "Wat als het twee keer draait?" Geplande jobs zonder lock, webhooks zonder idempotency,
  `save()` in een retry-pad, nummer-toekenning `max+1` zonder lock.
- "Wat als de externe call halverwege faalt?" Extern gelukt maar lokaal niet opgeslagen (of
  andersom); mail verstuurd en daarna rollback.
- Taal-valkuilen: mutable default-argumenten, late-binding closures, `is` vs `==`, float-
  gelijkheid, defaults die één keer geëvalueerd worden, iteratie tijdens mutatie, `zip`
  op ongelijke lengtes, `await` vergeten, promise zonder catch.
- Wrappers/adapters/decorators: routeren ze naar het gewrapte object of terug via een
  registry/global (recursie)? Worden alle methodes doorgegeven die aanroepers gebruiken?

## data

Datakwaliteit en -integriteit, gemeten aan de echte database (zie `prod-pariteit.md`).

- Elke modelwijziging heeft zijn migratie in dezelfde PR; risico-operaties beoordeeld
  tegen echte data en de deploy-volgorde; data-migraties idempotent met reverse.
- Nieuw veld: null/blank/default consistent met hoe de code hem leest; `""` vs `None` niet
  door elkaar; enum met bewuste default; relaties met bewuste on-delete; uniciteit die het
  domein eist ook in het schema (anders racet `get_or_create`).
- Geld: decimale types, coercion via string, expliciete afronding op de juiste precisie,
  tekenconventies van het boekhoudpakket gerespecteerd, nooit `float` in wat opgeslagen of
  geboekt wordt.
- Tijd: tijdzone-bewuste now/today als het opgeslagen of als daggrens gebruikt wordt;
  periode-toerekening via de periode-helpers van het project, niet via de factuurdatum.
- Syncs: upsert op het externe unieke id; bij herhaling geen dubbele rijen; verwijderd aan
  de bron -> wat gebeurt lokaal; partial writes zonder transactie; side-effects op commit.
- Bulk-paden omzeilen model-hooks en validatie; klopt dat met wat in de hooks leeft?
- Query-vorm: N+1 (query in loop, `obj.fk.id`, serializer-veld met `.all()`), ongebonden
  lijsten zonder paginatie, `len()`/`bool()` op querysets, `distinct`+`order_by` op
  relaties, iterators zonder chunking.
- Append-only of trigger-bewaakte tabellen: geen `update()`/`delete()` in nieuwe code; de
  trigger vangt het in prod, niet in tests zonder migraties.

## domein

Doet de code wat het domein zegt, op de plek waar het domein het wil?

- Toets elke gewijzigde regel aan de invarianten in de projectkaart (verplichte
  querysets/filters, scoping, statussets die tellen, schrijfgrenzen, instelbare grenzen).
- Requirement-trace: wat de PR-beschrijving belooft is COMPLEET, AFGEWEKEN, WEGGELATEN of
  ONBEWEZEN; **extra** gedrag dat niemand vroeg is een regressie tot het bewust is.
- Status-machines: transities via de service-laag onder een lock; verboden paden niet via
  een "handige" admin-actie mogelijk.
- Hoogte: een `if klant == X` of `if type == Y` in gedeelde infra is een pleister; hoort
  de regel in een model-property, service, rule-engine of setting?
- Hardcoded grenzen (minimumbedrag, percentage, termijn) waar het project een instelbare
  setting of rule wil: P1.
- Comments en docs: klopt de claim in docstring, CLAUDE.md, ADR of contract nog na deze
  diff? Een diff die een documentzin onwaar maakt, neemt het document mee.
- Berekeningen die een externe bron spiegelen (Excel, oud pakket) met open beslispunten:
  een "verbetering" daar is een beslissing van de eigenaar, geen PR.

## security

Alleen concreet exploiteerbare of privacy-relevante findings, met aanvalspad. Geen
theoretische hardening, geen DoS, geen rate-limiting zonder gevolg.

Werk eerst de bestaande patronen van het project uit (permission-classes, mixins, wrappers,
scoping-helpers, encryptie) en vergelijk de diff daarmee; afwijking van het huispatroon is
de beste voorspeller.

- **Authz**: nieuwe view/endpoint/tool zonder het huispatroon; schrijfactie onder een
  read-permissie; object-level: kan gebruiker A het object van tenant B lezen via een id?
  Tenant-scoping ontbreekt op een nieuwe query.
- **Bewust open oppervlakken** (portals, webhooks, uploads met token in URL): elke wijziging
  daar is P0-gebied; tokens hebben expiry en scope; geen enumeratie via foutmeldingen.
- **Injectie**: raw SQL met interpolatie op niet-constante input; `mark_safe`/`v-html`/
  `innerHTML` op gebruikersdata; subprocess met shell; path traversal in upload-/document-
  paden; onveilige deserialisatie.
- **Secrets**: nieuwe key/token in code, settings met default, fixtures, migraties, tests,
  logregels; een secrets-baseline die groeit met iets wat geen placeholder is.
- **Persoonsgegevens**: identiteitsnummers, salaris, IBAN, geboortedatum, medische of
  screening-informatie in logs, `__str__`, admin-lijsten, API-responses buiten het doel,
  exports, mail, agent-tool-output, persistente frontend-state. Nieuw gevoelig veld zonder
  versleuteling; geen verwijderpad voor wat verwijderd moet kunnen.
- **Schrijfgrenzen**: elke nieuwe write naar een extern systeem buiten de plekken die de
  projectkaart noemt, ook via een helper (een AST-test ziet alleen directe calls).
- **Sessie/CSRF**: nieuwe `csrf_exempt`; lege authentication-classes zonder docstring;
  fetch die de CSRF-cookie omzeilt.
- **Externe calls**: host/protocol uit gebruikersinput (SSRF); TLS-verificatie uit;
  timeouts ontbreken (hangende worker).

Aannames tegen ruis: env-vars en CLI-flags zijn vertrouwd; UUID's zijn niet te raden;
moderne frontend-frameworks escapen standaard; client-side checks zijn geen security en
worden niet gemeld; een ontbrekende audit-log is geen kwetsbaarheid.

## kwaliteit

Vereenvoudiging, hergebruik, duplicatie, dode code, AI-slop en spaghetti; zie
`ai-slop-en-spaghetti.md`. Alleen gedragsneutrale verbeteringen; geen bugs zoeken.

- **Hergebruik**: grep de gedeelde helpers van het project (services, utils, adapters,
  factories) voordat je een nieuwe helper accepteert. Noem de bestaande.
- **Vereenvoudiging**: afleidbare state apart bijgehouden; copy-paste met kleine variatie;
  diepe nesting die een early return oplost; dode takken; boolean-parameters die gedrag
  vertakken. Noem de simpelere vorm.
- **Efficiëntie**: herhaalde I/O of query in een loop; onafhankelijke calls sequentieel;
  werk op een hot path dat cachebaar of prefetchbaar is. Label perf-claims gemeten of niet.
- **Hoogte**: special case op gedeelde infra; regel in view i.p.v. service; service die een
  request neemt; hook die werk doet.
- **Dode code**: definitie zonder aanroeper (let op dynamische dispatch: routes, registries,
  admin, job-namen als string, templates, tool-registries); parameter die niemand meegeeft;
  enum-waarde zonder gebruik; flag die altijd één kant op staat.
- **Bestandsgroei**: nieuwe verantwoordelijkheid in een bestand dat al te groot is hoort in
  een module ernaast.

Meld nooit: lange waarom-docstrings, bewust gedocumenteerde duplicatie, onderdrukkingen
mét reden, formatting die de formatter regelt.

## tests

Dekken de tests het **gedrag** dat de diff belooft, en falen ze als de code kapot is?

- Elke nieuwe tak, grens en foutpad heeft een test; rekenlogica heeft hand-uitgerekende
  asserts, niet een assert op wat de code toevallig teruggeeft.
- Negatieve gevallen: leeg, nul, None, grensdatum, dubbele input, tweede run
  (idempotentie), verkeerde rol, uitgeschakelde flag.
- Tests die de implementatie testen: `called_once_with` zonder resultaat-assert; mock van
  de functie onder test; mock op de verkeerde laag (mock op de externe grens, niet de
  service).
- Verwijderde of verzwakte tests: welke case dekten ze?
- Testsettings-drift (projectkaart): een test die alleen slaagt door zo'n afwijking is geen
  bewijs. Hooks gewist zonder herstel maakt de suite volgorde-afhankelijk.
- Coverage-vloeren: nieuwe code in een kritieke module zonder tests trekt hem eronder.
- Frontend: nieuwe adapter/vormvertaling heeft een unit-test; mock-implementaties blijven
  de interface satisfyen; typecheck lokaal groen als CI hem niet draait.
- Per ontbrekende test: noem de fout die hij zou vangen, anders geen finding. Score 9-10
  dataverlies/security, 7-8 business-regel, 5-6 randgeval; onder 5 niet melden.

## contract

Grenzen tussen componenten: API, frontend, MCP/agent-tools, externe partijen.

- **API**: veld verwijderd/hernoemd/type gewijzigd -> wie leest het (frontend-types,
  adapters, MCP-server, agent-tools, andere services)? Schema (OpenAPI) blijft in lijn;
  paginatie/filters consistent; endpoint geregistreerd waar het project dat eist; foutvorm
  consistent.
- **Frontend**: types en mocks mee; adapters puur; enum-waarden uit de backend, niet
  hardcoded; foutstaat zichtbaar; route-guards; proxy-prefixen kloppen met de reverse
  proxy; geen backend-kennis in componenten.
- **UX-contract**: een telling in een kop komt overeen met wat de gebruiker vanaf die plek
  kan bereiken; een cap zonder overloop-route terwijl de kop het totaal toont is een P2;
  comments die "de telling volgt de lijst" beloven moeten na een cap nog waar zijn; een
  verwijderd UI-pad laat geen instelling of actie achter die nergens meer gezet kan worden.
- **MCP/agent-tools**: tool per endpoint met dezelfde scoping als de API; read-only tenzij
  expliciet; output zonder persoonsgegevens buiten het doel.
- **Externe partijen**: het contractdocument is de bron; wijziging: document eerst, dan
  code, en de andere kant in de PR genoemd. Endpoints zonder contractdocument: aannames
  over stabiele velden zijn een open vraag in het rapport, niet weerlegd of zeker.
- **Templates (server-side)**: url-namen bestaan nog; context-variabelen die de view niet
  meer levert; admin-overrides die na een framework-upgrade nog matchen.
