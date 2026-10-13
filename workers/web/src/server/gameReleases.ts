import { env } from "cloudflare:workers";
import { createServerFn } from "@tanstack/react-start";
import type { GodotReleaseConfig } from "#/hooks/useGodotGame";

const RELEASE_POINTER_KEY = "current.json";
const RELEASE_ID = /^[0-9a-f]{40}$/;

async function getCurrentReleaseId(): Promise<string> {
	const pointer = await env.GAME_RELEASES.get(RELEASE_POINTER_KEY);
	if (!pointer) throw new Error("Current game release is unavailable");

	const value: unknown = JSON.parse(await pointer.text());
	if (!value || typeof value !== "object" || Array.isArray(value)) {
		throw new Error("Current game release pointer is invalid");
	}
	const release = (value as { release?: unknown }).release;
	if (typeof release !== "string" || !RELEASE_ID.test(release)) {
		throw new Error("Current game release pointer is invalid");
	}

	return release;
}

export const getGameReleaseId = createServerFn({ method: "GET" }).handler(
	getCurrentReleaseId,
);

async function getCurrentReleaseConfig(): Promise<GodotReleaseConfig> {
	const release = await getCurrentReleaseId();

	const config = await env.GAME_RELEASES.get(
		`releases/${release}/release_config.json`,
	);
	if (!config)
		throw new Error("Current game release configuration is unavailable");

	return JSON.parse(await config.text());
}

export const getGameReleaseConfig = createServerFn({ method: "GET" }).handler(
	getCurrentReleaseConfig,
);
