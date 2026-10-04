import type { Context } from "hono";
import { routePath } from "hono/route";

import type { WorkerEnv } from "../workerTypes";

export interface RequestVariables {
	requestId: string;
}

type ObservedContext = Context<{ Bindings: WorkerEnv; Variables: RequestVariables }>;

export function observeRequest(context: ObservedContext, durationMs: number): void {
	const status = context.res.status;
	const outcome = status === 429 ? "rate_limited" : status >= 500 ? "error" : status >= 400 ? "rejected" : "success";
	const event = {
		event: "http_request",
		method: context.req.method,
		route: routePath(context, -1),
		requestId: context.get("requestId"),
		status,
		durationMs: Math.round(durationMs),
		outcome,
	};
	if (outcome === "success") console.info(JSON.stringify(event));
	else console.warn(JSON.stringify(event));
}
