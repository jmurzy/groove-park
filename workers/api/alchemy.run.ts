import * as Alchemy from "alchemy";
import { adopt } from "alchemy/AdoptPolicy";
import * as Cloudflare from "alchemy/Cloudflare";
import * as Config from "effect/Config";
import * as Effect from "effect/Effect";

import type { GlobalLeaderboard } from "./src/leaderboard/durableObject";

const ROOT_ZONE_NAME = "gunbarrelhaus.com";

const zone = Cloudflare.Zone.Zone("GunbarrelHausZone", {
	name: ROOT_ZONE_NAME,
}).pipe(adopt(true));

export const apiWorker = Cloudflare.Worker("GameApi", {
	name: "game-api",
	main: "./src/index.ts",
	compatibility: { date: "2026-09-25" },
	workersDev: false,
	domain: {
		name: `api.game.${ROOT_ZONE_NAME}`,
		zoneName: ROOT_ZONE_NAME,
	},
	env: {
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
		GAME_ORIGIN: `https://game.${ROOT_ZONE_NAME}`,
		LIFTIE_USER_AGENT: Config.Redacted("LIFTIE_USER_AGENT"),
		TZ: "UTC",
	},
}).pipe(adopt(true));

export type ApiWorkerEnv = Cloudflare.InferEnv<typeof apiWorker>;

export default Alchemy.Stack(
	"game-api",
	{ providers: Cloudflare.providers(), state: Cloudflare.state() },
	Effect.gen(function* () {
		const managedZone = yield* zone;
		const api = yield* apiWorker;
		return {
			apiUrl: api.url,
			zoneId: managedZone.zoneId,
		};
	}),
);
