---
name: supergoal
description: >-
  Plan and autonomously build a software task end-to-end, with verification the executor cannot
  fake: an independent evaluator re-proves every phase against repository ground truth and the
  running artifact, blind to the builder's self-report. Use for any non-trivial feature, refactor
  or redesign the user wants driven to completion without babysitting ("plan and ship X",
  "autonomous build", `/supergoal`). Dit is de zware variant (evaluator + council per fase);
  het token-zuinige alternatief voor hetzelfde doel is keten-loop. Plant via batch-grill-intake en recon,
  opent automatisch een interactieve HTML plan-pagina waarop je feedback geeft tot alles klopt, en draait
  daarna de hele keten in deze sessie door zonder een plak-commando. Works on Claude Code and Codex.
argument-hint: <beschrijf wat je wilt bouwen, fixen of verschepen>
---

# Supergoal

Je draait de Supergoal workflow. De taak van de gebruiker is:

$ARGUMENTS

**Het principe waar alles omheen gebouwd is: niks is klaar tot iets onafhankelijks het bewijst, tegen de oorspronkelijke opdracht, door de app echt te draaien.** Claude Code stopt standaard zodra de agent zegt dat hij klaar is; Supergoal stopt pas als een controleur die het werk niet zelf maakte het bewijst. Dit principe wordt hieronder één keer uitgewerkt in de drie rollen en geldt daarna overal zonder herhaling.

## De drie rollen

- **Generator** (de bouwer). Doet het werk van een fase. Levert het resultaat plus een ruwe bewijslijst: gedraaide commands met output en exit codes, gewijzigde bestanden, observaties van de draaiende app. Zegt zelf **niet** of het geslaagd is, gaat nooit op eigen houtje door.
- **Evaluator** (de onafhankelijke controleur). Een aparte agent met een schone lei. Leest de fase-eisen en **doet elke check zelf opnieuw**: commands herdraaien, bestandswijzigingen vaststellen, de app zelf aansturen, oordeel-eisen blind beoordelen. Geeft per eis een uitslag plus ACCEPT of REJECT voor de fase. REJECT start het herstel (3-strike, zie Uitvoering); pas bij ACCEPT sluit de fase.
- **Council** (de richtings-gate). Draait per fasegrens, alleen ná een ACCEPT. De evaluator bewijst dat de fase klopt; de council kijkt of het resultaat de juiste kant op stuurt. Default AUTO-APPROVE. Escaleert alleen wanneer alle drie tegelijk gelden: moeilijk omkeerbaar, meerdere geloofwaardige paden, buiten de bevestigde scope. Bij escalatie convoceert hij de `council`-skill (aanbeveling A, alternatieven B/C, bronnen) en wacht op `go`/`B`/`C`; zonder live input volgt hij A en logt `auto-A`. De council oordeelt nooit over correctheid en kan een ACCEPT niet overrulen. Volledige instructie: `prompts/council-gate.md`.

**Isolatie per host.** Claude Code (Task/Agent tool): evaluator als subagent met verse context, echte isolatie. Codex (geen subagent): evaluator als losse pass met de opdracht het generator-verhaal te negeren en alles vers vast te stellen; de herdraaide checks hangen niet van die context af.

### Model-routing per rol

Een lange run valt niet om door kosten maar door rate limits en een te zwakke judge. Route op rol waar de host het toelaat; is er één model, gebruik dat overal. **Plan zwaar, voer licht uit, en schaal de judge-kant nooit af.**

| Rol | Tier | Waarom |
|---|---|---|
| Planning (Stage 0-6) | het zwaarste beschikbaar, hoge effort | hier vallen de beslissingen die alles erna sturen |
| Retrieval-workers, mechanische recon | goedkoop en snel (haiku) | hoog volume, geen oordeel |
| Sufficient-context judge + adversarial prober | sterk | de context-gate; een zwakke judge laat gaten door |
| Generator spoor-specialisten | worker-tier (sonnet); sessiemodel alleen voor een kritiek of ambigue spoor | de scherpe specs uit de planfase dragen het oordeel al |
| Evaluator | sterk, bij voorkeur opus | de hele moat hangt op een scherpe onafhankelijke beoordelaar |
| Council | sessiemodel voor de triage; sterk voor een volle convocatie | triage is een goedkope go/escaleer-call |

### Dispatch-tiers (canoniek; overal waar "dispatch" valt, geldt dit blok)

1. **Parallelle subagents zijn de default** zodra een fase twee of meer scheidbare sporen heeft: een specialist per spoor, gratis, in één bericht gespawnd. Een fase met scheidbare sporen draait nooit als één sequentiële agent.
2. **Sequentieel** is alleen voor een atomaire fase of een host zonder subagent-tool.
3. **De Workflow-tool** is een aparte, zwaardere tier voor ongewoon grote swarms, alleen bij genoeg credits. Geen Workflow-tool beschikbaar: behandel het budget als zuinig.
4. **`/loop` of een scheduled task** vervangt de eenmalige run wanneer de taak terugkerend is ("elke dag", "blijf X doen") in plaats van bouw-tot-klaar.

## Wat "klaar" vereist

Geen vibes. Vertaal de lat naar criteria die een onafhankelijke partij kan natrekken: **elk criterium ja/nee-toetsbaar**, **elk criterium gelabeld met zijn validatieklasse**, en **elke fase die gedrag oplevert draagt minstens één `empirical` criterium** ("tests groen" bewijst geen gedrag; het draaiende artefact observeren wel).

| Klasse | Wat het bewijst | Hoe de evaluator het zelf herdraait |
|---|---|---|
| `tool-output` | Build, typecheck, lint, test, schema | Command opnieuw draaien, eigen exit code + patroon; nooit de gerapporteerde overnemen |
| `deliverable` | Bestand of feature bestaat echt | `bash .supergoal/repo-state.sh deliverable <baseline> "<path>"` tegen de working tree |
| `empirical` | Geobserveerd gedrag van het echte artefact | Zelf aansturen: preview MCP screenshot + DOM-assert (web), curl (API), binary draaien (CLI), usage-script (library), /e2e voor flows |
| `llm-judge` | Subjectieve kwaliteit (UX, copy, error-afhandeling) | Blind voor het generator-rapport beoordelen, met bewijs-citaties |
| `self-consistency` | Spreekt deze fase eerdere fasen tegen? | Criteria van eerdere fasen her-greppen op conflicten |

Markeer elk criterium met zijn klasse, bijv. `- [tool-output] Alle tests slagen.` `- [empirical] /login rendert en accepteert een geldige inlog (screenshot).`

## Hoe de run verloopt

0. **Context**: memory inladen, tools detecteren, lopende run hervatten.
1. **Intake**: de beslisboom afgrillen tot gedeeld begrip via `batch-grill-me`, de hele frontier per ronde.
2. **Recon**: info uit vier bronnen, met een genoeg-check plus een gaten-zoeker.
3. **Synthese**: risico's en afhankelijkheden uit de verzamelde info.
4. **Decompose**: onafhankelijk verifieerbare fasen, empirisch bewijs waar gedrag ontstaat.
5. **Specs**: per fase een werk-spec met geklasseerde criteria en rollback-doel.
6. **Plan review**: menselijke gate via een auto-geopende interactieve HTML plan-pagina; feedback-loop tot akkoord.
7. **Uitvoeren**: na akkoord draait de generator/evaluator/council-loop meteen in deze sessie door tot de final audit, geen plak-commando.

Twee vaste menselijke gates (Stage 1 de batch-grill, Stage 6 de HTML plan-review), plus de dynamische council-gate die de run alleen pauzeert wanneer alleen de gebruiker de richting kan kiezen.

## Lokaliseer de skill-directory

```bash
SUPERGOAL_DIR=$(dirname "$(ls -1 \
  "$HOME/.claude/skills/supergoal/SKILL.md" \
  "$PWD/.claude/skills/supergoal/SKILL.md" \
  2>/dev/null | head -n1)")
export SUPERGOAL_DIR
export SUPERGOAL_ROOT="${SUPERGOAL_ROOT:-.supergoal}"
mkdir -p "$SUPERGOAL_ROOT/goals"
echo "SUPERGOAL_DIR=$SUPERGOAL_DIR"
echo "SUPERGOAL_ROOT=$SUPERGOAL_ROOT"
```

Alle artefacten leven onder `$SUPERGOAL_ROOT`, skill-assets onder `$SUPERGOAL_DIR`.

---

## Stage 0 - Context (memory + tools)

### Memory preload

```bash
MEM_DIR=""
for cand in \
  "$HOME/.claude/projects/-Users-$(whoami)/memory" \
  "$HOME/.claude/memory" \
  "$PWD/.claude/memory" \
  "$SUPERGOAL_ROOT/memory"; do
  [[ -d "$cand" ]] && MEM_DIR="$cand" && break
done
echo "MEM_DIR=$MEM_DIR"

if [[ -n "$MEM_DIR" && -f "$MEM_DIR/MEMORY.md" ]]; then
  echo "--- MEMORY INDEX ---"
  cat "$MEM_DIR/MEMORY.md"
fi
```

Lees de index, dan selectief de memory-bestanden die bij de taak passen. Leg hits vast in `$SUPERGOAL_ROOT/applied-memories.md`; toon ze in Stage 1 als "Toegepast uit memory: ...".

### Tool discovery

Schrijf het resultaat naar `$SUPERGOAL_ROOT/tools.md`. Detecteer:

- **Evaluator-isolatie**: Task/Agent tool aanwezig? Ja: evaluator wordt subagent. Nee: aparte-pass fallback.
- **Model-tiers**: welke modellen de host per subagent kan kiezen (bepaalt de routing-tabel).
- **Empirisch gereedschap**: preview MCP, chrome-devtools, `/e2e`, `/run`, curl. Noteer per surface-type wat er is; dit bepaalt hoe `empirical` criteria bewezen worden.
- **Docs**: Context7, WebSearch, WebFetch. Afwezig: training-cutoff kennis, log dat als aanname.
- **Project skills**: domein-relevante skills naar `$SUPERGOAL_ROOT/applied-skills.md`.
- **Dispatch-primitieven**: Workflow-tool, `/loop`, scheduled-tasks (zie Dispatch-tiers; Stage 6.6 kiest ermee).
- **Skill-bronnen**: `npx` + skill-finder aanwezig? Dan per spoor: installed matchen, anders `npx skills add <owner/repo>` van skills.sh, anders zelf schrijven.
- **Eerdere state**: bestaat `$SUPERGOAL_ROOT/STATE.md`, hervat in plaats van opnieuw te beginnen.

### Hervat-detectie

Toont `STATE.md` `Status: IN_PROGRESS` met een openstaande fase: plan niet opnieuw. Print "Supergoal hervatten vanaf fase N" en spring naar Stage 6, of naar Stage 7 als de gebruiker hervatting bevestigt.

---

## Stage 1 - Intake: batch-grill tot gedeeld begrip

Echo de taak terug in één zin. Classificeer (tags combineren): `new-project` (geen `.git/` of lege tree), `existing-repo`, `bugfix` ("bug", "broken", "fails"), `refactor`, `ui` ("design", "UI", "responsive", "redesign").

Draai de intake via de skill `batch-grill-me`: bouw een DESIGN-BOOM van beslissingen en werk hem af in RONDES. De frontier is elke beslissing waarvan de vereisten al vaststaan. Stel de HELE frontier per ronde (genummerd, elk met jouw aanbevolen antwoord), wacht op de antwoorden, herbereken de frontier, en ga door tot de boom leeg is. Feiten zoek je zelf op (recon of subagents; vraag de gebruiker nooit wat je kunt opzoeken); alleen echte beslissingen leg je voor. Dit is zwaarder en vollediger dan een losse vragenlijst: geen tak blijft stilzwijgend aangenomen. Regels bovenop de grill:

- **Elke vraag draagt jouw aanbevolen antwoord** ("ik zou X doen omdat ..."), zodat de gebruiker bevestigt of bijstuurt in plaats van zelf alles te bedenken.
- **Codebase eerst.** Kan recon of memory de vraag beantwoorden, vraag dan niet, zoek het op. Gril alleen wat alleen de gebruiker weet.
- **Scherp vage taal aan.** Bij een overladen term ("account", "annulering") stel je de precieze canonieke term voor en laat je kiezen.
- **Stress-test met een concreet scenario** dat de grens tussen twee concepten forceert ("wat als dezelfde gebruiker tijdens een verlenging dubbel betaalt?").
- **Confronteer tegenspraken direct**: "je zei net X, maar de code doet Y, welke is het?"
- **Leg beslissingen vast terwijl ze vallen**: opgeloste termen naar een glossarium (`CONTEXT.md` als het project die conventie voert, anders een sectie in THINKING.md); een zware trade-off-beslissing krijgt een ADR-achtige notitie in de fase-rationale of ROADMAP "Alternatives considered".
- **Bij een zware of onbekende keuze**: vraag hem niet kaal. Haal 1-3 bronnen op (Docs-bron, Context7, WebSearch), vat ze samen met link, en leg 2-3 concrete scenario's voor met trade-offs plus jouw aanbeveling, als opties in `AskUserQuestion` (aanbevolen eerst). Zo beslist de gebruiker op inhoud in plaats van jouw voorstel af te stempelen.
- **Bij een one-way-door met meerdere geloofwaardige paden** (stack, architectuur, build-vs-buy, een datamodel dat alles vastlegt): convoceer de `council`-skill en vouw het verdict in de keuze-briefing. Right-size: een goedkoop-omkeerbare keuze verdient geen council. Skill niet geïnstalleerd: val terug op de bronnen-en-scenario's-briefing.

Leg het gekozen scenario en de bronnen vast in ROADMAP "Alternatives considered".

De beslisboom is de categorietabel hieronder. **De grill is klaar wanneer elke categorie gedekt is**: beantwoord, al gedekt door memory/prompt (toon als "Toegepast uit memory: ..." / "Uit je prompt: ..."), of expliciet als aanname gelogd voor de Stage 6 review. Niet eerder, niet bij een vast aantal vragen.

| Categorie | Waarom het het plan beïnvloedt |
|---|---|
| Doelplatform / surface | iOS, web, desktop, CLI: andere stacks, fasen, empirische checks |
| Stack / framework | Bepaalt elke fase |
| Design richting | Bepaalt tokens, componentvormen, Polish-inhoud |
| Integratie-ankers | Auth, database, payments, hosting: legt vendors vast |
| Scope-grens | MVP nu vs volledige feature; wat buiten scope valt |
| Use case / doelgroep | Stuurt auth, onboarding, fouttolerantie |
| Performance / schaal | Alleen vragen als niet-triviaal |
| Datamodel | Vraag de vorm als de prompt data impliceert en het niet evident is |

Kalibratie: een taak van < 1 uur in één bestand hoeft geen grill, zeg dat en ga door. Een bestaande codebase grilt recon de meeste vragen weg (vaak blijven er 0-2 over); een nieuw project verdient de volle boom.

---

## Stage 2 - Recon & cross-corpus context assembly

Een lus: verzamelen, beoordelen of het genoeg is, gaten vullen, dan pas plannen.

### 2a. Query rewrite

Zet de taak plus Stage 1-antwoorden om naar gerichte sub-queries, één per open planningsvraag, naar `$SUPERGOAL_ROOT/queries.md`. Decomponeer eerst; fan niet uit op de ruwe taakstring.

### 2b. Vier bronnen

Met een Task tool: een zoek-agent per bron, parallel (prompt-template: `prompts/retrieval-worker.md`). Zonder: dezelfde rondes na elkaar. Elke ronde levert fragmenten met bronvermelding, geen rauwe dumps.

| Bron | Waar vandaan | Wat ophalen |
|---|---|---|
| Code | recon scripts, grep, glob | Repo-vragen beantwoorden met `file:line` bewijs |
| Docs | Context7, WebSearch, WebFetch | Actuele API-docs voor elke SDK die de taak raakt, versie-gepind |
| MCPs | aangesloten servers | Welke data en acties de relevante MCP-tools bieden |
| Skills | available-skills lijst | Passende skills naar `applied-skills.md` |

```bash
mkdir -p "$SUPERGOAL_ROOT/context"
# Existing codebase
bash "$SUPERGOAL_DIR/scripts/detect-stack.sh"   > "$SUPERGOAL_ROOT/context/code-stack.md"
bash "$SUPERGOAL_DIR/scripts/summarize-repo.sh" > "$SUPERGOAL_ROOT/context/code-map.md"
# New project
bash "$SUPERGOAL_DIR/scripts/detect-env.sh"     > "$SUPERGOAL_ROOT/context/code-env.md"
```

### 2c. Sufficient-context judge

Beoordeel de bundel tegen de open vragen (prompt: `prompts/sufficient-context-judge.md`): elke materiële vraag beantwoord of onderbouwd aangenomen, geen tegenspraken tussen corpora, geen hoog-risico gebied op een gok.

- **SUFFICIENT**: schrijf `$SUPERGOAL_ROOT/context/SUFFICIENT.md`, draai 2c-bis.
- **INSUFFICIENT**: schrijf de gaten plus waarom ze ertoe doen, terug naar 2a als verfijnde queries. Max 3 rondes; daarna worden restgaten expliciete aannames in THINKING.md.

### 2c-bis. Adversarial prober

De eerste judge zoekt compleetheid en mist daardoor wat er niet is. Spawn een tweede met de omgekeerde opdracht: vind een gat (prompt: `prompts/adversarial-prober.md`). Een gevonden gat loopt terug naar 2a (telt mee voor de cap). Geen gat na een echte poging: append "Adversarial check passed" aan `SUFFICIENT.md`.

Print daarna een recon-samenvatting van 5 regels: stack, package manager, build/test/lint, opvallende modules, statusregel ("context: SUFFICIENT na N ronde(s)").

---

## Stage 3 - Synthese

Niet opnieuw ophalen; samenvatten uit `$SUPERGOAL_ROOT/context/`:

- **Top 3 risico's**: meest waarschijnlijk fout, moeilijkst omkeerbaar, makkelijk te missen tot het geshipt is.
- **Niet-voor-de-hand-liggende afhankelijkheden**: wat in vaste volgorde moet of ander werk blokkeert.
- **Memory-hits** uit `applied-memories.md` inbakken in goals, constraints of mitigaties.
- **Docs-feiten** versie-gepind; restgaten als expliciete aanname ("verifieer in fase 1").
- **MCP-capabilities** die de taak nodig heeft inbakken in plaats van zelf bouwen.

Schrijf `$SUPERGOAL_ROOT/THINKING.md` (1-2 pagina's): Goals, Constraints, Risks, Dependencies, Aannames, Memory hits, Tools/skills, Best practices. Lat: `references/planning-depth.md`.

---

## Stage 4 - Decompose in fasen

Zoveel fasen als de taak nodig heeft: een triviale wijziging 2, een feature 4-6, een full-stack app 8-12, een grote migratie 15+. Zie `references/phase-design.md`. Eisen:

- Elke fase levert iets dat **op zichzelf verifieerbaar** is, met **expliciete afhankelijkheden**.
- **Echt bewijs is een ontwerp-eis**: elke fase die gedrag oplevert krijgt minstens één `empirical` criterium. Is het enige bewijs "tests slagen", dan is de fase niet goed ontworpen.
- De **laatste fase is altijd Polish & Harden** (edge cases, error states, security, a11y, copy, perf); zo wordt "elk aspect is perfect" afgedwongen.
- Bestaande codebase met dunne testdekking: een vroege **safety net** fase met characterization tests.

Elke fase heeft: naam (max 5 woorden, actie-eerst), waarom (1 zin), deliverables, geklasseerde acceptatiecriteria, mandatory commands, vereist bewijs, afhankelijkheden.

---

## Stage 5 - Roadmap en fase-specs

Vier bestanden onder `$SUPERGOAL_ROOT/`:

1. **`ROADMAP.md`** (template `$SUPERGOAL_DIR/templates/ROADMAP.md`), met een `## Alternatives considered` sectie: welke aanpakken op tafel lagen, waarom deze won, met de intake-bronnen erbij. Geen echte alternatieven: "Single viable approach because <reden>".
2. **`STATE.md`** (template `$SUPERGOAL_DIR/templates/STATE.md`), het live voortgangsbestand; overleeft context-compaction en maakt mid-loop hervatten mogelijk.
3. **`phases/phase-N.md`** (template `$SUPERGOAL_DIR/templates/phase-goal.txt`), de werk-spec per fase.
4. **`phases/phase-N-rationale.md`** (template `$SUPERGOAL_DIR/templates/phase-rationale.md`): waarom deze opdeling, alternatieven, fase-risico's, en het **rollback-doel** (naar welke baseline reverteren als deze fase state corrumpeert).

Elke spec draagt deze markers zodat generator en evaluator dezelfde ankers hebben:

```
SUPERGOAL_PHASE_START
Phase: <N> of <total> - <name>
Task: <one-line>
Mandatory commands: <list>
Acceptance criteria: <count>
Evidence required: <list>
Depends on phases: <list or "none">
Validation classes: tool-output | deliverable | empirical | llm-judge | self-consistency
Team: <sporen + specialisten (2+ bij scheidbaar werk), of "solo (atomair: <reden>)">
Skills needed: <skills per spoor, of "none">
Rollback target: phase <N-k> baseline ref (see phase-N-rationale.md)

[... volledige werkbeschrijving, geklasseerde criteria, vereist bewijs ...]

[De generator print hier SUPERGOAL_PHASE_EVIDENCE; de evaluator print SUPERGOAL_EVAL_VERDICT; op ACCEPT volgt SUPERGOAL_COUNCIL_VERDICT en daarna SUPERGOAL_PHASE_DONE]
```

Valideer elke spec met `bash $SUPERGOAL_DIR/scripts/validate-phase.sh .supergoal/phases/phase-N.md`.

---

## Stage 6 - Plan review & bevestiging (harde gate)

De keten draait onbewaakt zodra hij start; dit is het laatste goedkope moment om bij te sturen.

### Stage 6a - Self-critique pass

Beantwoord vóór de samenvatting exact vier vragen, elk met een uitgeschreven verdict (een pass zonder uitgeschreven antwoorden telt niet):

1. **Toetsbaarheid:** is elk criterium een ja/nee test? Markeer elk "werkt"/"goed"/"klaar" zonder iets meetbaars erachter.
2. **Fase-atomiciteit:** zit er een fase tussen die stiekem twee eenheden is (namen met "en", deliverables zonder gedeelde verify-gate)?
3. **Zwakste afhankelijkheid:** waar cascadeert een gedeeltelijke fout het ergst?
4. **Empirische dekking:** heeft elke gedrag-fase minstens één `empirical` criterium? Zo nee, voeg toe.

Alle vier schoon: noteer `Self-critique: clean.` Bevindingen: noem ze concreet, **herschrijf de betreffende criteria in-place** in de fase-specs en `ROADMAP.md`, herdraai `validate-phase.sh`, toon de herschrijvingen in de samenvatting.

### Stage 6b - Render en open de plan-review HTML

Render `.supergoal/review.html` uit `$SUPERGOAL_DIR/templates/review.html.tmpl`: self-contained (inline SVG, geen externe assets), met fasen, afhankelijkheden, alternatieven, risico's, self-critique, per-fase rationale, en de intake-keuzes met scenario's en bronnen ({{DECISIONS_HTML}}). De markdown onder `.supergoal/` blijft source-of-truth.

**Open de pagina automatisch** voor de gebruiker, toon nooit alleen een pad: `SendUserFile` met `display: "render"` (of de preview-browser / een Artifact als dat er is). De gebruiker leest en beoordeelt in de pagina, niet in een lap chat-tekst.

### Stage 6c - Samenvatting print

```
Plan klaar voor review. <N> fasen.

Toegepast uit memory:
  - <hit 1>
  (of: "geen, schone run")

Fasen:
  1. <naam> - <eenregelige deliverable> [bewijs: <klassen>]
  ...
  N. Polish & Harden - elk aspect geverifieerd

Stack: <stack> | pkg: <pm> | build/test/lint: <commands>
Evaluator: <subagent-geisoleerd | aparte-pass fallback>
Empirisch bewijs via: <preview MCP | /e2e | curl | ...>
Dispatch: <goal | loop> + fase-intensiteit <sequentieel | subagents | workflow> (zeg het als je zuiniger of zwaarder wilt)

Belangrijke aannames (corrigeer wat fout is):
  - <aanname 1>

Top risico's & mitigaties:
  1. <risico> -> <mitigatie>

Self-critique:
  - <bevinding, of "clean">

Artefacten:
  Roadmap: .supergoal/ROADMAP.md
  Voortgang: .supergoal/STATE.md
  Fase specs: .supergoal/phases/phase-1..N.md
  Review: .supergoal/review.html

De plan-pagina is hierboven geopend; geef je feedback daarop.
```

### Stage 6d - Feedback-loop tot het klopt

De review is de geopende HTML-pagina, geen keuzemenu. Herhaal tot de gebruiker akkoord is:

1. Vraag in één regel om feedback op de pagina ("wat klopt nog niet?").
2. Krijg je feedback: verwerk hem in de source-of-truth (`ROADMAP.md` plus de geraakte `phases/phase-N.md`), herdraai `validate-phase.sh`, render `review.html` opnieuw en **open hem opnieuw automatisch** (`SendUserFile` render), zodat de gebruiker de correctie meteen ziet.
3. Zegt de gebruiker dat het klopt (akkoord / "start" / "go"): door naar Stage 6.5. Anders volgende ronde. Nooit starten op stilte.

Geen `/goal`-plak meer: na akkoord draait de keten in deze sessie door (Stage 7).

---

## Stage 6.5 - Pre-flight smoke check

Na akkoord op de plan-pagina, vóór de fase-loop start: draai de mandatory commands (gededupliceerd) één keer tegen de huidige staat. Dit vangt een startpunt dat al stuk is.

1. Union alle `Mandatory commands:` tot een gededupliceerde set.
2. Draai elk één keer, vang exit code en laatste ~5 regels.
3. **Groen**: append `<DATE> - Pre-flight green: <N> commands clean.` aan `STATE.md`, print `PREFLIGHT_GREEN`, door naar Stage 7.
4. **Rood**: append `<DATE> - Pre-flight red: <cmd> exited <code>.`, print `PREFLIGHT_RED` met details, toon de Stage 6 samenvatting opnieuw met menu van 4: **"Skip pre-flight, dispatch anyway"** (de baseline is misschien bewust stuk) / de drie revisie-opties. Bij skip: log `Pre-flight bypassed by user.` en door.

---

## Stage 6.6 - Kies de uitvoeringsvorm

Kies langs de Dispatch-tiers, op twee assen: complexiteit van de vraag en budget. Budget: geen Workflow-tool = zuinig; anders vraag het één keer (zuinig / standaard / max). Triviaal (< 1 uur, één bestand): zeg dat dit geen Supergoal nodig heeft. Terugkerend: `/loop` of scheduled task (tier 4). Al het andere: de in-sessie fase-loop met subagents per scheidbaar spoor (tier 1), plus Workflow-swarms per fase alleen bij max budget en een echte swarm van meer dan 3 agents (tier 3).

Leg vast in `STATE.md` als `Dispatch: <in-session | loop> + <subagents | workflow>` (dit veld begrenst alleen de Workflow-tier; tier-1 subagents draaien altijd bij scheidbaar werk). Stage 7 draait de gekozen vorm.

---

## Stage 7 - Uitvoeren (in deze sessie, geen plak)

Na akkoord op de HTML-pagina draait de keten meteen door in deze sessie; er is geen `/goal`-regel om te plakken. Na akkoord:

1. Update `STATE.md`: `Status: IN_PROGRESS`, `Current phase: 1`, `Baseline ref:` op `git rev-parse HEAD 2>/dev/null || echo "no-git"`. Initialiseer `Phase baselines:` (leeg); de generator vult per fasegrens `phase <N> pre: <ref>` in, de rollback-ankers uit `phase-N-rationale.md`.
2. Kopieer de runtime-bundel naar `.supergoal/` zodat verse subagents en een hervatting alles van schijf lezen: `templates/PROTOCOL.md`, `prompts/phase-judge.md` -> `evaluator.md`, `prompts/phase-team.md` -> `phase-team.md`, `references/workflow-patterns.md` -> `workflow-patterns.md`, `prompts/council-gate.md` -> `council-gate.md`, `scripts/repo-state.sh` -> `repo-state.sh`, en `references/repo-state-comparison.md` + `references/goal-format.md` -> `.supergoal/references/`.
3. Verifieer elke `phase-N.md` met `validate-phase.sh`.
4. Start de fase-loop uit "Uitvoering: de fase-loop" hieronder, gedreven door `.supergoal/PROTOCOL.md`, en draai tot `SUPERGOAL_RUN_COMPLETE`: generator bouwt, onafhankelijke evaluator (verse subagent-context) bewijst, council-richtingsgate op ACCEPT, rollback bij regressie, memory-writeback per fase, en de final audit tegen de oorspronkelijke `ROADMAP.md`. De evaluator-isolatie komt van de subagent-spawn, niet meer van een verse `/goal`-sessie. Pauzeer alleen op de harde stops en op een council-escalatie die alleen de gebruiker kan beslissen.

Vroeger stond hier een kant-en-klaar `/goal`-blok om te plakken; dat is vervangen door dit in-sessie doorlopen. De referentie-mechaniek (de exacte fase-markers en done-conditie) staat in `.supergoal/PROTOCOL.md` en `references/goal-format.md`.

De done-conditie: `SUPERGOAL_RUN_COMPLETE` verschijnt met per fase één ACCEPT, één `SUPERGOAL_COUNCIL_VERDICT` (AUTO-APPROVE of een opgeloste escalatie) en één `SUPERGOAL_PHASE_DONE`, met `AUDIT_COMPLETE` ervoor, en zonder `FAILURE_HANDOFF` of `AUDIT_HANDOFF` deze run. De exacte fase-markers en done-conditie staan in `.supergoal/PROTOCOL.md` en `references/goal-format.md`.

---

## Uitvoering: de fase-loop

Draait in deze sessie, herhaald tot `SUPERGOAL_RUN_COMPLETE`. Volledige mechaniek in `.supergoal/PROTOCOL.md`; de kern:

1. Lees `STATE.md` -> fase N. Lees `phase-N.md`. Snapshot de pre-fase baseline naar `STATE.md`.
2. Print `SUPERGOAL_PHASE_START`.
3. **Generator**: kies eerst het werkpatroon dat bij de fase past (`references/workflow-patterns.md`: default geen patroon, anders classify-and-act, fan-out-and-synthesize, adversarial verification, generate-and-filter, tournament of loop-until-done, naar het signaal in de spec). Knip de fase in onafhankelijke sporen (eigen deliverable, eigen verify-gate, geen gedeelde mutatie van dezelfde bestanden); spoor-detectie is de verplichte eerste stap. Dispatch per Dispatch-tiers (specialist-subagent per spoor bij 2+, zie `.supergoal/phase-team.md`), en los per spoor ontbrekende skills op via de skill-finder-passes. Print `SUPERGOAL_PHASE_TEAM` (patroon, sporen, specialisten, skills). Doe het werk, draai mandatory commands, stuur het artefact aan voor de empirische criteria, en print `SUPERGOAL_PHASE_EVIDENCE`: ruwe command-output + exit codes, gewijzigde bestanden, observaties. Geen oordeel.
4. **Evaluator** (subagent met verse context, of fallback-pass): leest `phase-N.md` en `.supergoal/evaluator.md`, niet het generator-oordeel. Herdraait elke check per klasse (zie de criteria-tabel). Print `SUPERGOAL_EVAL_VERDICT phase=N` met per-criterium pass/fail + bewijs, en ACCEPT of REJECT.
5. **REJECT** -> 3-strike recovery (onder). **ACCEPT** -> council-gate (rol-definitie bovenaan): print `SUPERGOAL_COUNCIL_VERDICT phase=N` met AUTO-APPROVE en ga door, of print bij escalatie `SUPERGOAL_COUNCIL_ESCALATE` (aanbeveling A, alternatieven B/C, bronnen) en leg voor via `AskUserQuestion` (A eerst); bij `B`/`C` herschrijf je de geraakte toekomstige fase-specs en ROADMAP-blokken in-place, herdraai `validate-phase.sh`, en log onder `STATE.md` Council decisions. De geraakte fasen worden later opnieuw door de evaluator bewezen.
6. Memory writeback check, dan `SUPERGOAL_PHASE_DONE`, update `STATE.md`. User-interrupt check op de fasegrens. N < total: volgende fase. N == total: final audit, dan pas `SUPERGOAL_RUN_COMPLETE`.

### Failure recovery (3-strike, op REJECT)

- **1e REJECT**: print `FAILURE_PROBE` (welk criterium, wat de evaluator afkeurde, root-cause hypothese), auto-retry de fase één keer met de probe als feedback.
- **2e REJECT**: print `FAILURE_ESCALATE`, schrijf een gerichte fix spec `phase-N.fix.md` (alleen het falende criterium, geen scope creep), voer uit, evaluator herbeoordeelt.
- **3e REJECT**: print `FAILURE_HANDOFF` (criterium, probe-historie, drie pogingen, volgende stap), zet `STATE.md` op `BLOCKED`, stop.

Regressie die de audit aan fase N toeschrijft: lees het rollback-doel uit `phase-N-rationale.md` en reverteer naar de pre-fase baseline vóór je een fix spec schrijft, in plaats van blind vooruit te patchen.

### Final audit (evaluator-gedreven)

Een latere fase kan een eerdere stilletjes breken; de audit hervalideert tegen de **oorspronkelijke** `ROADMAP.md`, gedraaid door de evaluator. Max 3 rondes; faalt ronde 3, dan `AUDIT_HANDOFF`.

1. Print `AUDIT_START` (ronde, fase-telling, criteria, gededupliceerde commands).
2. Herlees `ROADMAP.md`, trek elk acceptatiecriterium vers uit het origineel.
3. Fase-compleetheid: één ACCEPT en één `SUPERGOAL_PHASE_DONE` per fase 1..N.
4. Herdraai de geaggregeerde mandatory commands, surface exit codes.
5. Her-observeer het artefact end-to-end voor de `empirical` criteria over alle fasen heen.
6. Deliverable-check via `repo-state.sh` tegen de baseline.
7. Print `AUDIT_VERIFY`. Gaten -> `AUDIT_GAPS`, schrijf `audit-fix-<round>.md`, voer uit, loop. Schoon -> `AUDIT_COMPLETE` met coverage, dan `SUPERGOAL_RUN_COMPLETE`.

### Mid-run onderbreking

Bij een gebruikersbericht tijdens de run: pauzeer op de fasegrens (na `SUPERGOAL_PHASE_DONE`, vóór de volgende spec), adresseer het, vraag voor hervatting.

---

## Memory writeback

Op elke ACCEPT-gate: leerde deze fase iets niet-voor-de-hand-liggends dat een toekomstige run helpt? Waard om op te slaan: een API-eigenaardigheid buiten de docs, een bevestigde gebruikersvoorkeur, een project-feit, een faalpatroon plus fix. Schrijf onder MEM_DIR met `name` / `description` / `metadata.type` frontmatter, link vanuit `MEMORY.md`, print `MEMORY_SAVED: <name>` of `none`. De laatste fase schrijft altijd een `project_<slug>.md`. Nooit secrets of efemere state.

---

## Wanneer afwijken

- **Zeer kleine taak** (< 1 uur, één bestand): zeg dat dit geen Supergoal nodig heeft.
- **Gebruiker duwt terug op een fase tijdens intake**: collaps, herplan, door.
- **Mid-run wijziging**: update de fase-spec, draai `validate-phase.sh`, laat hervatten. Niet herstarten bij fase 1.

---

## Referentiebestanden

- `references/planning-depth.md`: wat een plan diep genoeg maakt
- `references/phase-design.md`: fasen opdelen die schoon auto-chainen
- `references/workflow-patterns.md`: de zes werkpatronen en de keuze per fase
- `references/goal-format.md`: `/goal` op Claude Code + Codex, de vereiste transcript-blokken
- `references/repo-state-comparison.md`: hoe de working-tree vergelijking werkt

## Scripts

- `scripts/detect-stack.sh`, `scripts/detect-env.sh`, `scripts/summarize-repo.sh`: recon
- `scripts/validate-phase.sh`: checkt de SUPERGOAL_PHASE_START marker en geklasseerde criteria
- `scripts/repo-state.sh`: working-tree vergelijking voor deliverable- en cleanliness-checks

## Prompts

- `prompts/retrieval-worker.md`: retrieval-worker per corpus (Stage 2b)
- `prompts/sufficient-context-judge.md`: de eerste context-judge (Stage 2c)
- `prompts/adversarial-prober.md`: de tweede context-judge (Stage 2c-bis)
- `prompts/phase-judge.md`: de onafhankelijke evaluator (bij dispatch -> `.supergoal/evaluator.md`)
- `prompts/phase-team.md`: per-fase team-orchestratie + skill-resolutie (-> `.supergoal/phase-team.md`)
- `prompts/council-gate.md`: de per-fase richtings-gate (-> `.supergoal/council-gate.md`)

## Templates

- `templates/ROADMAP.md`, `templates/STATE.md`, `templates/phase-goal.txt`, `templates/phase-rationale.md`
- `templates/PROTOCOL.md`: de uitvoeringsloop (bij dispatch -> `.supergoal/PROTOCOL.md`)
- `templates/review.html.tmpl`: self-contained plan-review HTML
