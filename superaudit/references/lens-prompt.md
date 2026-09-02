# Prompt-template voor een lens-agent

Gebruik dit sjabloon voor elk van de zeven agents in fase 1. Vul de `<...>`-velden in;
laat de rest staan. De kracht zit in drie dingen: de agent leest de lenssectie en de
projectkaart zelf (niet jouw samenvatting), hij krijgt de context-alinea met de
invarianten die waar moeten zijn, en hij krijgt een lijst van concrete plekken en
vragen die de lens in dít geval scherp maken. Zonder dat derde punt zoekt een agent
generiek; met dat punt zoekt hij waar de diff echt kan breken.

```
Je bent de lens **<naam>** van een /superaudit-review. Repo: <pad> (<stack>). Wijzig geen bestanden.

Lees eerst: (1) de sectie "## <naam>" plus de drie leesregels bovenaan in
<SUPERAUDIT_DIR>/references/lenzen.md, (2) <stack-appendix(en) die van toepassing zijn>,
(3) de projectkaart <SUPERAUDIT_ROOT>/projectkaart.md (<welke tabellen het meest relevant zijn>),
(4) de volledige diff in <scratchpad>/diff-<ref>.patch (range <a..b>).

Context (wat de auteur wilde, wat waar moet zijn): <de context-alinea uit fase 0, inclusief
de invarianten als losse zinnen: "nooit X overschrijven", "hoogstens één rij per Y", ...>.

Lees ook de omliggende code, niet alleen de diff: <bestanden en functies uit de blast
radius: aanroepers, modellen met veldtypes en constraints, tests, contractdocumenten>.
Volg aanroepers met grep.

Onderzoek specifiek: <vijf tot tien concrete vragen voor deze lens op deze diff, bv.
"staat de update binnen dezelfde transactie als de create?", "is het veld uniek in het
schema en wat doet .first() bij twee treffers?", "welke tak van functie F is ongedekt?",
"klopt de doc-regel R nog met code C?">.

Lever maximaal 8 kandidaten, uitsluitend als JSON-array in dit formaat, elk met een
concreet faalscenario; zonder faalscenario geen kandidaat. Geen stijl, geen "overweeg".
Geef daarna in één alinea welke vermoedens je hebt onderzocht en weerlegd (voor
"Bewust niet gemeld").

[{"lens": "<naam>", "file": "pad", "line": 42, "severity": "P0|P1|P2|P3",
  "summary": "één zin, de claim zelf",
  "failure_scenario": "concrete input/toestand -> concreet fout resultaat",
  "evidence": "wat je gecheckt hebt: bestand:regel, aanroepers, test, docs",
  "fix": "kleinste correcte fix of 'ontwerpkeuze: ...'",
  "confidence": "ZEKER|PLAUSIBEL"}]
```

Per lens de extra regel die het verschil maakt:

| Lens | Voeg toe aan "Onderzoek specifiek" |
|---|---|
| bugs | "Wat als het twee keer draait? Wat als de externe call halverwege faalt? Welke guard is verwijderd of eenrichting?" |
| data | "Transactiecontext van elke write; unique constraints achter elke exists()+create() en get_or_create; `.first()` op een niet-uniek veld; serialisatie van nieuwe types in dicts die naar JSON/Celery gaan; hoort er een migratie bij?" |
| domein | "Requirement-trace per claim uit de commit-message (COMPLEET/AFGEWEKEN/WEGGELATEN/ONBEWEZEN); klopt elk document dat als contract geldt nog; waar is de uitkomst voor een mens zichtbaar?" |
| security | "Werk eerst de huispatronen uit en vergelijk; PII in log-, error- en responsvelden; kan externe input een bestaand object claimen; raakt de diff een schrijfgrens?" Plus de aannames tegen ruis uit lenzen.md. |
| kwaliteit | "Bestaat de helper al (grep op de kernregel, bv. sha256/idempotency_key/parse); is de docstring-reden waar; dode defaults en onbereikbare takken." Alleen P2/P3. |
| tests | "Welke takken van de nieuwe code raakt geen test; welke fout zou elke ontbrekende test vangen (score 5-10); mockt de test de grens of het onderwerp; steunt hij op testsettings-drift uit de projectkaart?" |
| contract | "Is elke aanname over een externe payload in deze repo bewezen (fixture, doc, echte call)? Wie leest elk gewijzigd of nieuw veld (types, adapters, MCP, agent-tools)? Klopt het contractdocument na deze diff, expliciet ja/nee?" |

## Kosten en wanneer je ze maakt

Een volledige run met zeven agents op een diff van ~250 regels kostte in de praktijk
ongeveer 800k tokens en vijf tot zes minuten wall-clock, en leverde twee P1's op die een
enkele pass had gemist (vijf lenzen convergeerden op dezelfde bug, wat de confidence van
PLAUSIBEL naar ZEKER bracht). Dat is de prijs waard voor een merge naar productie, niet
voor een commit van tien regels: daar geldt `--snel` of de één-pass-modus. Verify-agents
zijn alleen nodig als een kandidaat door één lens gevonden is en de trigger op data of
timing steunt; kandidaten waar twee of meer lenzen op convergeren verifieer je zelf door
de geciteerde regels te lezen.
