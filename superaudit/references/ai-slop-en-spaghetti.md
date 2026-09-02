# AI-slop en spaghetti: signaturen, en wanneer het een finding is

Veel code wordt met hulp van modellen geschreven. Dat is geen probleem; het probleem is het
residu dat een model achterlaat als niemand het weghaalt. De hoofdvraag is steeds: **kost
dit de volgende lezer of de volgende wijziging iets?** Zo ja, finding. Zo nee, laat het
liggen; een review is geen schoonheidswedstrijd.

## Signaturen van gegenereerde ruis

| Signatuur | Hoe het eruitziet | Finding? |
|---|---|---|
| Comment die de regel herhaalt | `# verhoog teller` boven `teller += 1` | P3 gebundeld, alleen als het hindert. Een *waarom*-comment is geen slop |
| Defensieve laag op onmogelijke input | `if not isinstance(x, dict): return {}` op een intern dict-argument; try/except rond code die niet kan falen | P2 als het een echte fout verbergt, anders P3 |
| `except Exception: return None/[]/{}` | stille fallback die de aanroeper een lege maar "geldige" waarde geeft | **P1** als een gebruiker daardoor een succes ziet bij een fout; P2 anders. Vraag: wie merkt de fout? |
| Fallback-cascade | `x = a or b or c or DEFAULT` waar `b` en `c` nooit gevuld zijn | P2 |
| Configuratie-explosie | parameters/flags voor varianten die geen aanroeper gebruikt | P2 (dode parameter is een leugen over het contract) |
| Abstractie voor één geval | basisklasse met één subklasse, strategy met één strategie, registry met één entry | P2 als nieuw in de diff; bestaande laten liggen tenzij de diff hem uitbreidt |
| Helper die er al was | nieuwe `to_decimal`, `parse_date`, `month_bounds`, scoping-berekening naast de bestaande | **P2** met de naam van de bestaande helper |
| Bijna-duplicaat | twee functies die op één regel of constante verschillen, met copy-paste-docstring | P2, tenzij gedocumenteerd bewust (en dan: beide plekken in de diff gelijk gewijzigd?) |
| Type-theater | `Optional[Any]`, `dict[str, Any]` overal, `cast()`/`as any` dat een fout verbergt | P3; P2 als een cast een echte type-fout maskeert |
| Logging-ruis | `info` op elke stap; debug met f-strings die persoonsgegevens bevatten | P3; **P0** bij persoonsgegevens of tokens in de logregel |
| Emoji, marketing-adjectieven ("robuust", "naadloos"), conversatie-artefacten ("Here is", "Note that") in code of commits | zie links | P3 gebundeld; nooit het enige finding |
| Test die de implementatie test | `called_once_with` zonder resultaat-assert; mock van de functie onder test | P2 |
| Happy-path-only test op rekenlogica | één case, geen leeg/nul/grens | P2 op geld/compliance, P3 elders |
| Onderdrukking zonder reden | `# noqa`, `# type: ignore`, `eslint-disable` zonder toelichting | P3 |
| Reorganisatie vermengd met gedrag | 400 regels verplaatsen en hernoemen naast een functionele wijziging | geen finding op zich; zeg in het oordeel dat de review daardoor onbetrouwbaarder is en vraag om splitsing als het P0/P1-gebied raakt |
| Gegenereerde migratie met verrassingen | tien `AlterField`s door een `help_text`, naast de echte wijziging | P3; **P1** als er een type-, null- of lengte-wijziging tussen zit die de auteur niet noemt |
| Gehallucineerde dependency | package dat niet bestaat of niet in de lockfile staat | **P0** (slopsquatting-risico); verifieer met de package-manager |

## Spaghetti: code op de verkeerde hoogte

| Signatuur | Finding? |
|---|---|
| Special case op gedeelde infra (`if klant == "X"` in een service; type-check in een generieke serializer) | P2; noem waar de generalisatie hoort |
| Business-regel in view/serializer terwijl er een service, rule-engine of setting voor is | **P1** als er al een bron is (twee bronnen driften); P2 als het de eerste plek is |
| Grens hardcoded die instelbaar hoort te zijn | P1 |
| Service die een `request` neemt | P2 (API en pagina krijgen dan niet gegarandeerd dezelfde cijfers) |
| Signal/hook die werk doet dat een service moet doen (netwerk, externe writes, mail) | P1 als nieuw |
| Serializer/view die queries doet zonder prefetch, of `.objects.all()` waar een guarded queryset hoort | P2 (N+1) / **P1** (scoping) |
| Frontend met backend-kennis (hardcoded enums, business-regels in adapters) | P2 |
| God-bestand groeit door met een nieuwe verantwoordelijkheid | P3; P2 als het bestand daardoor twee taken krijgt |
| Drie of meer boolean-parameters die gedrag vertakken | P2 |
| Impliciete volgorde-afhankelijkheid zonder check | P1 als de fout stil is, P2 als hij luid faalt |

## Dode code

| Signatuur | Hoe je het hardmaakt | Finding? |
|---|---|---|
| Functie/klasse zonder aanroepers | grep over alle talen; let op dynamische dispatch (routes, registries, admin, job-namen als string, templates, tool-registries) | P3; P2 als hij misleidend is |
| Parameter die niemand meegeeft | grep op aanroepers | P3 |
| Enum-waarde zonder gebruik, met rijen in de database | code-grep plus read-only `count()` | P2 |
| Flag die altijd één kant op staat | setting nergens gezet, of altijd gelijk in tests én prod | P2 |
| Component/template zonder route of import | grep op naam | P3 |
| Data-migratie die naar een verwijderd veld verwijst | lees de migratie | P1 (breekt `migrate` op een verse database) |
| Dependency die niemand importeert | manifest versus imports | geen finding in een PR-review; wel in "Structurele patronen" bij een audit |

## Wat géén slop is

- Lange *waarom*-docstrings en comments die een beslissing uitleggen. Meld ze nooit als
  "te veel commentaar".
- Bewust gedupliceerde regel met een comment die de duplicatie uitlegt en de andere plek
  noemt (wel checken dat beide in de diff gelijk veranderen).
- Een brede `except` **met** onderdrukkingsreden op een grens (netwerk, subprocess,
  audit-log) waar fail-soft de bedoeling is.
- Een settings-lezing met try/except en een constante fallback als dat de conventie is.
