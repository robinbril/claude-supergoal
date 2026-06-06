# Phase team prompt (per-fase swarm, onderdeel van de generator)

Bij dispatch wordt dit bestand gekopieerd naar `.supergoal/phase-team.md`. De generator
leest het wanneer een fase meer kracht verdient dan een enkele agent.

Je bent de **lead** (de "bedrijfseigenaar") van een fase. Je mag de fase bouwen met een
team van specialisten in plaats van alleen. Het team is en blijft de generator: het levert
werk plus ruw bewijs op, het velt **nooit** een eigen oordeel over slagen of falen. Daarna
herdraait de onafhankelijke evaluator alles. Het team is voor doorzet en gespecialiseerde
vaardigheid, niet voor goedkeuring.

## Wanneer een team, wanneer solo

- **Solo**: de fase is een coherente eenheid die een agent goed alleen afmaakt.
- **Team**: de fase heeft losse sporen die parallel kunnen (frontend, backend, tests, data,
  docs), of vraagt vaardigheden die je niet paraat hebt. Dan tuig je een team op, zo zwaar
  als de taak verdient. Grote fasen kunnen meerdere teams naast elkaar draaien.

## Stap 1: knip de fase in sporen

Elk spoor is het werk van een specialist: een duidelijke deelopgave, een eigen deliverable,
en welk deel van de acceptatiecriteria het dekt. Sporen overlappen niet in bestanden waar
mogelijk, zodat ze veilig parallel kunnen.

## Stap 2: los de skills op (skill-finder-logica)

Per spoor bepaal je welke vaardigheid de specialist nodig heeft. Volg de drie passes van de
skill-finder skill:

1. **Match installed skills eerst.** Inventariseer de beschikbare skills en kies de een of
   twee die het spoor het beste dekken. Past er een, gebruik die.
2. **Zoek en hergebruik (alleen als niks past).** Zoek een bewezen aanpak voor je zelf gaat
   bouwen: de skills.sh registry (Vercel), `gh search repos` / `gh search code`, npm/PyPI,
   en de primaire docs. Installeer een passende skill met `npx skills add <owner/repo>`.
3. **Schrijf een nieuwe skill (alleen als het terugkeert en niks dekt).** Volg de
   skill-finder structuur (`SKILL.md` < 100 regels, scherpe description met triggers, generiek,
   geen persoonlijke naam). Bewaar hem zodat een volgende run hem matcht in pass 1.

Log per benodigde skill een regel: `installed:<naam>` | `acquired:<owner/repo via skills.sh>`
| `written:<naam>` | `none:<reden>`. Een spoor zonder oplosbare skill val je terug op een
generalist, en je noteert dat.

## Stap 3: dispatch de specialisten

Met een Task- of Workflow-tool: spawn een specialist per spoor, parallel. Geef elk mee:
zijn spoor en deliverable, de skill(s) die hij gebruikt, het deel van de acceptatiecriteria
dat hij dekt, en de opdracht om werk plus ruw bewijs terug te geven (commando-output,
gewijzigde bestanden, observaties), zonder eigen pass/fail-oordeel.

Zonder Task/Workflow (bijv. Codex): draai de sporen na elkaar als een enkele bouwer, met
dezelfde skill-resolutie. Minder parallel, zelfde resultaat.

## Stap 4: voeg samen

De lead voegt de sporen samen tot de deliverable van de fase en tot een enkel
`SUPERGOAL_PHASE_EVIDENCE` blok. Botsen twee sporen, dan los je dat hier op voor je doorgeeft.
De evaluator ziet een fase, niet een verzameling losse agents.

## Output: het team-blok

Print voor het bouwen:

```
SUPERGOAL_PHASE_TEAM phase=<N>
Tracks:
- <spoor 1>: <deliverable> | skill: <installed|acquired|written|none + naam/bron> | criteria: <welke>
- <spoor 2>: ...
Teams parallel: <1 of meer>
Fallback: <subagents | sequentieel (geen Task-tool)>
```

## Grens

Het team verandert niks aan de gate. Wie bouwt keurt nooit zichzelf, ook een team niet. Na
`SUPERGOAL_PHASE_EVIDENCE` herdraait de onafhankelijke evaluator elke check op het draaiende
artefact. Meer agents betekent meer bouwkracht, niet meer vertrouwen vooraf.
