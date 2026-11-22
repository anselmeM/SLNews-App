# Platform improvements — task list

**Goal:** reduce cross-repo drift and make the mobile backend boundary explicit without a monorepo rewrite.

**Status:** all tasks complete. Canonical contract: https://github.com/anselmeM/SLNews-Web/blob/master/contracts/openapi.json

| # | Task | Repo | Status |
|---|---|---|---|
| 1 | Canonical mobile API OpenAPI contract and fixtures | Web | [x] |
| 2 | Web contract drift tests and spec validation | Web | [x] |
| 3 | App contract fixture test for AdUnit/event payload | App | [x] |
| 4 | Mobile API boundary and ownership documentation | Web + App | [x] |
| 5 | Prisma schema migration policy and CI validation | Web | [x] |

## Acceptance criteria

### 1. Canonical contract
- `contracts/openapi.json` covers the sponsorship mobile endpoints.
- `contracts/fixtures/` contains one AdUnit and one event fixture.
- Contract version, ownership and change policy are documented.

### 2. Web contract tests
- Tests assert the OpenAPI paths exist and the fixture field set matches the AdUnit schema.
- Tests assert the fixture matches the shape returned by the Web mapper.
- CI parses the OpenAPI document; a malformed contract fails the build.

### 3. App contract fixture test
- Flutter test parses the canonical AdUnit fixture through `AdUnit.fromSponsorship`.
- Assertions cover the field set and required values.
- Tracker event assertions cover `id`, `type`, `eventId` and optional `token`.

### 4. Boundary documentation
- One document states which backend owns which mobile endpoint.
- Base URLs, auth rules, versioning and legacy event behavior are explicit.
- App docs link to the canonical contract.

### 5. Schema migration policy
- Policy documents the current `db push` workflow, preview/apply gate and the path to real migrations.
- `prisma validate` runs in CI on every schema change.

## Verification

```powershell
# Web
npx tsc --noEmit
npm run lint
npm test -- --run

# App
flutter analyze --no-pub
flutter test test/contracts
```
## Result

- Canonical contract: `SLNews-Web/contracts/openapi.json` + fixtures.
- Web tests parse the contract and compare the AdUnit mapper/fixture.
- App test parses the canonical fixture and caught a real drift: `AdUnit.toJson` was omitting `placement`; it now includes it.
- Mobile API ownership and base URLs are documented in `SLNews-Web/docs/MOBILE-API-BOUNDARY.md`.
- Schema workflow/migration policy is documented in `SLNews-Web/docs/SCHEMA-MIGRATIONS.md`; CI validates the Prisma schema.
## Phase 2 — generated fixture and migration baseline

| Task | Status |
|---|---|
| Generate the Dart contract fixture from Web `openapi.json` | [x] |
| Replace manually copied App fixtures with the generated file | [x] |
| Add a reproducible generator check/test | [x] |
| Create an initial Prisma migration baseline | [x] |
| Switch the database workflow from `db push` to `migrate deploy` | [x] |
| Baseline the existing production database | [x] |

The generated contract is `test/contracts/mobile_contract.g.dart`; regenerate
it from the Web repo with `npm run contracts:generate`.
