import { type RefObject, useEffect, useMemo, useRef, useState } from "react";

export type GodotEngineConfig = {
	args: string[];
	canvasResizePolicy: number;
	emscriptenPoolSize?: number;
	ensureCrossOriginIsolationHeaders: boolean;
	executable: string;
	experimentalVK: boolean;
	fileSizes: Record<string, number>;
	focusCanvas: boolean;
	gdextensionLibs: string[];
	godotPoolSize?: number;
	serviceWorker?: string;
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

export type GameCfg = {
	game_api: { base_url: string; resort_slug: string };
};

type GodotEngine = {
	installServiceWorker(): Promise<void>;
	startGame(options: {
		canvas: HTMLCanvasElement;
		onProgress(current: number, total: number): void;
	}): Promise<void>;
};

type GodotEngineConstructor = {
	new (config: GodotEngineConfig): GodotEngine;
	getMissingFeatures(options: { threads: boolean }): string[];
};

declare global {
	interface Window {
		Engine?: GodotEngineConstructor;
		GAME_CFG?: GameCfg;
	}
}

let engineScriptPromise: Promise<GodotEngineConstructor> | undefined;

function loadGodotEngine(url: string) {
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

async function handleMissingFeatures(
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

	// FIXME(jmurzy): The game page is game.gunbarrelhaus.com, while assetBase is on
	// assets.game.gunbarrelhaus.com. Both this lookup and the following Godot
	// registration reject a service worker URL from that cross-origin host.
	const registration = await navigator.serviceWorker.getRegistration(assetBase);
	if (registration) throw new Error("Service worker already exists.");

	await engine.installServiceWorker();
	window.location.reload();
	return true;
}

async function startGodotGame(
	releaseConfig: GodotReleaseConfig,
	assetBase: string,
	canvas: HTMLCanvasElement,
	onProgress: (current: number, total: number) => void,
) {
	const serviceWorker = releaseConfig.config.serviceWorker;
	const config: GodotEngineConfig = {
		...releaseConfig.config,
		executable: new URL(releaseConfig.config.executable, assetBase).href,
		// engine.installServiceWorker() installs the service worker.
		...(serviceWorker
			? { serviceWorker: new URL(serviceWorker, assetBase).href }
			: {}),
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

type GameProgress = {
	current: number;
	total: number;
};

export function useGodotGame(
	canvasRef: RefObject<HTMLCanvasElement | null>,
	releaseConfig: GodotReleaseConfig | null,
	gameCfg: GameCfg,
	assetBase: string,
) {
	// biome-ignore lint/correctness/useExhaustiveDependencies: The game config is intentionally fixed for this mounted page.
	const stableGameCfg = useMemo(() => gameCfg, []);
	const gameStartRef = useRef<Promise<void> | undefined>(undefined);
	const onProgressRef = useRef<
		((current: number, total: number) => void) | undefined
	>(undefined);
	const [progress, setProgress] = useState<GameProgress>();
	const [notice, setNotice] = useState<string>();
	const [isReady, setIsReady] = useState(false);

	useEffect(() => {
		setIsReady(false);
		const canvas = canvasRef.current;
		if (!canvas || !releaseConfig) {
			setNotice("Game release is unavailable.");
			return;
		}

		window.GAME_CFG ??= stableGameCfg;
		setNotice(undefined);
		setProgress({ current: 0, total: 0 });

		let active = true;
		onProgressRef.current = (current, total) => {
			if (active) setProgress({ current, total });
		};
		let gameStart = gameStartRef.current;
		if (!gameStart) {
			gameStart = startGodotGame(
				releaseConfig,
				assetBase,
				canvas,
				(current, total) => {
					onProgressRef.current?.(current, total);
				},
			);
			gameStartRef.current = gameStart;
		}
		void gameStart
			.then(() => {
				if (active) {
					setProgress(undefined);
					setIsReady(true);
				}
			})
			.catch((error: unknown) => {
				console.error(error);
				if (active) {
					setNotice(error instanceof Error ? error.message : String(error));
				}
			});

		return () => {
			active = false;
			onProgressRef.current = undefined;
		};
	}, [assetBase, canvasRef, releaseConfig, stableGameCfg]);

	return { isReady, notice, progress };
}
