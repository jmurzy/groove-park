# Heavenly API Worker

The Heavenly API is a Cloudflare Worker that serves Liftie status and fronts one SQLite-backed
Durable Object named `leaderboard-global` for the shared leaderboard. Godot client integration, Turnstile,
rate limits, deployment configuration, and recovery operations are deferred.

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
SQL table changes are separately versioned in `src/leaderboard/schema.ts` and recorded in
`_sql_schema_migrations`. Add a new, strictly increasing migration entry for every persistent
schema change; never edit an applied one.

## Local API

- `GET /api/leaderboard` returns the current top ten and server time.
- `POST /api/leaderboard/qualify` accepts `{ "totalScore": number }`.
- `POST /api/leaderboard/submissions` accepts a validated immutable round submission.
- `GET /api/liftie/resort/:resortName` proxies the matching Liftie resort with the
  `LIFTIE_USER_AGENT` Worker secret, normalizes its lift counts, and caches successful responses
  for 60 seconds. Resort names must be lowercase `a-z`, `0-9`, and `-`; upstream or parsing
  failures return `503` with an `unknown` state.

The Worker validates payload shape, a normalized player name of up to 12 characters, total score,
rider kind, and the `ags` or `web` platform.

Configure the required Worker secrets before deployment:

```sh
npx wrangler secret put LIFTIE_USER_AGENT
npx wrangler secret put TZ
```

For local `wrangler dev`, copy `.env.example` to `.env` and replace the placeholder value. The
actual `.env` file is ignored and must not be committed.
