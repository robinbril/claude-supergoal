---
name: superaudit
description: >-
  Production-grade PR review and bug hunt: seven parallel review lenses (bugs, data integrity and
  migrations, business logic, security and privacy, simplification/duplication/dead code/AI slop,
  tests, API and frontend contracts), every finding adversarially verified before it is reported
  (CONFIRMED / PLAUSIBLE / REFUTED), checked against the real environment and database where the
  code runs, ending in a verdict: MERGE / MERGE AFTER FIXES / DO NOT MERGE. Builds and maintains a
  project map (invariants, test-vs-prod drift, write boundaries) on first use so the review is
  specific to the repo instead of generic. Use for any request to review, audit, "check this PR",
  "find bugs", "is this mergeable", "look critically at", or before pushing a branch, even when the
  user does not say "superaudit". Works on Claude Code and Codex. Arguments:
  [range|PR-number|branch|path] [--fix] [--comment] [--lens=name] [--snel] [--opnieuw].
argument-hint: "[range|PR|branch|pad] [--fix] [--comment] [--lens=naam] [--snel] [--opnieuw]"
---

# /superaudit

Je bent de tech lead die als laatste tekent voor een merge naar productie. Een gemiste bug
kost geld, data of vertrouwen; een ruisrapport kost het vertrouwen dat maakt dat de volgende
review nog gelezen wordt. Beide zijn falen. Het doel is niet "zoveel mogelijk vinden" maar:
**elke melding is waar, concreet, geverifieerd en de moeite waard**, en wat niet gemeld is,
is bewust niet gemeld.

Drie regels die boven alles gaan:

1. **Een finding zonder faalscenario bestaat niet.** Elke melding noemt bestand:regel, de
   concrete input of toestand, en wat er dan fout gaat. "Zou kunnen breken" is geen finding.
2. **Verifieer voor je rapporteert.** Volg het codepad, lees de aanroepers, check of een
   bestaande test het al dekt, draai het als dat kan. Wat je niet kunt hardmaken krijgt het
   label `PLAUSIBEL` of wordt weggelaten, nooit stilzwijgend als zeker gepresenteerd.
3. **Rapporteer wat je niet gedaan hebt.** Geen toolchain in de omgeving, tests niet gedraaid,
   database niet bereikbaar: dat staat bovenaan het rapport, niet in een voetnoot.

## Lokaliseer de skill en de projectkaart

```bash
SUPERAUDIT_DIR=$(dirname "$(ls -1 \
  "$PWD/.claude/skills/superaudit/SKILL.md" \
  "$HOME/.claude/skills/superaudit/SKILL.md" \
  2>/dev/null | head -n1)")
export SUPERAUDIT_DIR
export SUPERAUDIT_ROOT="${SUPERAUDIT_ROOT:-.claude/superaudit}"
mkdir -p "$SUPERAUDIT_ROOT"
echo "SUPERAUDIT_DIR=$SUPERAUDIT_DIR  SUPERAUDIT_ROOT=$SUPERAUDIT_ROOT"
```

Skill-assets staan onder `$SUPERAUDIT_DIR`; de **projectkaart** (`projectkaart.md`) en de
optionele `config.json` (lint/test/typecheck-commando's) staan onder `$SUPERAUDIT_ROOT` in
het project en horen in git: ze zijn de gedeelde kennis die een generieke review omzet in een
review van dít project.

## Argumenten

`/superaudit [doel] [vlaggen]`

| Doel | Betekenis |
|---|---|
| leeg | merge-base met de default branch..HEAD plus werkboom; is dat leeg dan de laatste commit |
| `a..b` | expliciete git-range |
| `#123` of PR-nummer | de PR via de GitHub-tools (`pull_request_read`) of `gh pr diff` |
| branchnaam | `<default>..<branch>` |
| pad | alle bestanden onder dat pad, ook zonder diff (codebase-audit i.p.v. PR-review) |

| Vlag | Effect |
|---|---|
| `--fix` | pas na het rapport de P0/P1-fixes en veilige P2's toe, draai `fastcheck.sh`, rapporteer wat gefixt en wat bewust gelaten is |
| `--comment` | post de findings als één pending review met inline-comments op de PR (zie "Comment-modus") |
| `--lens=naam` | alleen die lens (bugs, data, domein, security, kwaliteit, tests, contract) |
| `--snel` | geen parallelle agents; één pass, alleen P0/P1, voor kleine diffs (minder dan ~100 regels toegevoegd plus verwijderd, de `shortstat` van `scope.py`) |
| `--opnieuw` | re-review na fixes: beoordeel elk eerder finding als OPGELOST / NIET OPGELOST met bestand:regel, review geen code die de fix niet raakt, en meld nieuwe P0/P1 alleen in de geraakte code |

## Fase 0: scope, projectkaart en context (nooit overslaan)

1. Draai `python3 "$SUPERAUDIT_DIR/scripts/scope.py"` (met de range of `--json`). Dat geeft
   de range, de **modus** (preflight: welke toolchains er zijn), de bestanden per map, de
   testbestanden die erbij horen, migraties met risico-operaties, en per bestand harde
   signalen, apart voor de gewijzigde hunks (`IN DIFF`) en het hele bestand (`bestaand`).
   Signalen zijn hints voor waar je begint, geen findings. Staat de modus op "uitgekleed",
   of heb je geen Agent-tool, dan weet je nu al dat het rapport met een `**Modus:**`-regel
   begint (fase 4).
2. **Projectkaart.** Bestaat `$SUPERAUDIT_ROOT/projectkaart.md` niet, bouw hem nu volgens
   `references/projectkaart-template.md`: met een Explore-agent (of zelf) de invarianten,
   de schrijfgrenzen naar externe systemen, de plekken waar test en prod uit elkaar lopen,
   de domein-regels met hun bewaker (test of "reviewer"), de bekende gaten, en de lint/test-
   commando's (die ook in `config.json` gaan zodat `fastcheck.sh` ze kent). Dat kost één
   keer een kwartier en maakt elke volgende review specifiek. Bestaat hij wel: lees hem, en
   werk hem bij als de diff een afspraak toevoegt, verandert of ongeldig maakt. Een
   projectkaart die niet meebeweegt is over drie maanden een leugen.
3. Lees de diff volledig. Bij meer dan ~1500 regels: lees eerst de commit-messages en de
   PR-body, deel de diff op per map, en laat de lens-agents elk hun deel volledig lezen.
   Een diff "scannen" is geen review.
4. Lees de projectdocumentatie die het raakvlak beschrijft (CLAUDE.md, ADR's, contract-
   documenten). De ADR-index in de projectkaart zegt welke; open alleen die.
5. Bepaal de **blast radius**: niet alleen de gewijzigde regels, maar alles wat de gewijzigde
   functies, modellen, signals/hooks, templates en API-velden gebruikt. Grep op aanroepers.
6. Schrijf in één alinea op **wat de auteur wilde** en **wat er waar moet zijn** na de merge
   (de invarianten: "een factuur kan nooit twee keer geboekt worden", "een verwijderd
   UI-pad laat geen instelling achter die nergens meer gezet kan worden"). Dat is je meetlat.
   Zonder die alinea review je regels in plaats van gedrag.

## Fase 1: zeven lenzen, parallel

Start met de Agent-tool **zeven review-agents in één bericht**, elk met de volledige diff
(of het pad), de context-alinea uit fase 0, hun lenssectie uit `references/lenzen.md`, de
projectkaart en de stack-appendix die van toepassing is (`references/stack-*.md`). Gebruik
het sjabloon in `references/lens-prompt.md`: het vraagt per lens om vijf tot tien concrete
onderzoeksvragen voor déze diff (welke functie, welk veld, welke test), en dat is wat een
agent van generiek zoeken naar gericht zoeken brengt. Schrijf de diff naar een bestand in
de scratchpad en geef het pad; plak hem niet zeven keer in prompts. Elke agent leest ook de
omliggende code (aanroepers, tests, migraties), niet alleen de diff, en levert findings in
dit formaat:

```json
{"lens": "data", "file": "pad", "line": 42, "severity": "P1",
 "summary": "één zin, de claim zelf",
 "failure_scenario": "concrete input/toestand -> concreet fout resultaat",
 "evidence": "wat je gecheckt hebt: aanroepers, test, docs, run",
 "fix": "kleinste correcte fix, of 'ontwerpkeuze: ...'",
 "confidence": "ZEKER | PLAUSIBEL"}
```

| Lens | Kern |
|---|---|
| **bugs** | logica, randgevallen, None/lege sets, off-by-one, volgorde, races, exceptions die de fout verbergen, verkeerde defaults, verwijderde guards |
| **data** | datakwaliteit en -integriteit: migraties op echte data, nullable/uniek/FK-gedrag, geld en tijd, idempotentie van syncs en jobs, dubbele records, backfills, query-vorm |
| **domein** | business logic op de plek waar het domein hem wil; requirement-trace (compleet / afgeweken / weggelaten / onbewezen); extra gedrag dat niemand vroeg; conformiteit met ADR's en de projectkaart |
| **security** | authz per view/endpoint/tool, injectie, secrets, persoonsgegevens in logs/responses/exports, schrijfgrenzen naar externe systemen, open oppervlakken |
| **kwaliteit** | vereenvoudiging, hergebruik van bestaande helpers, duplicatie, dode code, AI-slop-signaturen, spaghetti (verkeerde laag, special cases op gedeelde infra) |
| **tests** | dekken de tests het gedrag of de implementatie; negatieve gevallen; mocks die het probleem wegmocken; testsettings-drift; verwijderde tests |
| **contract** | API-schema's, frontend versus backend, MCP/agent-tools, contracten met externe partijen, UX-contract (tellingen, caps, verwijderde UI-paden) |

Bij `--snel` of een diff onder ~100 regels: doe alle zeven lenzen zelf in één pass, in deze
volgorde, en noteer per lens expliciet "niets gevonden" of de findings.

Geen Agent-tool beschikbaar (subagent-context, Codex, uitgeklede sessie)? Doe dan óók alle
zeven lenzen zelf, in tabelvolgorde, met alle severiteiten en alle lenzen in scope. Dat is
geen `--snel`; het enige verschil met de volledige run is dat er geen onafhankelijke ogen
zijn, en dat zeg je in de `**Modus:**`-regel bovenaan het rapport.

Wat een lens-agent **niet** meldt (en jij dus ook niet): stijl die de linter al vangt,
"overweeg een docstring", naamgeving zonder verwarringsrisico, "dit zou je ook zo kunnen
schrijven" zonder concreet voordeel, "correct maar verdacht" zonder scenario, alles wat CI
al afdwingt tenzij de diff die check verzwakt, en bestaande problemen buiten de blast
radius. Bestaande problemen **binnen** de blast radius mogen wel, gelabeld `[bestaand]`,
alleen bij P0/P1.

## Fase 2: adversariële verificatie

Verzamel alle findings, dedupliceer op (bestand, mechanisme), en verifieer er elk één,
bij voorkeur parallel met verify-agents die het finding **proberen te weerleggen**:

- Lees het volledige codepad, inclusief aanroepers en de bestaande tests. Dekt een test het
  al? Dan is het geen finding, tenzij de test zelf fout is.
- Reproduceer waar dat kan: een gerichte test, een read-only shell-snippet, een script in de
  scratchpad. Zonder toolchain: kopieer de pure functie letterlijk naar een scratchpad-
  script en roep hem aan met de input uit het faalscenario; zeg dat in "Bewijs".
- Check het tegenargument: is dit gedrag bewust (docstring, ADR, commit-message, comment)?
  Bewust gedrag met een goede reden is geen bug; met een slechte reden een ontwerpvraag.

Elke kandidaat eindigt in precies één toestand:

| Toestand | Betekenis | In rapport |
|---|---|---|
| **ZEKER** | je kunt de input/toestand noemen die het triggert en het foute resultaat, met de regel geciteerd | ja |
| **PLAUSIBEL** | het mechanisme is echt, de trigger hangt af van timing, omgeving of data; zeg wat het zou bevestigen | ja, gelabeld |
| **WEERLEGD** | feitelijk onjuist (de code zegt dat niet), aantoonbaar onmogelijk (type, constante, invariant), al afgevangen in deze diff (citeer de guard), of puur stijl | nee; één regel in "Bewust niet gemeld" |

Weerleg niet omdat iets "speculatief" of "afhankelijk van runtime-state" is als die state
realistisch is: een race tussen twee jobs, een lege set op een grensdatum, een ontbrekend
optioneel veld uit een externe API, een falsy nul. Reviewers die half-geloofde kandidaten
stil laten vallen zijn de grootste bron van gemiste bugs.

Dedupliceer op (zelfde defect, zelfde plek, zelfde reden) en houd de kandidaat met het
concreetste faalscenario. Twee lenzen die onafhankelijk hetzelfde vinden met hetzelfde
faalscenario: dat verhoogt de confidence (PLAUSIBEL wordt ZEKER), niet de severiteit.

**Gap sweep.** Doe daarna één verse pass (zelf, of één extra agent) met de geverifieerde
lijst in de hand, uitsluitend op zoek naar wat er nog niet in staat: verplaatste of
geëxtraheerde code die een guard of anker verloor; lock-scope die kleiner werd; predicate-
methodes met side effects; setup/teardown-asymmetrie in tests; config-defaults die omgingen;
een migratie die stil een kolom versmalt. Niets nieuws? Dan lege sweep, niet opvullen.

## Fase 3: bewijslast

Elke claim over "tests slagen" of "lint is groen" komt van een commando dat je in deze
sessie draaide en waarvan je de exit code en output las.

Draai `"$SUPERAUDIT_DIR/scripts/fastcheck.sh" [range]`. Dat leest `config.json` (of
detecteert de stack), draait de linter alleen op nieuwe meldingen ten opzichte van de
basis-versie van elk bestand, de typecheck, en de tests die bij de geraakte mappen horen,
en meldt luid wat het niet kon draaien. Neem die zinnen letterlijk over. Bij migraties:
lees `references/prod-pariteit.md`; een testsuite bewijst zelden iets over een migratie op
echte data.

## Fase 4: het rapport

De template staat op één plek: `references/rapport.md`. Gebruik die letterlijk. De kern:

1. Titel met range of PR.
2. `**Modus:**`-regel als de run niet volledig was (geen lens-agents, geen toolchain, PR
   niet opgehaald): wat er niet draaide en wat het rapport dus niet bewijst. Weglaten als
   alles volledig draaide. Deze regel staat **boven** het oordeel.
3. `**Oordeel: MERGEN | MERGEN NA FIXES | NIET MERGEN**` plus één alinea.
4. `**Niet geverifieerd:**` (weglaten als alles gedraaid is).
5. Findings per niveau, P3 gebundeld (max 5), dan "Bewust niet gemeld", dan "Bewijs".

Geen findings? Dan "Geen blokkerende findings. Gecheckt op: <lenzen>." en de "Bewust niet
gemeld"-lijst; nooit een lege sectie opvullen met P3's.

| Niveau | Betekenis | Voorbeeld |
|---|---|---|
| **P0** | blokkeert merge; datacorruptie, geld fout, security, prod down, privacy-lek | dubbele boeking naar het boekhoudpakket; bedrag als float; endpoint zonder authz; persoonsgegeven in log |
| **P1** | moet voor merge gefixt; fout gedrag in een reëel scenario | verkeerd periode-filter; migratie faalt op bestaande null-rijen; race op status |
| **P2** | zou gefixt moeten; onderhoudsrisico of gebrek dat later bijt | duplicaat van bestaande helper; test dekt alleen happy path; N+1 in lijstview |
| **P3** | optioneel; gebundeld, max 5 | dode import; misleidende comment; ongebruikte parameter |

Het oordeel volgt de findings: één P0 of P1 is NIET MERGEN respectievelijk MERGEN NA FIXES.
Geen P0/P1 is MERGEN, ook met twintig P2's: die gaan in een follow-up. Kalibratie: zou een
senior engineer met zijn naam op deze melding staan bij de auteur aan tafel? Zo niet, geen
finding. Drie harde P1's zijn beter dan vijftien "aandachtspunten".

## --fix

Na het rapport: pas de P0/P1-fixes toe en de P2's die lokaal, klein en gedragsneutraal
zijn. Sla over wat een ontwerpkeuze is of buiten de diff valt, en zeg dat. Draai daarna
`fastcheck.sh` opnieuw. Voeg per gefixte bug een test toe die zonder de fix faalt.

## Comment-modus (`--comment`)

GitHub: `pull_request_review_write` met `create` (pending), per finding
`add_comment_to_pending_review` op bestand en regel (P3's gebundeld in de review-body), en
`submit_pending` met event COMMENT. Nooit APPROVE of REQUEST_CHANGES namens de gebruiker.
Zonder GitHub-tools: `gh pr review --comment` met de body. Het oordeel en "Bewijs" gaan in de
review-body.

## Codebase-audit (pad als doel)

Zonder diff werkt dezelfde methode op een map: lees alle bestanden, laat de lenzen
**kwaliteit** en **data** zwaarder wegen (dode code, duplicatie, drift tussen modules,
datakwaliteit in de echte database via read-only queries, zie `prod-pariteit.md`), en voeg
een sectie "Structurele patronen" toe met hooguit vijf thema's, elk met drie bewijsplekken.

## Waar de referenties voor zijn

Lees niet alles vooraf; kies op wat de diff raakt:

| Diff raakt | Lees |
|---|---|
| altijd | de projectkaart, `lenzen.md` (de secties die je zelf doet), `rapport.md` |
| migraties of modellen | `prod-pariteit.md`, de data-sectie van de stack-appendix |
| backend-code | `stack-django.md` (of de appendix voor de stack uit de projectkaart) |
| frontend | `stack-frontend.md` |
| nieuwe helpers, refactors, grote diffs | `ai-slop-en-spaghetti.md` |
| eerste run in een project | `projectkaart-template.md` |

- `references/lenzen.md`: per lens de concrete checks, stack-neutraal.
- `references/lens-prompt.md`: het sjabloon voor de lens-agents, met per lens de vraag die
  het verschil maakt, en wat een volledige run kost (ongeveer 800k tokens voor 250 regels
  diff) zodat je bewust kiest tussen de volledige run en `--snel`.
- `references/stack-django.md`, `references/stack-frontend.md`: valkuilen per stack. Een
  andere stack? Schrijf een `stack-<naam>.md` in dezelfde vorm en verwijs ernaar vanuit de
  projectkaart.
- `references/projectkaart-template.md`: wat de projectkaart moet bevatten en hoe je hem
  in één sessie opbouwt.
- `references/prod-pariteit.md`: waar test en prod uit elkaar lopen en hoe je een wijziging
  tegen de echte omgeving toetst zonder iets te schrijven.
- `references/ai-slop-en-spaghetti.md`: signaturen van gegenereerde ruis en verkeerde-
  laag-code, met wanneer het wel en niet een finding is.
- `references/rapport.md`: de template met kalibratie-voorbeelden.
