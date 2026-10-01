import { error, json } from "../utils/http";
import type { WorkerContext } from "../workerTypes";

const LIFTIE_URL = "https://liftie.info";
const LIFTIE_CACHE_SECONDS = 60;

export interface ResortResponse {
	status: "open" | "hold" | "closed" | "unknown";
	open_count: number;
	hold_count: number;
	closed_count: number;
	total_count: number;
}

export const UNKNOWN_LIFTIE_STATE: ResortResponse = {
	status: "unknown",
	open_count: 0,
	hold_count: 0,
	closed_count: 0,
	total_count: 0,
};

function asRecord(value: unknown): Record<string, unknown> | null {
	return value && typeof value === "object" && !Array.isArray(value) ? (value as Record<string, unknown>) : null;
}

function nonNegativeInteger(value: unknown): number | null {
	return typeof value === "number" && Number.isSafeInteger(value) && value >= 0 ? value : null;
}

export function normalizeResortResponse(value: unknown): ResortResponse | null {
	const root = asRecord(value);
	if (!root) return null;
	const lifts = asRecord(root.lifts);
	const stats = lifts && asRecord(lifts.stats);
	if (!stats) return null;

	const openCount = nonNegativeInteger(stats.open);
	const holdCount = nonNegativeInteger(stats.hold);
	const closedCount = nonNegativeInteger(stats.closed);
	const scheduledCount = nonNegativeInteger(stats.scheduled);
	if (openCount === null || holdCount === null || closedCount === null || scheduledCount === null) return null;

	const totalCount = openCount + holdCount + closedCount + scheduledCount;
	return {
		status: openCount > 0 ? "open" : holdCount > 0 ? "hold" : totalCount > 0 ? "closed" : "unknown",
		open_count: openCount,
		hold_count: holdCount,
		closed_count: closedCount,
		total_count: totalCount,
	};
}

function unavailable(): Response {
	return json(UNKNOWN_LIFTIE_STATE, 503, { "Cache-Control": "no-store" });
}

export async function getResort(context: WorkerContext): Promise<Response> {
	const resortName = context.req.param("resortName");
	if (!resortName || !/^[a-z0-9-]+$/.test(resortName)) return error("INVALID_RESORT_NAME", 400);

	const request = context.req.raw;
	const cache = caches.default;
	const cached = await cache.match(request);
	if (cached) return cached;

	try {
		const upstream = await fetch(`${LIFTIE_URL}/api/resort/${encodeURIComponent(resortName)}`, {
			headers: { "User-Agent": context.env.LIFTIE_USER_AGENT },
		});
		if (!upstream.ok) return unavailable();
		const state = normalizeResortResponse(await upstream.json());
		if (!state) return unavailable();

		const response = json(state, 200, { "Cache-Control": `public, s-maxage=${LIFTIE_CACHE_SECONDS}` });
		context.executionCtx.waitUntil(cache.put(request, response.clone()));
		return response;
	} catch {
		return unavailable();
	}
}
