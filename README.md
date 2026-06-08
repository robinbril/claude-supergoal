# Supergoal

Plan een grote softwaretaak samen met de agent, laat hem daarna autonoom bouwen, en laat niks "klaar" zijn tot een onafhankelijke controleur het bewijst.

Een skill voor Claude Code en Codex.

<p align="center">
  <img src="docs/architecture.png" alt="Supergoal architectuur" width="820">
</p>
<p align="center"><sub>Schaalbare bron: <a href="docs/architecture.svg">architecture.svg</a></sub></p>

## Wat het is

Supergoal neemt een taak die je normaal de hele dag moet babysitten en draait hem in twee delen: eerst plan je samen, daarna bouwt de agent zelf. Het verschil met de standaard zit in de controle. De agent die bouwt mag nooit zelf beslissen of het werk klaar is. Dat doet een aparte controleur.

## Waarom dit anders is dan de standaard

De grootste faalmodus van autonome agents is dat ze zichzelf "klaar" verklaren terwijl het niet klopt. Supergoal haalt dat weg:

- **De bouwer keurt nooit zijn eigen werk.** Een onafhankelijke evaluator met een schone context doet elke check zelf opnieuw, blind voor wat de bouwer beweert.
- **Bewijs komt uit de echte app.** De evaluator draait de app en kijkt of het gedrag klopt, niet alleen of de tests groen zijn.
- **Gebouwd voor lange runs.** Plan en voortgang staan op schijf en overleven context-verlies. Een regressie rolt terug naar de baseline van de vorige fase. Aan het eind draait een audit tegen het oorspronkelijke plan.
- **Plannen is een gesprek.** In de planfase interviewt de skill je als een architect: een scherpe vraag per keer, met een aanbeveling, plus artikelen en scenario's zodat je op inhoud beslist. Bij een echt zware, onomkeerbare keuze roept hij een adviesraad (council) van onafhankelijke adviseurs bijeen die de afweging voor je uitvecht.
- **Een adviesraad bewaakt de richting.** Tijdens de run kijkt na elke goedgekeurde fase een adviesraad of de koers nog klopt. Meestal gaat het automatisch door. Alleen bij een zware koerskeuze pauzeert hij en legt hij je een aanbeveling met alternatieven en bronnen voor: zeg `go` om de raad te volgen, of `B`/`C` om bij te sturen. Is er niemand om te antwoorden, dan volgt hij zijn eigen aanbeveling, zodat een lange run niet stilstaat.
- **Per fase een team.** Een fase met losse sporen draait standaard als team: een specialist per spoor, parallel, elk met een eigen skillset, en ontbrekende skills bijgehaald via de skills.sh registry of zelf geschreven. De onafhankelijke evaluator blijft er overheen, dus de bouwkracht groeit zonder dat het vertrouwen daalt. Parallelle subagents kosten geen extra credits; alleen grote swarms via de Workflow-tool wel.

## Hoe het werkt

1. **Context.** Memory inladen, kijken welk gereedschap er is (subagents, een manier om de app te draaien), een lopende run hervatten.
2. **Plannen samen.** De skill loopt de beslisboom met je af door te blijven doorvragen, een vraag per keer, met bronnen en scenario's bij de zware keuzes.
3. **Context verzamelen.** Info uit vier bronnen (code, docs, MCP's, skills), met een check of het genoeg is plus een tweede check die juist een gat zoekt.
4. **Plan opdelen.** Zoveel fasen als de taak nodig heeft, elk op zichzelf te controleren, met empirisch bewijs waar gedrag ontstaat.
5. **Plan-review.** Je krijgt een samenvatting plus een losse HTML-pagina met de fasen, de keuzes, de bronnen en de risico's. Jij keurt goed. Dit is de enige stop.
6. **Autonome run.** Een ronde per fase: de generator bouwt, de onafhankelijke evaluator bewijst (ACCEPT of REJECT). REJECT start een herstel van maximaal drie pogingen. Per fase kan de generator een team van specialisten opzetten en ontbrekende skills bijladen (via skills.sh of zelf geschreven); de evaluator blijft er onafhankelijk overheen. Na elke goedgekeurde fase checkt de adviesraad de richting: meestal gaat het door, alleen bij een zware koerskeuze vraagt hij jou (`go` / `B` / `C`).
7. **Eindaudit.** Na de laatste fase controleert de evaluator het geheel nog eens tegen het oorspronkelijke plan, voordat de run als klaar geldt.

Twee vaste momenten vragen jouw input: de planfase en de plan-review. Daarbovenop pauzeert de adviesraad de run alleen wanneer alleen jij een koerskeuze kunt maken. Verder draait het zelf.

Supergoal kiest zelf de uitvoeringsvorm: `/goal` voor een gewone build, met parallelle subagents per scheidbaar spoor (gratis), grote Workflow-swarms alleen als je budget het toelaat, of `/loop` (of een scheduled task) als de taak terugkerend is.

## Installeren

```bash
git clone https://github.com/robinbril/claude-supergoal.git
mkdir -p ~/.claude/skills/supergoal
cp -r claude-supergoal/SKILL.md claude-supergoal/prompts claude-supergoal/references \
      claude-supergoal/scripts claude-supergoal/templates claude-supergoal/docs \
      ~/.claude/skills/supergoal/
```

Voor een project in plaats van globaal: zet dezelfde mappen onder `.claude/skills/supergoal/` in je projectroot.

## Gebruiken

In Claude Code of Codex:

```
/supergoal beschrijf wat je wilt bouwen, fixen of verschepen
```

Daarna: plan samen, keur het plan goed, plak de ene `/goal` regel die de skill voor je klaarzet, en de run draait tot klaar.

## Werkt op

Claude Code en Codex. Waar geen subagents beschikbaar zijn, draait de evaluator als losse stap; de checks die hij overdoet hangen niet van die context af, dus het meeste blijft overeind.

## Wat zit erin

```
SKILL.md                de skill zelf
prompts/                de evaluator, het per-fase team, en de drie context-checks
references/             planning, fase-opdeling, /goal-formaat, repo-vergelijking
scripts/                recon en de working-tree vergelijking
templates/              ROADMAP, STATE, PROTOCOL, fase-spec, review.html
docs/architecture.svg   de procesflow, stage voor stage (dark theme)
```

## Credits

Voortbouwend op het open-source project [supergoal](https://github.com/robzilla1738/supergoal) van Robert Courson (MIT) en op het `/goal`-commando van Claude Code.

## Licentie

MIT. Zie [LICENSE](LICENSE).
