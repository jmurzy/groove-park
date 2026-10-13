# API Worker

The Heavenly API is a Cloudflare Worker that serves Liftie status, and fronts one SQLite-backed 
Durable Object named `leaderboard-global` for the shared leaderboard.

`alchemy.run.ts` adopts the `gunbarrelhaus.com` zone and manages the API Worker domain, rate
limits, and secrets. Its fixed resource names and adoption policy preserve an existing
`game-api` Worker and `GlobalLeaderboard` Durable Object namespace when present on the first
deploy. It does not manage DNS records that are not explicitly declared in the stack. Review
`just plan` before production deploys. The API deployment workflow requires the
`LIFTIE_USER_AGENT` GitHub Actions secret in addition to the Cloudflare credentials.

## Production secrets

Configure these as GitHub Actions secrets, restricted to the production repository or environment:

- `CLOUDFLARE_ACCOUNT_ID`: the target Cloudflare account identifier. It is used only by deployment
  workflows.
- `CLOUDFLARE_API_TOKEN`: a token restricted to that account, with only the permissions required to
  deploy the declared Worker resources. Review `just plan` when infrastructure changes and narrow
  the token scope accordingly.
- `LIFTIE_USER_AGENT`: the sole Worker secret. It is supplied only to the API deployment workflow,
  not Web release publishing.

`GAME_ORIGIN` is public deployment configuration in `alchemy.run.ts`, not a secret.

## Commands

```sh
just install
just check
just dev
```

The tests deploy `alchemy.run.ts` to local workerd emulation, including the R2 bucket and
SQLite-backed Durable Object. Wrangler remains installed only for the immutable R2 object uploads
in the web release workflow.

`TZ` is fixed to `UTC` for explicit offset-bearing leaderboard timestamps.

## Database migrations

`alchemy.run.ts` declaratively exports the SQLite-backed `GlobalLeaderboard` Durable Object class.
SQL table changes are versioned in `src/leaderboard/durableObject.ts` and recorded in
`_sql_schema_migrations`. Add a new, strictly increasing migration entry for every persistent
schema change; never edit an applied one.

## Local API

- `GET /api/leaderboard` returns the current top ten as `{ "topEntries": [...] }` and uses
  `Cache-Control: no-store` so post-submission reads are fresh.
- `POST /api/leaderboard/qualify` accepts `{ "totalScore": number }`.
- `POST /api/leaderboard/submissions` accepts a validated immutable round submission and returns
  `{ "accepted": true, "rank": number }`. Fetch the leaderboard separately for board entries.
- `GET /api/liftie/resort/:resortName` proxies the matching Liftie resort with the
  `LIFTIE_USER_AGENT` Worker secret, returning Liftie's validated resort response and caching
  successful responses for 60 seconds. Resort names must be lowercase `a-z`, `0-9`, and `-`;
  upstream or parsing failures return an empty, non-cacheable `503` response.

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
just plan
just deploy
```

The `.env` file is also used by local `alchemy dev`; it is ignored and must not be committed.
