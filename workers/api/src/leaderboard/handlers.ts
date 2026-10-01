import { error, json, requestJson } from "../utils/http";
import type { WorkerContext } from "../workerTypes";
import type { ScoreSubmission } from "./durableObject";

const LEADERBOARD_OBJECT_NAME = "leaderboard-global";
const MAX_SCORE = 2_147_483_647;

function isScore(value: unknown): value is number {
	return typeof value === "number" && Number.isInteger(value) && value >= 0 && value <= MAX_SCORE;
}

function normalizePlayerName(value: unknown): string | null {
	if (typeof value !== "string") return null;
	const playerName = value.normalize("NFC").trim();
	if (playerName.length === 0 || Array.from(playerName).length > 12 || /[\p{Cc}\p{Cs}]/u.test(playerName)) return null;
	return playerName;
}

export async function getLeaderboard(context: WorkerContext): Promise<Response> {
	const leaderboard = context.env.LEADERBOARD.getByName(LEADERBOARD_OBJECT_NAME);
	const snapshot = await leaderboard.getBoard();
	return json(snapshot);
}

export async function qualifyLeaderboard(context: WorkerContext): Promise<Response> {
	const body = await requestJson(context.req.raw);
	if (!body.ok) return body.response;
	if (!isScore(body.value.totalScore)) return error("INVALID_TOTAL_SCORE", 400);

	const leaderboard = context.env.LEADERBOARD.getByName(LEADERBOARD_OBJECT_NAME);
	return json(await leaderboard.checkQualification(body.value.totalScore));
}

export async function submitLeaderboard(context: WorkerContext): Promise<Response> {
	const body = await requestJson(context.req.raw);
	if (!body.ok) return body.response;
	const submission = parseSubmission(body.value);
	if (!submission.ok) return error(submission.code, 400);
	
	const leaderboard = context.env.LEADERBOARD.getByName(LEADERBOARD_OBJECT_NAME);
	const result = await leaderboard.submit(submission.value);
	return json(result, 201);
}

function parseSubmission(value: Record<string, unknown>):
	| { ok: true; value: ScoreSubmission }
	| { ok: false; code: string } {
	const playerName = normalizePlayerName(value.playerName);
	if (!playerName) return { ok: false, code: "INVALID_PLAYER_NAME" };
	if (
		typeof value.roundId !== "string" ||
		!/^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value.roundId)
	) {
		return { ok: false, code: "INVALID_ROUND_ID" };
	}
	if (value.riderKind !== "skier" && value.riderKind !== "snowboarder") return { ok: false, code: "INVALID_RIDER_KIND" };
	if (!isScore(value.totalScore)) return { ok: false, code: "INVALID_TOTAL_SCORE" };
	if (value.platform !== "ags" && value.platform !== "web") return { ok: false, code: "INVALID_PLATFORM" };
	return {
		ok: true,
		value: {
			roundId: value.roundId,
			playerName,
			riderKind: value.riderKind,
			totalScore: value.totalScore,
			platform: value.platform,
		},
	};
}
