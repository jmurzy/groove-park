import * as Alchemy from "alchemy";
import { adopt } from "alchemy/AdoptPolicy";
import * as Cloudflare from "alchemy/Cloudflare";
import * as Config from "effect/Config";
import * as Effect from "effect/Effect";

import type { GlobalLeaderboard } from "./src/leaderboard/durableObject";

const rootZoneName = "gunbarrelhaus.com";

const zone = Cloudflare.Zone.Zone("GunbarrelHausZone", {
	name: rootZoneName,
}).pipe(adopt(true));

const gameReleases = Cloudflare.R2.Bucket("GameReleases", {
	name: "game-releases",
	// Keep the r2.dev endpoint private; the declared custom domain remains public.
	publicAccess: false,
	domains: [{ name: `assets.game.${rootZoneName}`, zone: rootZoneName, minTLS: "1.2" }],
	cors: [
		{
			allowedMethods: ["GET", "HEAD"],
			allowedOrigins: [`https://game.${rootZoneName}`],
			allowedHeaders: ["range"],
			exposeHeaders: ["etag", "content-range"],
			maxAgeSeconds: 86400,
		},
	],
}).pipe(adopt(true));

export const apiWorker = Cloudflare.Worker("GameServer", {
	name: "game-server",
	main: "./src/index.ts",
	compatibility: { date: "2026-09-25" },
	workersDev: false,
	domain: {
		name: `api.game.${rootZoneName}`,
		aliases: [`game.${rootZoneName}`],
		zoneName: rootZoneName,
	},
	env: {
		GAME_RELEASES: gameReleases,
		LEADERBOARD: Cloudflare.DurableObject<GlobalLeaderboard>("LEADERBOARD", {
			className: "GlobalLeaderboard",
		}),
		INSTALLATION_RATE_LIMIT: Cloudflare.RateLimit("INSTALLATION_RATE_LIMIT", {
			namespaceId: 1001,
			simple: { limit: 20, period: 60 },
		}),
		IP_RATE_LIMIT: Cloudflare.RateLimit("IP_RATE_LIMIT", {
			namespaceId: 1002,
			simple: { limit: 60, period: 60 },
		}),
		GAME_API_ORIGIN: `https://api.game.${rootZoneName}`,
		GAME_ORIGIN: `https://game.${rootZoneName}`,
		GAME_ASSET_ORIGIN: `https://assets.game.${rootZoneName}`,
		LIFTIE_USER_AGENT: Config.Redacted("LIFTIE_USER_AGENT"),
		TZ: "UTC",
	},
}).pipe(adopt(true));

export type ApiWorkerEnv = Cloudflare.InferEnv<typeof apiWorker>;

export default Alchemy.Stack(
	"game",
	{ providers: Cloudflare.providers(), state: Cloudflare.state() },
	Effect.gen(function* () {
		const managedZone = yield* zone;
		const releases = yield* gameReleases;
		const api = yield* apiWorker;
		return { apiUrl: api.url, gameReleaseBucket: releases.bucketName, zoneId: managedZone.zoneId };
	}),
);
