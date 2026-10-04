import { env, evictDurableObject, SELF } from "cloudflare:test";
import { describe, expect, it } from "vitest";

import { normalizeResortResponse, UNKNOWN_LIFTIE_STATE } from "../src/liftie/handlers";

const submission = {
	roundId: "018f3d8e-6b1c-7ef9-8cf6-252ff3d07123",
	playerName: "Sky Rider",
	riderKind: "skier",
	totalScore: 420,
	platform: "web",
};

describe("leaderboard API", () => {
	it("normalizes Liftie stats for the web client", () => {
		expect(
			normalizeResortResponse({
				lifts: { stats: { open: 19, hold: 2, closed: 8, scheduled: 3 } },
			}),
		).toEqual({ status: "open", open_count: 19, hold_count: 2, closed_count: 8, total_count: 32 });
	});

	it("rejects malformed Liftie data for an unavailable response", () => {
		expect(normalizeResortResponse({ lifts: { stats: { open: "19" } } })).toBeNull();
		expect(UNKNOWN_LIFTIE_STATE).toEqual({
			status: "unknown",
			open_count: 0,
			hold_count: 0,
			closed_count: 0,
			total_count: 0,
		});
	});

	it("rejects an invalid Liftie resort name", async () => {
		const response = await SELF.fetch("https://example.test/api/liftie/resort/Heavenly");
		expect(response.status).toBe(400);
		expect(await response.json()).toEqual({ error: { code: "INVALID_RESORT_NAME" } });
	});

	it("initializes the global board", async () => {
		const first = await SELF.fetch("https://example.test/api/leaderboard");
		expect(first.status).toBe(200);
		expect(await first.json()).toMatchObject({ topEntries: [] });
	});

	it("qualifies an empty board and stores a normalized submission idempotently", async () => {
		const qualification = await SELF.fetch("https://example.test/api/leaderboard/qualify", {
			method: "POST",
			body: JSON.stringify({ totalScore: 420 }),
		});
		expect(await qualification.json()).toEqual({ qualified: true, rank: 1 });

		const first = await submit(submission);
		expect(first.status).toBe(201);
		expect(await first.json()).toMatchObject({
			accepted: true,
			rank: 1,
			topEntries: [{ createdAt: expect.stringMatching(/^[\d-]+T[\d:]+\+00:00$/) }],
		});

		const repeated = await submit(submission);
		expect(repeated.status).toBe(201);
		expect(await repeated.json()).toMatchObject({ accepted: true, rank: 1 });

		const board = await env.LEADERBOARD.getByName("leaderboard-global").getBoard();
		expect(board.topEntries).toHaveLength(1);
		expect(board.topEntries[0]?.playerName).toBe("Sky Rider");
	});

	it("returns the original entry when a round ID is reused", async () => {
		await submit(submission);
		const repeated = await submit({ ...submission, totalScore: 421 });
		expect(repeated.status).toBe(201);
		expect(await repeated.json()).toMatchObject({
			accepted: true,
			topEntries: [{ roundId: submission.roundId, totalScore: 420 }],
		});
	});

	it("accepts only ags or web platforms", async () => {
		const accepted = await submit({
			...submission,
			roundId: "018f3d8e-6b1c-7ef9-8cf6-252ff3d07124",
			platform: "ags",
		});
		expect(accepted.status).toBe(201);

		const rejected = await submit({
			...submission,
			roundId: "018f3d8e-6b1c-7ef9-8cf6-252ff3d07125",
			platform: "cabinet",
		});
		expect(rejected.status).toBe(400);
		expect(await rejected.json()).toEqual({ error: { code: "INVALID_PLATFORM" } });
	});

	it("accepts player names up to twelve characters", async () => {
		const accepted = await submit({
			...submission,
			roundId: "018f3d8e-6b1c-7ef9-8cf6-252ff3d07126",
			playerName: "Powder Rider",
		});
		expect(accepted.status).toBe(201);

		const rejected = await submit({
			...submission,
			roundId: "018f3d8e-6b1c-7ef9-8cf6-252ff3d07127",
			playerName: "Too Long Name",
		});
		expect(rejected.status).toBe(400);
		expect(await rejected.json()).toEqual({ error: { code: "INVALID_PLAYER_NAME" } });
	});

	it("requires a score above tenth place", async () => {
		for (let score = 1000; score > 990; score -= 1) {
			const response = await submit({ ...submission, roundId: roundId(score), totalScore: score });
			expect(response.status).toBe(201);
		}

		expect(await qualify(991)).toEqual({ qualified: false, rank: null });
		expect(await qualify(992)).toEqual({ qualified: true, rank: null });

	});

	it("serializes concurrent submissions and survives Durable Object eviction", async () => {
		const responses = await Promise.all(
			Array.from({ length: 12 }, (_, index) =>
				submit({ ...submission, roundId: roundId(index), totalScore: 500 + index }),
			),
		);
		expect(responses.map((response) => response.status)).toEqual(Array(12).fill(201));

		const leaderboard = env.LEADERBOARD.getByName("leaderboard-global");
		const beforeEviction = await leaderboard.getBoard();
		expect(beforeEviction.topEntries).toHaveLength(10);
		await evictDurableObject(leaderboard);
		const restored = await leaderboard.getBoard();
		expect(restored).toEqual(beforeEviction);
	});
});

function submit(payload: object): Promise<Response> {
	return SELF.fetch("https://example.test/api/leaderboard/submissions", {
		method: "POST",
		headers: { "Content-Type": "application/json" },
		body: JSON.stringify(payload),
	});
}

async function qualify(totalScore: number): Promise<{ qualified: boolean; rank: number | null }> {
	const response = await SELF.fetch("https://example.test/api/leaderboard/qualify", {
		method: "POST",
		headers: { "Content-Type": "application/json" },
		body: JSON.stringify({ totalScore }),
	});
	return response.json();
}

function roundId(value: number): string {
	return `018f3d8e-6b1c-7ef9-8cf6-${value.toString(16).padStart(12, "0")}`;
}
