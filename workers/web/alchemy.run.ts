import * as Alchemy from "alchemy";
import { adopt } from "alchemy/AdoptPolicy";
import * as Cloudflare from "alchemy/Cloudflare";
import * as Config from "effect/Config";
import * as Effect from "effect/Effect";

const rootZoneName = "gunbarrelhaus.com";

const zone = Cloudflare.Zone.Zone("GunbarrelHausZone", {
	name: rootZoneName,
}).pipe(adopt(true));

const gameReleases = Cloudflare.R2.Bucket.ref("GameReleases", {
	stack: "game-api",
});

const webWorker = Cloudflare.Website.Vite("GameWeb", {
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
		GAME_RELEASES: gameReleases,
		EXAMPLE_MESSAGE_2: Config.String("EXAMPLE_MESSAGE_2"),
		EXAMPLE_SECRET_2: Config.Redacted("EXAMPLE_SECRET_2"),
	},
	domain: {
		name: `game.${rootZoneName}`,
		zoneName: rootZoneName,
	},
}).pipe(adopt(true));

export type WebWorkerEnv = Cloudflare.InferEnv<typeof webWorker>;

export default Alchemy.Stack(
	"game-web",
	{ providers: Cloudflare.providers(), state: Cloudflare.state() },
	Effect.gen(function* () {
		yield* zone;
		const worker = yield* webWorker;
		return { url: worker.url };
	}),
);
