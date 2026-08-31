# Frontend craft (mega-kritisch)

Generiek distillaat van 15 frontend-skills, voor de supergoal-bouwloop. Geen merk. Doel: elke frontend-fase op productieniveau bouwen en keuren voor die fase ACCEPT krijgt.

## Componenten die je standaard goed doet

- **Button**: instant feedback op pointer-down, niet op release. `active:scale-0.96` (nooit lager dan 0.95). Label past op 1 regel, contrast WCAG AA tegen de achtergrond. Hit-area minimaal 40x40px desktop, 44x44px touch.
- **Input/form**: label boven het veld, error eronder, nooit placeholder-as-label. Validatie inline, niet pas op submit. 16px teksthoogte op mobiel (anders zoomt iOS). Focus-ring altijd zichtbaar.
- **Card**: alleen gebruiken als elevatie echte hierarchie communiceert, niet als default wrapper. Concentrische border-radius (buiten = binnen + padding). Geen kaartensoep: gelijke, geborderde, gekopte kaarten voor alles betekent dat niets belangrijk is.
- **Modal/dialog**: gecentreerd, `transform-origin: center` (uitzondering op de origin-regel). Scrim erachter. Alleen voor een korte, zelfstandige taak; zodra hij intern moet scrollen is de vormfactor fout, escaleer naar drawer of workspace.
- **Drawer/side-panel**: voor meerdere instellingen of detailweergave met context-behoud. Anchor op de trigger, `transform-origin` naar de kant waar hij vandaan komt. Enter/exit langs hetzelfde pad.
- **Popover/tooltip**: schaalt vanuit de trigger, nooit vanuit het midden. Viewport-aware (flip/clamp), nooit een custom absolute div met hardcoded offset. Tooltip is nooit de enige drager van essentiele informatie. Eerste tooltip krijgt delay, volgende in dezelfde interactie niet.
- **Table**: geen alternerende zebra als vervanging voor echte hierarchie. Cijfers rechts uitgelijnd met tabular-nums. Brede tabellen krijgen een eigen `overflow-x:auto`-container, nooit de pagina zelf.
- **Tabs**: op smalle viewport wrappen (`flex-wrap`), nooit horizontaal scrollen. Actieve tab optisch evident, geen kleurtransitie via losse properties.
- **Nav/sidebar**: navigatie op een lijn, hoogte begrensd. Accordion-secties: alleen de actieve groep open. Labels specifiek naar inhoud ("Facturen"), geen vage koepelterm ("Overzicht").
- **Toast**: enter en exit langs dezelfde as. Interruptible via CSS transitions, niet keyframes (toasts worden snel achter elkaar toegevoegd). Timer pauzeert als het tabblad verborgen is.
- **Empty-state**: een zin plus een concrete actie, compact. Nooit een lege kaart als vulling, nooit een nep-stepper met naamloze bollen die een proces suggereert dat niet bestaat.
- **Skeleton/loading**: alleen tonen als er echt async werk is. Shimmer-richting consistent. Geen skeleton die langer draait dan de echte laadtijd rechtvaardigt.
- **Chart-container**: genoeg ruimte voor titel, assen, labels en tooltip. Nooit een native `title=`-tooltip voor betekenisdragende data. Zie sectie Data-viz.

## Vormfactor en overflow

| Level | Vorm | Voor |
|---|---|---|
| L1 | Inline | simpele waarde, 1 actie, kleine state-change |
| L2 | Popover | korte instelling, beperkte keuze, contextuele actie |
| L3 | Modal | korte zelfstandige workflow, beperkte config |
| L4 | Side panel | meerdere instellingen, detailweergave, context behouden |
| L5 | Full workspace | complexe workflow, meerdere config-lagen, tabellen, builder |

Regel: meer dan een handvol velden of meerdere conceptuele workflows hoort niet in een L3-modal. Een modal die intern verticaal moet scrollen of horizontaal knelt, is een verkeerd gekozen vormfactor. Escaleer naar L4/L5 met een stabiel navigatieframe plus een ruime workspace.

Harde overflow-regels:
- Geen horizontale scrollbar voor normale controls: buttons, dropdowns, tabs, formulieren, navigatie, gewone card-content.
- Horizontale scroll alleen voor intrinsiek horizontale datasets (brede tabellen, tijdreeksen), in een eigen `overflow-x:auto`-container.
- Geen scrollbare card als normale dashboardcomponent, geen nested scrolling tenzij functioneel noodzakelijk.
- Responsive is herflow, niet krimpen: `[A][B][C]` wordt `[A][B]` boven `[C]`, nooit `[A][B][C...]` afgekapt. Media queries die alleen dimensies verkleinen zonder de layout te herstructureren zijn een bug.
- Past content niet: eerst herflow, dan component vergroten, dan layout/kolommen veranderen, dan vormfactor escaleren. Content-region scroll is het laatste redmiddel.
- Belangrijke tekst verdwijnt nooit door ellipsis/clipping tenzij de volledige waarde elders bereikbaar is en de truncatie geen betekenis wegneemt.

## Typografie, kleur, spacing

- Type-scale met semantische namen, geen losse one-off maten. Headingniveaus dalen strikt met het niveau, nooit een lager niveau groter dan een hoger op dezelfde pagina.
- Regelbreedte long-form tekst circa 60-75 tekens (`max-w-xl`/`max-w-2xl`, of `65ch`).
- Tabular-nums op elk getal dat verandert (timers, tellers, prijzen).
- Line-height per rol: headings circa 1.1, body 1.5-1.6, unitless.
- Kleur via tokens, geen losse hexes verspreid door componenten. Een systeem: OKLCH voor perceptuele uniformiteit, of Tailwind `dark:`-variant/CSS-variabelen, een strategie per project.
- Neutrals met een lichte hue-bias (nooit puur `#000000`/`#ffffff`), max 1 accentkleur consistent door de hele pagina (Color Consistency Lock).
- Contrastvloer: WCAG AA 4.5:1 body, 3:1 grote tekst (circa 24px+).
- Spacing via layout (grid/gap), niet via losse margins per element. Een corner-radius-schaal voor de hele pagina (Shape Consistency Lock).

## Motion

- Animeer alleen met een reden: hierarchie, storytelling, feedback of state-transition. "Ziet er cool uit" is geen reden.
- Nooit animeren op een toetsenbord-actie of iets dat 100+ keer per dag wordt gezien (command palette, sneltoetsen). Occasioneel (modal, toast) krijgt standaard animatie, zeldzaam (onboarding) mag delight toevoegen.
- `prefers-reduced-motion` is verplicht boven een lichte motion-intensiteit: vervang slide/spring/parallax door een korte cross-fade of statische transitie, nooit door niets.
- Animeer alleen `transform` en `opacity` (GPU-compositable). Nooit `transition: all`. Geen `ResponsiveContainer` of meet-loops die op elke resize herberekenen: gebruik viewBox-geschaalde SVG met vaste/afgeronde coords.
- Interruptible: CSS transitions voor interactieve state, keyframes alleen voor eenmalige gescripte sequenties. Start een onderbroken animatie altijd vanaf de huidige waarde, nooit vanaf de doelwaarde.
- Enter start niet vanaf `scale(0)` (niets verschijnt uit het niets); begin bij `scale(0.95)` plus opacity. Exit subtieler dan enter (kleinere translate, kortere duur).
- Duur: knop-feedback 100-160ms, tooltip/popover 125-200ms, dropdown 150-250ms, modal/drawer 200-500ms. UI-animatie blijft onder 300ms.
- Animatie-woordenschat: gebruik de exacte term (stagger, spring, rubber-band, morph, crossfade, origin-aware) in plaats van een vage omschrijving; zie `animation-vocabulary` voor de volledige lijst.

## Data-viz

- Chart-type volgt uit de data-relatie, niet uit smaak: trend over tijd = lijn, vergelijking = staaf, ranking = horizontale staaf, part-to-whole = gestapelde staaf/treemap, distributie = histogram/boxplot, correlatie = scatter. Geen taart tenzij expliciet gevraagd en dan max 4 segmenten.
- Data-ink ratio hoog: geen top/rechter-as, geen legenda (label direct op de data), geen 3D, geen gridlines behalve zwak horizontaal (opacity 0.08-0.12) als precisie nodig is.
- As-lijnen spannen alleen de databereik (range-frame), niet gedwongen bij 0 tenzij het een staafdiagram is (staven starten altijd bij 0).
- Direct labeling in plaats van een losse legenda. Grijs als default kleur, een enkele accentkleur voor de belangrijkste reeks. Geen dual-axis (gebruik small multiples).
- Nooit een native browser-tooltip (`title=`) voor belangrijke analytics. Een gedeelde custom tooltip/popover met viewport-awareness en collision-detection.
- Titel benoemt de bevinding ("Omzet steeg 23%"), niet de as-beschrijving ("Omzet per kwartaal"). Vergelijkingscontext verplicht: een referentielijn, band, of vorige periode.

## Anti-AI-slop (hard)

Vermijd deze signaturen tenzij expliciet gevraagd:

- Generieke cream/beige achtergrond plus terracotta/brass-accent plus serif als default premium-palet.
- Paars-blauwe gradient hero, glow-effecten, neon-outerglow.
- Inter of Space Grotesk als automatische standaardfont; geen serif zonder reden (nooit consequent dezelfde serif herhalen).
- Emoji als sectie-markers of decoratieve bullets.
- Alles gecentreerd; drie identieke feature-cards naast elkaar.
- `rounded-lg` overal zonder consistente radius-schaal; een gekleurde accent-rail/border op elke kaart.
- Subtitels of helptekst onder elke heading/label/menu-item bij wijze van default; een heading die zichzelf herhaalt in de ondertitel.
- Em-dash of en-dash als separator waar dan ook zichtbaar: headline, label, body, quote, caption, button. Een gewone hyphen is het enige toegestane streepje.
- Sectienummer-eyebrows (`00 / INDEX`, `001 - Capabilities`), versielabels in de hero (`BETA`, `v0.6`), decoratieve statusdots zonder echte betekenis, scroll-cues (`Scroll to explore`).
- Nep-productscreenshots opgebouwd uit divs, hand-getekende decoratieve SVG-iconen, gebroken Unsplash-links.
- Generieke naamvoorbeelden ("John Doe"), generieke merknamen ("Acme"), fake-perfecte cijfers (99.99%).
- Een layout voor alle data-states: een lege state die de volle layout toont met gaten in plaats van een gerichte empty-state-flow.
- Permanente open formulieren in plaats van een trigger die een compact paneel opent.

## Mega-kritische keuringslat (frontend-fase)

Een onafhankelijke evaluator vinkt dit af voor een frontend-fase ACCEPT krijgt. Elk punt is toetsbaar, geen "ziet er goed uit".

1. Verse render-screenshot gemaakt NA een schone reload, met vooraf opgeschreven verwachting (een concreet getal, label of positie) voordat er gekeken wordt.
2. Zoom-screenshot van precies het gewijzigde gebied; elke mismatch tussen verwachting en screenshot expliciet benoemd, geen oordeel over een gebied buiten de screenshot.
3. Browserconsole leeg (geen errors, geen onafgehandelde warnings) op de geverifieerde pagina.
4. Meerdere viewports getest (mobiel, tablet, desktop): herflow klopt, geen clipping, geen verborgen controls, geen horizontale scroll op normale UI.
5. Licht en donker beide getest met een echte screenshot per modus, niet aangenomen vanuit de tokens.
6. Keyboard-focus zichtbaar op elk interactief element, tab-volgorde logisch, geen focus-trap zonder uitweg.
7. Geen betekenisdragende tekst afgekapt door ellipsis/overflow zonder dat de volledige waarde elders bereikbaar is.
8. Contrast WCAG AA geverifieerd voor tekst tegen zijn achtergrond, in beide themamodi.
9. Geen skeleton/loading-state getoond als er geen echt async werk achter zit.
10. Hover/interactie/tooltip-claims alleen bewezen met een screenshot waarop het zichtbaar is of een DOM-read van de tekst, nooit aangenomen.
11. Anti-slop-tells uit de sectie hierboven afwezig: gecontroleerd op em-dash, generieke gradient-hero, sectienummer-eyebrows, decoratieve dots, nep-screenshots.
12. `prefers-reduced-motion` gerespecteerd: geverifieerd dat animatie afvlakt naar cross-fade of statisch, niet alleen beweerd.
13. Elke chart in de fase is langs `data-visualization` en `tufte-data-viz` gehaald voor ACCEPT.
