import { error, json } from "../utils/http";
import type { WorkerContext } from "../workerTypes";

const LIFTIE_URL = "https://liftie.info";
const LIFTIE_CACHE_SECONDS = 60;

export type LiftStatus = "open" | "hold" | "scheduled" | "closed";

export interface LiftieResortResponse {
	id: string;
	open: boolean;
	ll: [longitude: number, latitude: number];
	timestamp: {
		lifts: number;
		opening: number;
	};
	lifts: {
		status: Record<string, LiftStatus>;
		stats: {
			open: number;
			hold: number;
			scheduled: number;
			closed: number;
			percentage: {
				open: number;
				hold: number;
				scheduled: number;
				closed: number;
			};
		};
	};
}

function asRecord(value: unknown): Record<string, unknown> | null {
	return value && typeof value === "object" && !Array.isArray(value)
		? (value as Record<string, unknown>)
		: null;
}

function nonNegativeInteger(value: unknown): number | null {
	return typeof value === "number" && Number.isSafeInteger(value) && value >= 0
		? value
		: null;
}

function finiteNumber(value: unknown): number | null {
	return typeof value === "number" && Number.isFinite(value) ? value : null;
}

function liftStatus(value: unknown): LiftStatus | null {
	return value === "open" ||
		value === "hold" ||
		value === "scheduled" ||
		value === "closed"
		? value
		: null;
}

function normalizeLiftStatuses(
	value: unknown,
): Record<string, LiftStatus> | null {
	const statuses = asRecord(value);
	if (!statuses) return null;

	const lifts: Record<string, LiftStatus> = {};
	for (const [name, value] of Object.entries(statuses)) {
		const status = liftStatus(value);
		if (!status) return null;
		lifts[name] = status;
	}
	return lifts;
}

export function normalizeResortResponse(
	value: unknown,
): LiftieResortResponse | null {
	const root = asRecord(value);
	if (!root) return null;
	const id = typeof root.id === "string" && root.id ? root.id : null;
	const isOpen = typeof root.open === "boolean" ? root.open : null;
	const coordinates = Array.isArray(root.ll) ? root.ll : null;
	if (!id || isOpen === null || !coordinates || coordinates.length !== 2)
		return null;
	const longitude = finiteNumber(coordinates[0]);
	const latitude = finiteNumber(coordinates[1]);
	if (longitude === null || latitude === null) return null;

	const timestamp = asRecord(root.timestamp);
	if (!timestamp) return null;
	const liftsTimestamp = nonNegativeInteger(timestamp.lifts);
	const openingTimestamp = nonNegativeInteger(timestamp.opening);
	if (liftsTimestamp === null || openingTimestamp === null) return null;

	const lifts = asRecord(root.lifts);
	const stats = lifts && asRecord(lifts.stats);
	if (!stats) return null;
	const liftStatuses = normalizeLiftStatuses(lifts.status);
	if (!liftStatuses) return null;

	const openCount = nonNegativeInteger(stats.open);
	const holdCount = nonNegativeInteger(stats.hold);
	const closedCount = nonNegativeInteger(stats.closed);
	const scheduledCount = nonNegativeInteger(stats.scheduled);
	if (
		openCount === null ||
		holdCount === null ||
		closedCount === null ||
		scheduledCount === null
	)
		return null;
	const percentage = asRecord(stats.percentage);
	if (!percentage) return null;
	const openPercentage = finiteNumber(percentage.open);
	const holdPercentage = finiteNumber(percentage.hold);
	const scheduledPercentage = finiteNumber(percentage.scheduled);
	const closedPercentage = finiteNumber(percentage.closed);
	if (
		openPercentage === null ||
		holdPercentage === null ||
		scheduledPercentage === null ||
		closedPercentage === null
	)
		return null;

	return {
		id,
		open: isOpen,
		ll: [longitude, latitude],
		timestamp: { lifts: liftsTimestamp, opening: openingTimestamp },
		lifts: {
			status: liftStatuses,
			stats: {
				open: openCount,
				hold: holdCount,
				scheduled: scheduledCount,
				closed: closedCount,
				percentage: {
					open: openPercentage,
					hold: holdPercentage,
					scheduled: scheduledPercentage,
					closed: closedPercentage,
				},
			},
		},
	};
}

function unavailable(): Response {
	return new Response(null, {
		status: 503,
		headers: { "Cache-Control": "no-store" },
	});
}

export async function getResort(context: WorkerContext): Promise<Response> {
	const resortName = context.req.param("resortName");
	if (!resortName || !/^[a-z0-9-]+$/.test(resortName))
		return error("INVALID_RESORT_NAME", 400);

	const request = context.req.raw;
	const cache = caches.default;
	const cached = await cache.match(request);
	if (cached) return cached;

	try {
		const upstream = await fetch(
			`${LIFTIE_URL}/api/resort/${encodeURIComponent(resortName)}`,
			{
				headers: { "User-Agent": context.env.LIFTIE_USER_AGENT },
			},
		);
		if (!upstream.ok) return unavailable();
		const state = normalizeResortResponse(await upstream.json());
		if (!state) return unavailable();

		const response = json(state, 200, {
			"Cache-Control": `public, s-maxage=${LIFTIE_CACHE_SECONDS}`,
		});
		context.executionCtx.waitUntil(cache.put(request, response.clone()));
		return response;
	} catch {
		return unavailable();
	}
}
