import { env } from "cloudflare:workers";
import { useEffect, useRef, useState } from "react";
import { createFileRoute } from "@tanstack/react-router";
import { createServerFn } from "@tanstack/react-start";
import {
	getGameReleaseConfig,
	getGameReleaseId,
	type GodotEngineConfig,
	type GodotReleaseConfig,
} from "#/server/game-releases";
import styles from "./index.module.css";

const getReleasesUrl = createServerFn({ method: "GET" }).handler(
	() => env.GAME_RELEASES_URL,
);

const getGameApiUrl = createServerFn({ method: "GET" }).handler(
	() => env.GAME_API_URL,
);

export const Route = createFileRoute("/")({
	loader: async () => ({
		releaseConfig: await getGameReleaseConfig(),
		releaseId: await getGameReleaseId(),
		gameApiUrl: await getGameApiUrl(),
		releasesUrl: await getReleasesUrl(),
	}),
	component: IndexPage,
});

function IndexPage() {
	const { gameApiUrl, releaseConfig, releaseId, releasesUrl } =
		Route.useLoaderData();
	const canvasRef = useRef<HTMLCanvasElement>(null);
	const gameStartRef = useRef<Promise<void> | undefined>(undefined);
	const onProgressRef = useRef<
		((current: number, total: number) => void) | undefined
	>(undefined);
	const [progress, setProgress] = useState<{
		current: number;
		total: number;
	}>();
	const [notice, setNotice] = useState<string>();

	useEffect(() => {
		const canvas = canvasRef.current;
		if (!canvas || !releaseId || !releaseConfig) {
			setNotice("Game release is unavailable.");
			return;
		}

		window.HEAVENLY_CFG ??= {
			leaderboard_api: { base_url: gameApiUrl },
		};
		setNotice(undefined);
		setProgress({ current: 0, total: 0 });

		const preventPointerEvent = (event: Event) => {
			event.preventDefault();
			event.stopImmediatePropagation();
			canvas.focus();
		};
		const preventScroll = (event: KeyboardEvent) => {
			if (
				["ArrowUp", "ArrowDown", "ArrowLeft", "ArrowRight", " "].includes(
					event.key,
				)
			) {
				event.preventDefault();
			}
		};

		for (const eventName of [
			"pointerdown",
			"pointerup",
			"pointermove",
			"pointerenter",
			"pointerleave",
			"click",
		]) {
			canvas.addEventListener(eventName, preventPointerEvent, true);
		}
		document.addEventListener("keydown", preventScroll);
		document.addEventListener("keyup", preventScroll);

		let active = true;
		onProgressRef.current = (current, total) => {
			if (active) setProgress({ current, total });
		};
		let gameStart = gameStartRef.current;
		if (!gameStart) {
			gameStart = startGame(
				releaseId,
				releaseConfig,
				releasesUrl,
				canvas,
				(current, total) => {
					onProgressRef.current?.(current, total);
				},
			);
			gameStartRef.current = gameStart;
		}
		void gameStart
			.then(() => {
				if (active) setProgress(undefined);
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
			for (const eventName of [
				"pointerdown",
				"pointerup",
				"pointermove",
				"pointerenter",
				"pointerleave",
				"click",
			]) {
				canvas.removeEventListener(eventName, preventPointerEvent, true);
			}
			document.removeEventListener("keydown", preventScroll);
			document.removeEventListener("keyup", preventScroll);
		};
	}, [gameApiUrl, releaseConfig, releaseId, releasesUrl]);

	async function toggleFullscreen() {
		const canvas = canvasRef.current;
		if (!canvas) return;

		try {
			if (document.fullscreenElement) await document.exitFullscreen();
			else await canvas.requestFullscreen();
			canvas.focus();
		} catch {
			// Fullscreen is optional and browsers may reject it due to local policy.
		}
	}

	return (
		<main className={styles.page}>
			<canvas
				ref={canvasRef}
				id="canvas"
				className={styles.canvas}
				tabIndex={0}
			>
				Your browser does not support the canvas tag.
			</canvas>
			{(progress || notice) && (
				<div className={styles.status}>
					{notice ? (
						<div className={styles.notice}>{notice}</div>
					) : (
						<progress
							aria-label="Loading game"
							className={styles.progress}
							value={progress?.current || undefined}
							max={progress?.total || undefined}
						/>
					)}
				</div>
			)}
			<button
				className={styles.fullscreen}
				onClick={toggleFullscreen}
				type="button"
			>
				Fullscreen
			</button>
		</main>
	);
}

async function startGame(
	releaseId: string,
	releaseConfig: GodotReleaseConfig,
	releasesUrl: string,
	canvas: HTMLCanvasElement,
	onProgress: (current: number, total: number) => void,
) {
	const assetBase = `${releasesUrl}/releases/${releaseId}/`;
	const config: GodotEngineConfig = {
		...releaseConfig.config,
		executable: new URL(releaseConfig.config.executable, assetBase).href,
	};
	await loadEngine(new URL(releaseConfig.url, assetBase).href);
	if (!window.Engine) throw new Error("Game engine failed to load.");

	const engine = new window.Engine(config);
	const missing = window.Engine.getMissingFeatures({
		threads: releaseConfig.threadsEnabled,
	});
	if (missing.length !== 0) {
		if (
			config.serviceWorker &&
			config.ensureCrossOriginIsolationHeaders &&
			"serviceWorker" in navigator
		) {
			await navigator.serviceWorker
				.getRegistration(assetBase)
				.then((registration) => {
					if (registration) throw new Error("Service worker already exists.");
					return engine.installServiceWorker();
				});
			window.location.reload();
			return;
		}
		throw new Error(
			`The following features required to run the game are missing:\n${missing.join("\n")}`,
		);
	}

	await engine.startGame({ canvas, onProgress });
}

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
		HEAVENLY_CFG?: {
			leaderboard_api: { base_url: string };
		};
	}
}

let engineScriptPromise: Promise<void> | undefined;

function loadEngine(source: string) {
	engineScriptPromise ??= new Promise((resolve, reject) => {
		const script = document.createElement("script");
		script.src = source;
		script.async = true;
		script.onload = () => resolve();
		script.onerror = () => reject(new Error("Game engine failed to load."));
		document.head.append(script);
	});
	return engineScriptPromise;
}
