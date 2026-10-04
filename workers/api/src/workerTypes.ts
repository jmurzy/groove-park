import type { Context } from "hono";

import type { RequestVariables } from "./utils/observability";

export type WorkerEnv = Env & {
	LIFTIE_USER_AGENT: string;
	TZ: string;
	INSTALLATION_RATE_LIMIT: RateLimit;
	IP_RATE_LIMIT: RateLimit;
};
export type WorkerApp = import("hono").Hono<{ Bindings: WorkerEnv; Variables: RequestVariables }>;
export type WorkerContext = Context<{ Bindings: WorkerEnv; Variables: RequestVariables }>;
