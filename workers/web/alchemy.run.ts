import * as Alchemy from "alchemy";
import { adopt } from "alchemy/AdoptPolicy";
import * as Cloudflare from "alchemy/Cloudflare";
import * as Config from "effect/Config";
import * as Effect from "effect/Effect";

const ROOT_ZONE_NAME = "gunbarrelhaus.com";
const GAME_ASSETS_DOMAIN = `assets.game.${ROOT_ZONE_NAME}`;

const zone = Cloudflare.Zone.Zone("GunbarrelHausZone", {
	name: ROOT_ZONE_NAME,
}).pipe(adopt(true));

const gameReleases = Effect.gen(function* () {
	const stage = yield* Alchemy.Stage;

	if (stage !== "production") {
		// Local Workers proxy this real bucket instead of using the R2 emulator.
		return yield* Cloudflare.R2.Bucket.ref("GameReleases", {
			stage: "production",
		});
	}

	return yield* Cloudflare.R2.Bucket("GameReleases", {
		name: "game-releases",
		// Keep the r2.dev endpoint private; the declared custom domain remains public.
		publicAccess: false,
		domains: [
			{ name: GAME_ASSETS_DOMAIN, zone: ROOT_ZONE_NAME, minTLS: "1.2" },
		],
		cors: [
			{
				allowedMethods: ["GET", "HEAD"],
				allowedOrigins: [
					`https://game.${ROOT_ZONE_NAME}`,
					"http://localhost:3000",
				],
				allowedHeaders: ["range"],
				exposeHeaders: ["etag", "content-range"],
				maxAgeSeconds: 86400,
			},
		],
	}).pipe(adopt(true));
});

const webWorker = Effect.gen(function* () {
	const stage = yield* Alchemy.Stage;
	const gameApi = yield* Cloudflare.Worker.ref("GameApi", {
		stack: "game-api",
		stage,
	});

	return yield* Cloudflare.Website.Vite("GameWeb", {
		name: "game-web",
		rootDir: ".",
		compatibility: {
			date: "2025-09-02",
			flags: ["nodejs_compat"],
		},
		workersDev: false,
		dev: {
			port: 3000,
			strictPort: true,
		},
		env: {
			GAME_API_URL: gameApi.url.as<string>(),
			GAME_RELEASES_URL: `https://${GAME_ASSETS_DOMAIN}`,
			GAME_RELEASES: gameReleases,

			EXAMPLE_MESSAGE_2: Config.String("EXAMPLE_MESSAGE_2"),
			EXAMPLE_SECRET_2: Config.Redacted("EXAMPLE_SECRET_2"),
		},
		domain: {
			name: `game.${ROOT_ZONE_NAME}`,
			zoneName: ROOT_ZONE_NAME,
		},
	}).pipe(adopt(true));
});

export type WebWorkerEnv = Cloudflare.InferEnv<typeof webWorker>;

export default Alchemy.Stack(
	"game-web",
	{ providers: Cloudflare.providers(), state: Cloudflare.state() },
	Effect.gen(function* () {
		yield* zone;
		yield* gameReleases;
		const worker = yield* webWorker;
		return { url: worker.url };
	}),
);
