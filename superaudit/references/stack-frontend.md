# Stack-appendix: SPA-frontends (Vue/React + TypeScript)

## Contract met de backend

- Eén getypte `Api`-interface; de HTTP-laag doet alleen I/O en fouttranslatie; adapters
  zijn pure, unit-geteste vormvertaling; de mock-implementatie blijft de interface
  satisfyen (typecheck vangt dat, als hij draait).
- Enum-waarden (statussen, rollen) komen uit de backend of een gedeeld type, nooit
  hardcoded strings in componenten.
- Foutstaat is zichtbaar; geen automatische retry op 4xx; auth-guard via een `me`-endpoint;
  CSRF-token meegestuurd op writes bij session-auth.
- Proxy-prefixen (`/api`, `/admin`, ...) en `base` kloppen met de reverse proxy in prod;
  een route buiten die prefixen komt niet aan.

## Reactiviteit en state

- `computed` zonder side effects; `watch` met `immediate` waar de eerste waarde telt;
  `v-if` op een veld dat pas na een fetch bestaat; optionele ketens (`?.`) die `undefined`
  in een berekening laten lopen.
- Query-caches (TanStack) met de juiste keys en invalidatie na een mutatie; stale data na
  een write is een finding.
- Persistente state (`localStorage`, `sessionStorage`): geen tokens, geen persoonsgegevens;
  wrap in try/catch; correct renderen zonder opgeslagen waarde.

## UX-contract

- Tellingen in koppen komen overeen met wat bereikbaar is; een `slice`/cap zonder
  overloop-route terwijl de kop het totaal toont is een P2.
- Bulk-acties werken op de getoonde set; drempels ("minstens 3 gelijke acties") tegen de
  zichtbare rijen, en dat is bewust of niet.
- Een verwijderd veld/knop/endpoint laat geen instelling achter die nergens meer gezet
  kan worden; docstrings en help-teksten die naar het oude pad verwijzen mee.

## Veiligheid

- Alleen `v-html`/`innerHTML`/`dangerouslySetInnerHTML` op gesanitiseerde inhoud
  (DOMPurify met expliciete config).
- Geen backend-permissielogica in de client als bewijs van security; de backend beslist.

## Tests en tooling

- Typecheck (`vue-tsc`/`tsc`) en unit-tests (vitest/jest) draaien vaak niet in CI; dan
  lokaal draaien en dat in "Bewijs" zetten.
- Nieuwe adapter, nieuwe berekening in een component, nieuwe cap: elk een test met de
  concrete verwachting (aantal rijen, label, link).

## CSS-specificiteit (veel gemiste "bugs")

- Een nieuwe `:hover`/`:focus-within`-regel met hogere specificiteit overschrijft een
  state-klasse (`--busy`, `--active`) die later in de cascade minder specifiek is: de
  state verdwijnt zodra de muis erover staat. Check de specificiteit, niet alleen de
  volgorde.
- `transition` op een property die nergens gezet wordt is dood; `!important` is een
  symptoom.
