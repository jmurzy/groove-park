import type {
	GodotEngineConfig,
	GodotReleaseConfig,
} from "#/server/game-releases";

export type GodotEngine = {
	installServiceWorker(): Promise<void>;
	startGame(options: {
		canvas: HTMLCanvasElement;
		onProgress(current: number, total: number): void;
	}): Promise<void>;
};

export type GodotEngineConstructor = {
	new (config: GodotEngineConfig): GodotEngine;
	getMissingFeatures(options: { threads: boolean }): string[];
};

declare global {
	interface Window {
		Engine?: GodotEngineConstructor;
		HEAVENLY_CFG?: {
			leaderboard_api: { base_url: string };
		};
	}
}

let engineScriptPromise: Promise<GodotEngineConstructor> | undefined;

export function loadGodotEngine(url: string) {
	engineScriptPromise ??= new Promise((resolve, reject) => {
		const script = document.createElement("script");
		script.src = url;
		script.async = true;
		script.onload = () => {
			if (window.Engine) resolve(window.Engine);
			else reject(new Error("Game engine failed to load."));
		};
		script.onerror = () => reject(new Error("Game engine failed to load."));
		document.head.append(script);
	});
	return engineScriptPromise;
}

export async function handleMissingFeatures(
	assetBase: string,
	config: GodotEngineConfig,
	engine: GodotEngine,
	missing: string[],
) {
	if (missing.length === 0) return false;

	const canInstallServiceWorker =
		config.serviceWorker &&
		config.ensureCrossOriginIsolationHeaders &&
		"serviceWorker" in navigator;

	if (!canInstallServiceWorker) {
		throw new Error(
			`The following features required to run the game are missing:\n${missing.join("\n")}`,
		);
	}

	const registration = await navigator.serviceWorker.getRegistration(assetBase);
	if (registration) throw new Error("Service worker already exists.");

	await engine.installServiceWorker();
	window.location.reload();
	return true;
}

export async function startGodotGame(
	releaseConfig: GodotReleaseConfig,
	assetBase: string,
	canvas: HTMLCanvasElement,
	onProgress: (current: number, total: number) => void,
) {
	const config: GodotEngineConfig = {
		...releaseConfig.config,
		executable: new URL(releaseConfig.config.executable, assetBase).href,
	};
	await loadGodotEngine(new URL(releaseConfig.url, assetBase).href);
	if (!window.Engine) throw new Error("Game engine failed to load.");

	const engine = new window.Engine(config);
	const missing = window.Engine.getMissingFeatures({
		threads: releaseConfig.threadsEnabled,
	});
	if (await handleMissingFeatures(assetBase, config, engine, missing)) return;

	await engine.startGame({ canvas, onProgress });
}
