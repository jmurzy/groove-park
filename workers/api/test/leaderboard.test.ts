import * as Alchemy from "alchemy";
import * as Cloudflare from "alchemy/Cloudflare";
import * as Test from "alchemy/Test/Vitest";
import { describe, expect } from "@effect/vitest";
import * as Effect from "effect/Effect";

import { apiWorker } from "../alchemy.run";
import { normalizeResortResponse } from "../src/liftie/handlers";

const localStack = Alchemy.Stack(
	"game",
	{ providers: Cloudflare.providers(), state: Alchemy.localState() },
	Effect.gen(function* () {
		const api = yield* apiWorker;
		return { apiUrl: api.url };
	}),
);

const {
	test: alchemyTest,
	beforeAll,
	deploy,
} = Test.make({
	providers: Cloudflare.providers(),
	dev: true,
});
const test = (name: string, make: () => Effect.Effect<void, unknown>) =>
	alchemyTest(name, Effect.suspend(make).pipe(Effect.orDie));
const stack = beforeAll(deploy(localStack));

const submission = {
	roundId: "018f3d8e-6b1c-7ef9-8cf6-252ff3d07123",
	playerName: "Sky Rider",
	riderKind: "skier",
	totalScore: 420,
	platform: "web",
};

describe("leaderboard API", () => {
	test("permits the game origin to call the API", () =>
		Effect.gen(function* () {
			const response = yield* request("/api/leaderboard", {
				method: "OPTIONS",
				headers: {
					Origin: "https://game.gunbarrelhaus.com",
					"Access-Control-Request-Method": "POST",
				},
			});
			expect(response.status).toBe(204);
			expect(response.headers.get("Access-Control-Allow-Origin")).toBe(
				"https://game.gunbarrelhaus.com",
			);
			expect(response.headers.get("Access-Control-Allow-Headers")).toContain(
				"X-Installation-Id",
			);
		}));

	test("permits browser requests from the game origin", () =>
		Effect.gen(function* () {
			const response = yield* request("/api/leaderboard", {
				headers: {
					Origin: "https://game.gunbarrelhaus.com",
					...cabinetHeaders(),
				},
			});
			expect(response.status).toBe(200);
			expect(response.headers.get("Access-Control-Allow-Origin")).toBe(
				"https://game.gunbarrelhaus.com",
			);
		}));

	test("does not allow a local origin", () =>
		Effect.gen(function* () {
			const response = yield* request("/api/leaderboard", {
				method: "OPTIONS",
				headers: {
					Origin: "http://localhost:3000",
					"Access-Control-Request-Method": "POST",
				},
			});
			expect(response.status).toBe(204);
			expect(response.headers.get("Access-Control-Allow-Origin")).toBeNull();
		}));

	test("rejects an invalid Liftie resort name", () =>
		Effect.gen(function* () {
			const response = yield* request("/api/liftie/resort/Heavenly", {
				headers: cabinetHeaders(),
			});
			expect(response.status).toBe(400);
			expect(yield* responseJson(response)).toEqual({
				error: { code: "INVALID_RESORT_NAME" },
			});
		}));

	test("applies cabinet installation validation to the Liftie proxy", () =>
		Effect.gen(function* () {
			const response = yield* request("/api/liftie/resort/heavenly", {
				headers: { "X-Installation-Id": "not-an-installation-id" },
			});
			expect(response.status).toBe(400);
			expect(yield* responseJson(response)).toEqual({
				error: { code: "INVALID_INSTALLATION_ID" },
			});
		}));

	test("returns the global board", () =>
		Effect.gen(function* () {
			const response = yield* request("/api/leaderboard", {
				headers: cabinetHeaders(),
			});
			expect(response.status).toBe(200);
			expect(response.headers.get("X-Request-Id")).toMatch(
				/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i,
			);
			expect(response.headers.get("Cache-Control")).toBe("no-store");
			const board = (yield* responseJson(response)) as {
				topEntries: unknown[];
			};
			expect(board.topEntries).toBeInstanceOf(Array);
		}));

	test("does not expose a leaderboard reset route", () =>
		Effect.gen(function* () {
			const response = yield* request("/api/reset", {
				headers: cabinetHeaders(),
			});
			expect(response.status).toBe(404);
			expect(yield* responseJson(response)).toEqual({
				error: { code: "NOT_FOUND" },
			});
		}));

	test("requires an installation ID before processing a request", () =>
		Effect.gen(function* () {
			const response = yield* request("/api/leaderboard");
			expect(response.status).toBe(400);
			expect(yield* responseJson(response)).toEqual({
				error: { code: "MISSING_INSTALLATION_ID" },
			});
		}));

	test("rejects malformed cabinet installation IDs before invoking the leaderboard", () =>
		Effect.gen(function* () {
			const before = yield* request("/api/leaderboard", {
				headers: cabinetHeaders(),
			});
			const beforeBody = yield* responseJson(before);
			const response = yield* submit(submission, {
				"X-Installation-Id": "not-an-installation-id",
			});
			expect(response.status).toBe(400);
			expect(yield* responseJson(response)).toEqual({
				error: { code: "INVALID_INSTALLATION_ID" },
			});
			const board = yield* request("/api/leaderboard", {
				headers: cabinetHeaders(),
			});
			expect(yield* responseJson(board)).toEqual(beforeBody);
		}));

	test("limits cabinet requests by installation without mutating the board", () =>
		Effect.gen(function* () {
			const headers = cabinetHeaders(
				"018f3d8e-6b1c-4ef9-8cf6-252ff3d07199",
				"192.0.2.20",
			);
			for (let index = 0; index < 20; index += 1) {
				const response = yield* request("/api/leaderboard/qualify", {
					method: "POST",
					headers,
					body: JSON.stringify({ totalScore: index }),
				});
				expect(response.status).toBe(200);
			}
			const limited = yield* submit(submission, headers);
			expect(limited.status).toBe(429);
			expect(limited.headers.get("Retry-After")).toBe("60");
			expect(yield* responseJson(limited)).toEqual({
				error: { code: "RATE_LIMITED" },
			});
		}));

	test("limits cabinet requests by connecting IP independently of installation ID", () =>
		Effect.gen(function* () {
			const ipAddress = "192.0.2.21";
			for (let index = 0; index < 60; index += 1) {
				const response = yield* request("/api/leaderboard/qualify", {
					method: "POST",
					headers: cabinetHeaders(roundId(index), ipAddress),
					body: JSON.stringify({ totalScore: index }),
				});
				expect(response.status).toBe(200);
			}
			const limited = yield* request("/api/leaderboard/qualify", {
				method: "POST",
				headers: cabinetHeaders(roundId(61), ipAddress),
				body: JSON.stringify({ totalScore: 61 }),
			});
			expect(limited.status).toBe(429);
			expect(yield* responseJson(limited)).toEqual({
				error: { code: "RATE_LIMITED" },
			});
		}));

	test("qualifies a top score and stores a normalized submission idempotently", () =>
		Effect.gen(function* () {
			const topSubmission = {
				...submission,
				roundId: roundId(2_147_483_647),
				totalScore: 2_147_483_647,
			};
			const qualification = yield* qualify(topSubmission.totalScore);
			expect(qualification).toEqual({ qualified: true });
			const first = yield* submit(topSubmission);
			expect(first.status).toBe(201);
			expect(yield* responseJson(first)).toEqual({ accepted: true, rank: 1 });
			const repeated = yield* submit(topSubmission);
			expect(repeated.status).toBe(201);
			expect(yield* responseJson(repeated)).toEqual({
				accepted: true,
				rank: 1,
			});
			const board = yield* request("/api/leaderboard", {
				headers: cabinetHeaders(),
			});
			const boardBody = (yield* responseJson(board)) as {
				topEntries: Array<{ roundId: string }>;
			};
			expect(
				boardBody.topEntries.some(
					(entry) => entry.roundId === topSubmission.roundId,
				),
			).toBe(true);
		}));

	test("does not qualify or store zero scores", () =>
		Effect.gen(function* () {
			const before = yield* request("/api/leaderboard", {
				headers: cabinetHeaders(),
			});
			const beforeBody = yield* responseJson(before);
			expect(yield* qualify(0)).toEqual({ qualified: false });
			const response = yield* submit({ ...submission, totalScore: 0 });
			expect(response.status).toBe(400);
			expect(yield* responseJson(response)).toEqual({
				error: { code: "INVALID_TOTAL_SCORE" },
			});
			const board = yield* request("/api/leaderboard", {
				headers: cabinetHeaders(),
			});
			expect(yield* responseJson(board)).toEqual(beforeBody);
		}));

	test("returns the original entry when a round ID is reused", () =>
		Effect.gen(function* () {
			const first = yield* submit({
				...submission,
				roundId: roundId(2_147_483_646),
				totalScore: 2_147_483_646,
			});
			const firstBody = yield* responseJson(first);
			const repeated = yield* submit({
				...submission,
				roundId: roundId(2_147_483_646),
				totalScore: 421,
			});
			expect(repeated.status).toBe(201);
			expect(yield* responseJson(repeated)).toEqual(firstBody);
		}));

	test("accepts only ags or web platforms", () =>
		Effect.gen(function* () {
			const accepted = yield* submit({
				...submission,
				roundId: roundId(24),
				platform: "ags",
			});
			expect(accepted.status).toBe(201);
			const rejected = yield* submit({
				...submission,
				roundId: roundId(25),
				platform: "cabinet",
			});
			expect(rejected.status).toBe(400);
			expect(yield* responseJson(rejected)).toEqual({
				error: { code: "INVALID_PLATFORM" },
			});
		}));

	test("accepts player names up to twelve characters", () =>
		Effect.gen(function* () {
			const accepted = yield* submit({
				...submission,
				roundId: roundId(26),
				playerName: "Powder Rider",
			});
			expect(accepted.status).toBe(201);
			const rejected = yield* submit({
				...submission,
				roundId: roundId(27),
				playerName: "Too Long Name",
			});
			expect(rejected.status).toBe(400);
			expect(yield* responseJson(rejected)).toEqual({
				error: { code: "INVALID_PLAYER_NAME" },
			});
		}));

	test("requires a score above tenth place", () =>
		Effect.gen(function* () {
			for (let offset = 100; offset < 110; offset += 1) {
				const score = 2_147_483_647 - offset;
				const response = yield* submit({
					...submission,
					roundId: roundId(score),
					totalScore: score,
				});
				expect(response.status).toBe(201);
			}
			const board = yield* request("/api/leaderboard", {
				headers: cabinetHeaders(),
			});
			const boardBody = (yield* responseJson(board)) as {
				topEntries: Array<{ totalScore: number }>;
			};
			const tenthScore = boardBody.topEntries[9]?.totalScore;
			expect(tenthScore).toBeTypeOf("number");
			if (tenthScore === undefined) return;
			expect(yield* qualify(tenthScore)).toEqual({ qualified: false });
			if (tenthScore < 2_147_483_647) {
				expect(yield* qualify(tenthScore + 1)).toEqual({ qualified: true });
			}
		}));

	test("serializes concurrent submissions", () =>
		Effect.gen(function* () {
			const responses = yield* Effect.all(
				Array.from({ length: 12 }, (_, index) =>
					submit(
						{ ...submission, roundId: roundId(index), totalScore: 500 + index },
						cabinetHeaders(roundId(index), "192.0.2.22"),
					),
				),
				{ concurrency: "unbounded" },
			);
			expect(responses.map((response) => response.status)).toEqual(
				Array(12).fill(201),
			);
			const board = yield* request("/api/leaderboard", {
				headers: cabinetHeaders(),
			});
			const body = (yield* responseJson(board)) as { topEntries: unknown[] };
			expect(body.topEntries).toHaveLength(10);
		}));
});

describe("Liftie normalization", () => {
	test("normalizes a complete Liftie resort response", () =>
		Effect.sync(() => {
			const liftieResort = {
				id: "sierra",
				open: false,
				ll: [-120.090012, 38.792763],
				timestamp: { lifts: 1791917385485, opening: 1791915613570 },
				lifts: {
					status: {
						"Easy Rider Express": "closed",
						"Grandview Express": "closed",
						"Rock Garden": "closed",
						"Tahoe King": "closed",
						"Thunder Gulch Carpet (Ski/Ride School Only)": "closed",
						"Blizzard Mountain Tubing": "closed",
						"Fuego Carpet": "closed",
						"Nob Hill": "closed",
						"Slider Carpet": "closed",
						"Wild Mountain Carpet (Ski/Ride School Only)": "closed",
						"El Dorado": "closed",
						"Short Stuff": "closed",
						"West Bowl Express": "closed",
						Puma: "closed",
					},
					stats: {
						open: 0,
						hold: 0,
						scheduled: 0,
						closed: 14,
						percentage: { open: 0, hold: 0, scheduled: 0, closed: 100 },
					},
				},
			};
			expect(normalizeResortResponse(liftieResort)).toEqual(liftieResort);
		}));

	test("rejects malformed Liftie data", () =>
		Effect.sync(() => {
			expect(
				normalizeResortResponse({
					id: "sierra",
					open: false,
					ll: [-120.090012, 38.792763],
					timestamp: { lifts: 1791917385485, opening: 1791915613570 },
					lifts: {
						status: {},
						stats: {
							open: "19",
							hold: 0,
							scheduled: 0,
							closed: 0,
							percentage: { open: 0, hold: 0, scheduled: 0, closed: 0 },
						},
					},
				}),
			).toBeNull();
		}));
});

function request(path: string, init?: RequestInit) {
	return Effect.gen(function* () {
		const { apiUrl } = yield* stack;
		return yield* Effect.tryPromise(() => fetch(new URL(path, apiUrl), init));
	});
}

function responseJson(response: Response) {
	return Effect.tryPromise(() => response.json());
}

function submit(payload: object, headers: HeadersInit = {}) {
	const requestHeaders = new Headers(headers);
	requestHeaders.set("Content-Type", "application/json");
	if (!requestHeaders.has("X-Installation-Id"))
		requestHeaders.set("X-Installation-Id", crypto.randomUUID());
	return request("/api/leaderboard/submissions", {
		method: "POST",
		headers: requestHeaders,
		body: JSON.stringify(payload),
	});
}

function cabinetHeaders(
	installationId: string = crypto.randomUUID(),
	ipAddress?: string,
): HeadersInit {
	const headers: Record<string, string> = {
		"X-Installation-Id": installationId,
	};
	if (ipAddress) headers["CF-Connecting-IP"] = ipAddress;
	return headers;
}

function qualify(totalScore: number) {
	return Effect.gen(function* () {
		const response = yield* request("/api/leaderboard/qualify", {
			method: "POST",
			headers: { "Content-Type": "application/json", ...cabinetHeaders() },
			body: JSON.stringify({ totalScore }),
		});
		return yield* responseJson(response);
	});
}

function roundId(value: number): string {
	return `018f3d8e-6b1c-7ef9-8cf6-${value.toString(16).padStart(12, "0")}`;
}
