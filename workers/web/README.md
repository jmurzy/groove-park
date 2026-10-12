# Web Worker

The Heavenly Web Worker is a web application deployed to the `game-web` Cloudflare Worker. 
It serves the web experience at `game.gunbarrelhaus.com`.

## Web hosting

`alchemy.run.ts` adopts the existing `gunbarrelhaus.com` zone and manages the `game-web` Worker,
its client assets, the `game.gunbarrelhaus.com` custom domain, and the `game-releases` R2 bucket.
The bucket owns the `assets.game.gunbarrelhaus.com` custom domain and CORS policy for immutable
game assets. Its fixed resource names and adoption policy preserve the existing zone, Worker, and
bucket when present on the first deploy. It does not manage DNS records that are not explicitly
declared in the stack. Review `just plan` before production deploys.

Alchemy's Vite resource builds and deploys the TanStack Start server bundle and client assets.
Add future Cloudflare bindings and secrets to `alchemy.run.ts`.

## Production secrets

Configure these as GitHub Actions secrets, restricted to the production repository or environment:

- `CLOUDFLARE_ACCOUNT_ID`: the target Cloudflare account identifier. It is used only by deployment
  workflows.
- `CLOUDFLARE_API_TOKEN`: a token restricted to that account, with only the permissions required to
  deploy the declared Worker resources. Review `just plan` when infrastructure changes and narrow
  the token scope accordingly.

`EXAMPLE_MESSAGE_2` is public Worker configuration and `EXAMPLE_SECRET_2` is a Worker secret
declared in `alchemy.run.ts`. Replace or remove these example bindings before using them in
production.

## Commands

```sh
just install
just check
just dev
```

`just dev` runs the local Cloudflare Worker through Alchemy with Vite hot module replacement at
`http://localhost:3000`. Vite generates `src/routeTree.gen.ts` during development and builds; run
`just generate-routes` to refresh it manually.

## Deployments

Review the production infrastructure changes, then deploy with the configured Cloudflare
credentials:

```sh
just plan
just deploy
```

For local development, copy `.env.example` to `.env` and replace its placeholder values. The
`.env` file is used by `alchemy dev`; it is ignored and must not be committed.
