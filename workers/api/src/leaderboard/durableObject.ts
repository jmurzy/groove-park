import { DurableObject } from "cloudflare:workers";

import type { ApiWorkerEnv } from "../../alchemy.run";

export const TOP_ENTRY_LIMIT = 10;

export type RiderKind = "skier" | "snowboarder";
export type Platform = "ags" | "web";

interface LeaderboardEntryRow {
	[key: string]: SqlStorageValue;
	round_id: string;
	player_name: string;
	total_score: number;
	rider_kind: RiderKind;
	platform: Platform;
	created_at: string;
}

export interface LeaderboardEntry {
	roundId: string;
	playerName: string;
	totalScore: number;
	riderKind: RiderKind;
	platform: Platform;
	createdAt: string;
}

export interface BoardSnapshot {
	topEntries: LeaderboardEntry[];
}

export interface SubmissionResult {
	accepted: true;
	rank: number;
}

export interface ScoreSubmission {
	roundId: string;
	playerName: string;
	riderKind: RiderKind;
	platform: Platform;
	totalScore: number;
}

interface SqlMigration {
	id: number;
	sql: string;
}

const SQL_MIGRATIONS: readonly SqlMigration[] = [
	{
		id: 1,
		sql: `
CREATE TABLE IF NOT EXISTS leaderboard_entries (
  round_id TEXT PRIMARY KEY,
  player_name TEXT NOT NULL CHECK (length(player_name) BETWEEN 1 AND 12),
  total_score INTEGER NOT NULL CHECK (total_score BETWEEN 0 AND 2147483647),
  rider_kind TEXT NOT NULL CHECK (rider_kind IN ('skier', 'snowboarder')),
  platform TEXT NOT NULL CHECK (platform IN ('ags', 'web')),
  created_at TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS leaderboard_rank_idx
ON leaderboard_entries(total_score DESC, created_at ASC, round_id ASC);
`,
	},
];

export class GlobalLeaderboard extends DurableObject<ApiWorkerEnv> {
	constructor(ctx: DurableObjectState, env: ApiWorkerEnv) {
		super(ctx, env);
		ctx.blockConcurrencyWhile(() => this.initialize());
	}

	async getBoard(): Promise<BoardSnapshot> {
		return {
			topEntries: this.topEntries(),
		};
	}

	async reset(): Promise<BoardSnapshot> {
		this.ctx.storage.sql.exec("DELETE FROM leaderboard_entries");
		return { topEntries: [] };
	}

	async checkQualification(totalScore: number): Promise<{ qualified: boolean }> {
		if (totalScore <= 0) return { qualified: false };
		const tenth = this.ctx.storage.sql
			.exec<{ total_score: number }>(
				"SELECT total_score FROM leaderboard_entries ORDER BY total_score DESC, created_at ASC, round_id ASC LIMIT 1 OFFSET ?",
				TOP_ENTRY_LIMIT - 1,
			)
			.toArray()[0];
		return { qualified: tenth == null || totalScore > tenth.total_score };
	}

	async submit(submission: ScoreSubmission): Promise<SubmissionResult> {
		if (submission.totalScore <= 0) throw new RangeError("Leaderboard scores must be positive");
		const existing = this.ctx.storage.sql
			.exec<LeaderboardEntryRow>("SELECT * FROM leaderboard_entries WHERE round_id = ?", submission.roundId)
			.toArray()[0];
		if (existing) {
			return this.submissionResult(existing);
		}

		const createdAt = formatCreatedAt(new Date(), this.env.TZ);
		const row = this.ctx.storage.sql
			.exec<LeaderboardEntryRow>(
				`INSERT INTO leaderboard_entries (
					round_id, player_name, total_score, rider_kind, platform, created_at
				) VALUES (?, ?, ?, ?, ?, ?)
				RETURNING *`,
				submission.roundId,
				submission.playerName,
				submission.totalScore,
				submission.riderKind,
				submission.platform,
				createdAt,
			)
			.one();
		return this.submissionResult(row);
	}

	private async initialize(): Promise<void> {
		this.ctx.storage.sql.exec(`
			CREATE TABLE IF NOT EXISTS _sql_schema_migrations (
				id INTEGER PRIMARY KEY,
				applied_at TEXT NOT NULL DEFAULT (datetime('now'))
			)
		`);
		const currentVersion = this.ctx.storage.sql
			.exec<{ version: number }>("SELECT COALESCE(MAX(id), 0) AS version FROM _sql_schema_migrations")
			.one().version;
		const latestVersion = SQL_MIGRATIONS.at(-1)?.id ?? 0;
		if (currentVersion > latestVersion) {
			throw new Error(`Unsupported leaderboard schema version: ${currentVersion}`);
		}

		for (const migration of SQL_MIGRATIONS) {
			if (migration.id <= currentVersion) continue;
			// The schema changes and their version marker execute as one SQL batch.
			this.ctx.storage.sql.exec(`${migration.sql}\nINSERT INTO _sql_schema_migrations (id) VALUES (?);`, migration.id);
		}
	}

	private topEntries(): LeaderboardEntry[] {
		return this.ctx.storage.sql
			.exec<LeaderboardEntryRow>(
				"SELECT * FROM leaderboard_entries ORDER BY total_score DESC, created_at ASC, round_id ASC LIMIT ?",
				TOP_ENTRY_LIMIT,
			)
			.toArray()
			.map((row) => this.toEntry(row));
	}

	private submissionResult(row: LeaderboardEntryRow): SubmissionResult {
		const rank = this.ctx.storage.sql
			.exec<{ rank: number }>(
				`SELECT COUNT(*) + 1 AS rank FROM leaderboard_entries
				 WHERE total_score > ?
				    OR (total_score = ? AND created_at < ?)
				    OR (total_score = ? AND created_at = ? AND round_id < ?)`,
				row.total_score,
				row.total_score,
				row.created_at,
				row.total_score,
				row.created_at,
				row.round_id,
			)
			.one().rank;
		return {
			accepted: true,
			rank,
		};
	}

	private toEntry(row: LeaderboardEntryRow): LeaderboardEntry {
		return {
			roundId: row.round_id,
			playerName: row.player_name,
			totalScore: row.total_score,
			riderKind: row.rider_kind,
			platform: row.platform,
			createdAt: row.created_at,
		};
	}
}

function formatCreatedAt(date: Date, timeZone: string): string {
	const parts = new Intl.DateTimeFormat("en-CA", {
		timeZone,
		year: "numeric",
		month: "2-digit",
		day: "2-digit",
		hour: "2-digit",
		minute: "2-digit",
		second: "2-digit",
		hourCycle: "h23",
		timeZoneName: "longOffset",
	}).formatToParts(date);
	const value = (type: Intl.DateTimeFormatPartTypes): string => parts.find((part) => part.type === type)?.value ?? "";
	const offset = value("timeZoneName");
	if (!/^GMT(?:[+-]\d{2}:\d{2})?$/.test(offset)) throw new Error(`Invalid timezone offset for ${timeZone}`);
	return `${value("year")}-${value("month")}-${value("day")}T${value("hour")}:${value("minute")}:${value("second")}${offset === "GMT" ? "+00:00" : offset.slice(3)}`;
}
