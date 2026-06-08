# Workflow-patterns (per fase het beste patroon kiezen)

Bij dispatch wordt dit bestand mee naar `.supergoal/` gekopieerd. De generator leest het per
fase en kiest het werkpatroon dat bij de aard van de fase past, voordat hij de sporen dispatcht
(zie `phase-team.md`).

Een patroon is hoe de generator een fase aanpakt: solo doorbouwen, of de fase opdelen en agents
in een vaste vorm laten samenwerken. Het patroon staat los van de evaluator-gate. Wat de
generator ook kiest, de onafhankelijke evaluator herdraait daarna elke check op het draaiende
artefact. Meer structuur aan de bouwkant koopt geen vertrouwen vooraf.

## Eerst: heeft deze fase een patroon nodig?

Default is **geen speciaal patroon**: de generator bouwt de fase gewoon, sequentieel. De meeste
fasen verdienen dat. Een patroon kost meer tokens en agents, dus zet het alleen in als de aard
van de fase erom vraagt. Vraag per fase: heeft dit echt meer compute nodig, of is het een
coherente klus die een agent goed alleen afmaakt?

Een patroon verdient zich terug wanneer een fase last heeft van een van deze drie faalvormen van
een enkele lange context:

- **Halverwege stoppen.** Een agent verklaart een grote, meervoudige taak klaar na deelwerk (20
  van de 50 punten in een review).
- **Voorkeur voor eigen werk.** Een agent die zijn eigen output beoordeelt vindt hem te makkelijk
  goed.
- **Doel-drift.** Over veel beurten en na compaction lekt het oorspronkelijke doel weg, en
  verdwijnen randvoorwaarden en "doe X niet"-regels.

Aparte agents met een eigen schone context en een scherp, afgebakend doel halen die druk weg.

## De zes patronen

1. **Classify-and-act.** Een classifier-agent bepaalt het type werk en routeert naar de juiste
   aanpak, agent of model. Ook bruikbaar aan het eind om de output te bepalen. *Wanneer:* de
   juiste aanpak hangt af van het type input, of het werk moet eerst gesorteerd worden. *Hoe:*
   een lichte classifier-agent, dan de gekozen tak.

2. **Fan-out-and-synthesize.** Knip de fase in veel kleine deelstappen, een agent per stap, dan
   een synthese-stap die alle gestructureerde resultaten samenvoegt. De synthese is een barrier:
   hij wacht op alle fan-out-agents. *Wanneer:* veel onafhankelijke deelstappen, of elke stap is
   gebaat bij een eigen schone context zodat ze elkaar niet besmetten. *Hoe:* subagents of een
   Workflow-fan-out, dan een synthese-agent.

3. **Adversarial verification.** Voor elke geproduceerde uitkomst draait een aparte agent die hem
   juist probeert te weerleggen tegen een rubric of criterium. *Wanneer:* de uitkomst moet hard
   kloppen (security, correctheid, feitelijke claims). *Hoe:* per finding een refuter-agent, een
   meerderheid beslist.

4. **Generate-and-filter.** Genereer veel kandidaten, filter ze op een rubric of door
   verificatie, ontdubbel, en geef alleen de beste terug. *Wanneer:* veel mogelijke opties of
   ideeen, je wilt de sterkste. *Hoe:* generator-agents parallel, dan een filter-stap.

5. **Tournament.** In plaats van het werk te verdelen, laat agents om het beste resultaat
   strijden. N agents pakken dezelfde taak met een andere aanpak, judge-agents vergelijken
   paarsgewijs tot er een winnaar is. *Wanneer:* smaak- of keuzewerk (ontwerp, naamgeving), of
   sorteren op een kwalitatieve maat. *Hoe:* N pogingen, dan een bracket van paarsgewijze judges.

6. **Loop until done.** Bij werk van onbekende omvang: blijf agents spawnen tot een stopconditie
   (niks nieuws meer, geen errors meer in de logs) in plaats van een vast aantal rondes.
   *Wanneer:* discovery met een open eind (audit, bugs zoeken, edge cases). *Hoe:* een lus die
   spawnt tot K lege rondes, of pair met `/loop` voor doorlopend werk.

Patronen mogen combineren. Een fase kan fan-out gebruiken om sporen te bouwen en daarna
adversarial verification om elk spoor te toetsen.

## Selectie-heuristiek (signaal in de fase, patroon)

| Signaal in de fase-spec of de gebruikersvraag | Patroon |
|---|---|
| Coherente klus, een agent maakt het goed alleen af | geen patroon, sequentieel (default) |
| De aanpak hangt af van het type input, of werk moet gesorteerd | classify-and-act |
| Veel onafhankelijke deelstappen, elk eigen context | fan-out-and-synthesize |
| Uitkomst moet hard kloppen: security, correctheid, claims | adversarial verification |
| Veel kandidaten of ideeen, beste eruit | generate-and-filter |
| Smaak of keuze, beste van meerdere aanpakken | tournament |
| Onbekende omvang, door tot niks nieuws | loop until done |

Wijst meer dan een rij naar een patroon, kies de zwaarste die past, of combineer ze.

## Twijfel: een classifier-agent

Is de aard van de fase niet eenduidig uit de spec te lezen, spawn dan een lichte classifier-agent
(dat is classify-and-act toegepast op de keuze zelf): hij leest de fase-spec en geeft een patroon
terug met een reden. Default blijft de heuristiek; de classifier is voor de randgevallen, zodat
een zuinig account niet per fase een extra agent betaalt.

## Kosten

Patronen die parallel spawnen (fan-out, tournament, adversarial met veel refuters) verbranden
tokens. Ze volgen dezelfde dispatch-as als de team-zwaarte: sequentieel binnen de `/goal` run als
standaard, subagents bij echte parallelle sporen, de Workflow-tool alleen met genoeg credits. Het
patroon kiest de vorm, de dispatch-modus kiest hoe zwaar je hem draait.
