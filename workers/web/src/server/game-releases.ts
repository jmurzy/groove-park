import { env } from "cloudflare:workers";
import { createServerFn } from "@tanstack/react-start";

const RELEASE_POINTER_KEY = "current.json";
const RELEASE_ID = /^[0-9a-f]{40}$/;

async function getCurrentReleaseId(): Promise<string | null> {
	const pointer = await env.GAME_RELEASES.get(RELEASE_POINTER_KEY);
	if (!pointer) return null;

	try {
		const value: unknown = JSON.parse(await pointer.text());
		if (!value || typeof value !== "object" || Array.isArray(value))
			return null;
		const release = (value as { release?: unknown }).release;
		return typeof release === "string" && RELEASE_ID.test(release)
			? release
			: null;
	} catch {
		return null;
	}
}

export const getGameReleaseId = createServerFn({ method: "GET" }).handler(
	getCurrentReleaseId,
);

export type GodotEngineConfig = {
	args: string[];
	canvasResizePolicy: number;
	emscriptenPoolSize: number;
	ensureCrossOriginIsolationHeaders: boolean;
	executable: string;
	experimentalVK: boolean;
	fileSizes: Record<string, number>;
	focusCanvas: boolean;
	gdextensionLibs: string[];
	godotPoolSize: number;

	serviceWorker?: any;
};

export type GodotReleaseConfig = {
	config: GodotEngineConfig;
	threadsEnabled: boolean;
	projectName: string;
	splashColor: string;
	splashClasses: string;
	splash: string;
	url: string;
};

async function getCurrentReleaseConfig(): Promise<GodotReleaseConfig | null> {
	const release = await getCurrentReleaseId();
	if (!release) return null;

	try {
		const config = await env.GAME_RELEASES.get(
			`releases/${release}/release_config.json`,
		);
		if (!config) return null;

		return JSON.parse(await config.text());
	} catch {
		return null;
	}
}

export const getGameReleaseConfig = createServerFn({ method: "GET" }).handler(
	getCurrentReleaseConfig,
);
