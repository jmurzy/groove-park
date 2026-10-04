# Heavenly API Worker

The Heavenly API is a Cloudflare Worker that serves Liftie status and fronts one SQLite-backed
Durable Object named `leaderboard-global` for the shared leaderboard. Recovery operations are
deferred.

## Requirements

- Node.js 24.21.0
- npm 11

## Commands

```sh
npm install
npm test
npm run typecheck
npm run dev
```

The generated `workerConfiguration.d.ts` is intentionally untracked. Generate it with
`npm run cf-typegen` whenever `wrangler.jsonc` changes.

`TZ` is an IANA timezone name used to create explicit offset-bearing leaderboard timestamps. Set
it in `.env` for local development and as a Cloudflare Worker secret for deployment.

## Database migrations

`wrangler.jsonc` declaratively exports the SQLite-backed `GlobalLeaderboard` Durable Object class.
SQL table changes are versioned in `src/leaderboard/durableObject.ts` and recorded in
`_sql_schema_migrations`. Add a new, strictly increasing migration entry for every persistent
schema change; never edit an applied one.

## Local API

- `GET /api/leaderboard` returns the current top ten as `{ "topEntries": [...] }`.
- `POST /api/leaderboard/qualify` accepts `{ "totalScore": number }`.
- `POST /api/leaderboard/submissions` accepts a validated immutable round submission.
- `GET /api/liftie/resort/:resortName` proxies the matching Liftie resort with the
  `LIFTIE_USER_AGENT` Worker secret, normalizes its lift counts, and caches successful responses
  for 60 seconds. Resort names must be lowercase `a-z`, `0-9`, and `-`; upstream or parsing
  failures return `503` with an `unknown` state.

The Worker validates payload shape, a normalized player name of up to 12 characters, total score,
rider kind, and the `ags` or `web` platform.

## Cabinet limits and observability

Every request is first limited to 60 requests per 60 seconds per Cloudflare connecting IP, then
must include the generated UUID `X-Installation-Id` and is additionally limited to 20 requests per
60 seconds per installation. Missing or invalid installation IDs return
`400 MISSING_INSTALLATION_ID` or `400 INVALID_INSTALLATION_ID`; exhausted limits return
`429 RATE_LIMITED` with `Retry-After: 60`. Rejected or limited requests are stopped before the
Durable Object is invoked.

Every response includes `X-Request-Id`. The Worker emits JSON request-completion logs containing
only the method, matched route pattern, request ID, status, rounded latency, and outcome. It never
logs player names, round IDs, installation IDs, IP addresses, or submission bodies.

Scores are accepted as opaque integer totals. The Worker can validate payload bounds and rank a
submitted total, but cannot prove client-observed motion measurements or reconstruct scoring
arithmetic from that total alone.

For the initial deployment, copy `.env.example` to `.env`, replace its placeholder values, then
upload the Worker and its required secrets together:

```sh
npx wrangler deploy --secrets-file .env
```

After the Worker exists, update an individual deployed secret with `npx wrangler secret put <KEY>`.
The `.env` file is also used by local `wrangler dev`; it is ignored and must not be committed.
