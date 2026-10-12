import { useEffect, useRef, useState } from "react";
import { createFileRoute } from "@tanstack/react-router";
import {
	getGameReleaseConfig,
	getGameReleaseId,
	type GodotEngineConfig,
	type GodotReleaseConfig,
} from "#/server/game-releases";

const GAME_ASSET_ORIGIN = "https://assets.game.gunbarrelhaus.com";
const GAME_API_ORIGIN = "https://api.game.gunbarrelhaus.com";

export const Route = createFileRoute("/")({
	loader: async () => ({
		releaseConfig: await getGameReleaseConfig(),
		releaseId: await getGameReleaseId(),
	}),
	component: IndexPage,
});

function IndexPage() {
	const { releaseConfig, releaseId } = Route.useLoaderData();
	const canvasRef = useRef<HTMLCanvasElement>(null);
	const [progress, setProgress] = useState<{ current: number; total: number }>();
	const [notice, setNotice] = useState<string>();

	useEffect(() => {
		const canvas = canvasRef.current;
		if (!canvas || !releaseId || !releaseConfig) {
			setNotice("Game release is unavailable.");
			return;
		}

		window.HEAVENLY_CFG ??= {
			leaderboard_api: { base_url: GAME_API_ORIGIN },
		};
		setNotice(undefined);
		setProgress({ current: 0, total: 0 });

		const preventPointerEvent = (event: Event) => {
			event.preventDefault();
			event.stopImmediatePropagation();
			canvas.focus();
		};
		const preventScroll = (event: KeyboardEvent) => {
			if (["ArrowUp", "ArrowDown", "ArrowLeft", "ArrowRight", " "].includes(event.key)) {
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
		void startGame(releaseId, releaseConfig, canvas, (current, total) => {
			if (active) setProgress({ current, total });
		})
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
	}, [releaseConfig, releaseId]);

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
		<main style={pageStyle}>
			<canvas ref={canvasRef} id="canvas" style={canvasStyle} tabIndex={0}>
				Your browser does not support the canvas tag.
			</canvas>
			{(progress || notice) && (
				<div style={statusStyle}>
					{notice ? (
						<div style={noticeStyle}>{notice}</div>
					) : (
						<progress
							aria-label="Loading game"
							style={progressStyle}
							value={progress?.current || undefined}
							max={progress?.total || undefined}
						/>
					)}
				</div>
			)}
			<button onClick={toggleFullscreen} style={fullscreenStyle} type="button">
				Fullscreen
			</button>
		</main>
	);
}

async function startGame(
	releaseId: string,
	releaseConfig: GodotReleaseConfig,
	canvas: HTMLCanvasElement,
	onProgress: (current: number, total: number) => void,
) {
	const assetBase = `${GAME_ASSET_ORIGIN}/releases/${releaseId}/`;
	const config: GodotEngineConfig = {
		...releaseConfig.config,
		executable: new URL(releaseConfig.config.executable, assetBase).href,
	};
	await loadEngine(new URL(releaseConfig.url, assetBase).href);
	if (!window.Engine) throw new Error("Game engine failed to load.");

	const engine = new window.Engine(config);
	const missing = window.Engine.getMissingFeatures({ threads: releaseConfig.threadsEnabled });
	if (missing.length !== 0) {
		if (
			config.serviceWorker &&
			config.ensureCrossOriginIsolationHeaders &&
			"serviceWorker" in navigator
		) {
			await navigator.serviceWorker.getRegistration(assetBase).then((registration) => {
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

const pageStyle = {
	background: "black",
	bottom: 0,
	left: 0,
	margin: 0,
	overflow: "hidden",
	position: "fixed",
	right: 0,
	top: 0,
	"touchAction": "none",
} as const;

const canvasStyle = { display: "block", outline: "none" } as const;
const statusStyle = {
	alignItems: "center",
	background: "black",
	display: "flex",
	inset: 0,
	justifyContent: "center",
	position: "absolute",
} as const;
const progressStyle = { width: "50%" } as const;
const noticeStyle = {
	background: "#5b3943",
	border: "1px solid #9b3943",
	borderRadius: "0.5rem",
	color: "#e0e0e0",
	fontFamily: "Arial, sans-serif",
	lineHeight: 1.3,
	margin: "0 2rem",
	padding: "1rem",
	textAlign: "center",
	whiteSpace: "pre-line",
} as const;
const fullscreenStyle = {
	background: "#10233d",
	border: "1px solid #65d9ef",
	borderRadius: ".25rem",
	bottom: "1rem",
	color: "white",
	padding: ".6rem .8rem",
	position: "fixed",
	right: "1rem",
	zIndex: 1,
} as const;
