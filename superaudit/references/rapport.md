# Rapport-template en kalibratie

## Template

```
# Superaudit: <range | PR #n | pad>

**Modus: uitgekleed.** <weglaten als de run volledig was. Anders: geen lens-agents (alle
lenzen zelf in één pass), geen toolchain (tests en migraties niet gedraaid), geen
node_modules (typecheck en unit-tests niet gedraaid), PR niet opgehaald. Wat "ZEKER" heet
steunt dan op code-lezing, grep van aanroepers en scratchpad-reproducties.>

**Oordeel: MERGEN | MERGEN NA FIXES | NIET MERGEN**
<Eén alinea. Wat de wijziging doet in gewone taal, wat er goed aan is, en de reden voor
het oordeel. Geen opsomming van bestanden: dat staat in de diff.>

**Niet geverifieerd:** <weglaten als alles gedraaid is. Anders: wat niet kon en waarom.>

## Findings

### P0 <titel als claim, geen vraag> — `pad/bestand.py:123`
Faalscenario: <concrete toestand of input> -> <concreet fout resultaat>.
Bewijs: <wat je nagekeken hebt: aanroepers, test die ontbreekt/faalt, reproductie, docs>.
Fix: <kleinste correcte fix, of "ontwerpkeuze: A of B, want ...">.

### P1 ...

### P2 ...

### P3 (gebundeld)
- `pad:regel` <één regel>

## Bewust niet gemeld
- <het vermoeden dat een lezer zou hebben> : weerlegd omdat <reden>.
- <bestaand probleem buiten blast radius> : buiten scope, staat op <plek> als follow-up.

## Bewijs
- scope: <de samenvattingsregels van fastcheck.sh: range, shortstat, mappen, migraties>
- fastcheck: <groen/rood; lint nieuw/bestaand; welke stappen OVERGESLAGEN>
- reproducties: <scripts/tests die je draaide, met uitkomst>
- lenzen: <per lens: agent of zelf, en "niets" of de finding-nummers>
- gap sweep: <wat je zocht en of het leeg was>
```

## Wat een goed finding is

**Goed (P1):**

> ### P1 `invoice_ready()` markeert een factuur als klaar terwijl de verplichte PO ontbreekt — `billing/invoice_ready.py:88`
> Faalscenario: klant met `po_required=True` en een contract zonder `po_number`; de nieuwe
> `all(...)`-check itereert over `checks` maar `po_check` is uit de lijst gevallen in deze
> diff (regel 71). De factuur gaat naar "klaar" en de boeking in `invoice.py:214` gebruikt
> een lege PO-referentie; die factuur wordt door de klant afgekeurd.
> Bewijs: `tests_invoice_ready.py` heeft geen case met `po_required=True`; scenario
> gereproduceerd in de shell met een factory: `ready == True`.
> Fix: `po_check` terug in `checks`, plus een test met `po_required=True` zonder PO die
> `ready is False` verwacht.

Claim in de titel, concrete toestand, het pad naar de schade, bewijs dat de lezer kan
nalopen, fix die de auteur direct kan doen.

**Slecht:**

> Mogelijk kan `invoice_ready()` in bepaalde gevallen onterecht True geven. Overweeg extra
> validatie toe te voegen.

Geen toestand, geen regel, geen schade, geen bewijs, en "overweeg" schuift het werk naar de
lezer.

**Geen finding (weglaten of in "Bewust niet gemeld"):**

- "Decimal wordt vergeleken met een int": dat is correct. Weerlegd.
- "De view heeft geen login-check": de route staat onder een wrapper die login en rol
  afdwingt. Weerlegd, hoort in "Bewust niet gemeld" omdat een lezer dit ook zou vermoeden.
- "Functie is 60 regels, splits op": geen faalscenario, geen onderhoudsrisico aangetoond.
- "Gebruik f-strings": linter-territorium.

## Kalibratie van severiteit

Vraag per finding: **wat gebeurt er in productie, bij wie, en hoe snel merkt iemand het?**

| Situatie | Niveau |
|---|---|
| Fout geldbedrag, hoe klein ook | P0 |
| Persoonsgegevens in log, respons buiten doel, of onversleuteld nieuw veld | P0 |
| View/endpoint zonder authz waar die elders wel staat | P0 |
| Migratie die op prod faalt (not-null zonder default op gevulde tabel, unique op dubbele data) | P0 |
| Nieuw schrijfpad naar een extern systeem buiten de afgesproken plekken | P0 |
| Verkeerd resultaat in een reëel maar niet-dagelijks scenario | P1 |
| Sync/job die bij herhaling dubbele records maakt | P1 |
| Status-transitie die een verboden pad toestaat | P1 |
| Stille fout waar de gebruiker een succesmelding ziet | P1 |
| Duplicaat van een bestaande helper met net andere semantiek | P2 |
| Test die alleen de happy path dekt op rekenlogica | P2 |
| N+1 in een lijst die in prod honderden rijen heeft | P2 (P1 als de pagina er al traag van is) |
| Dode code, dode import, misleidende comment | P3 |

Twijfel tussen twee niveaus: kies het lagere en zeg in het faalscenario waarom het geen
niveau hoger is. Overdrijven kost meer vertrouwen dan onderschatten.

## Toon

Direct, feitelijk, zonder "misschien", zonder "goed werk!" als opvulling, zonder herhaling
van wat de diff al laat zien. In de taal van het project.
