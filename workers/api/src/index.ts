import { Hono, type MiddlewareHandler } from "hono";
import { cors } from "hono/cors";

import { getGame } from "./game/handlers";
import { getLeaderboard, qualifyLeaderboard, resetLeaderboard, submitLeaderboard } from "./leaderboard/handlers";
import { getResort } from "./liftie/handlers";
import { error } from "./utils/http";
import { observeRequest, type RequestVariables } from "./utils/observability";
import { limitInstallationRequest, limitIpRequest } from "./utils/rateLimit";
import type { ApiWorkerEnv } from "../alchemy.run";

export { GlobalLeaderboard } from "./leaderboard/durableObject";

const app = new Hono<{ Bindings: ApiWorkerEnv; Variables: RequestVariables }>();

app.use("/api/*", async (context, next) => {
	const startedAt = performance.now();
	const requestId = crypto.randomUUID();
	context.set("requestId", requestId);
	await next();
	context.header("X-Request-Id", requestId);
	observeRequest(context, performance.now() - startedAt);
});

const limitRequest: MiddlewareHandler<{
	Bindings: ApiWorkerEnv;
	Variables: RequestVariables;
}> = async (context, next) => {
	const response =
		(await limitIpRequest(context.req.raw, context.env)) ??
		(await limitInstallationRequest(context.req.raw, context.env));
	if (response) return response;
	await next();
};

app.use("/api/*", (context, next) =>
	cors({
		origin: context.env.GAME_ORIGIN,
		allowHeaders: ["Accept", "Content-Type", "X-Installation-Id"],
		allowMethods: ["GET", "POST", "OPTIONS"],
		exposeHeaders: ["X-Request-Id"],
		maxAge: 86400,
	})(context, next),
);
app.use("/api/*", limitRequest);

app.get("/", getGame);

app.get("/api/liftie/resort/:resortName", getResort);

app.get("/api/leaderboard", getLeaderboard);
app.get("/api/reset", resetLeaderboard);
app.post("/api/leaderboard/qualify", qualifyLeaderboard);
app.post("/api/leaderboard/submissions", submitLeaderboard);

app.notFound(() => error("NOT_FOUND", 404));

app.onError((exception, context) => {
	console.error(
		JSON.stringify({
			event: "http_exception",
			operation: "worker.fetch",
			requestId: context.get("requestId"),
			error: exception instanceof Error ? exception.name : "UNKNOWN",
		}),
	);
	return error("INTERNAL_ERROR", 500, { "X-Request-Id": context.get("requestId") });
});

export default app;
