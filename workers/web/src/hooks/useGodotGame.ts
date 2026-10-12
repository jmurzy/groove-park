import { useEffect, useRef, useState, type RefObject } from "react";
import type { GodotReleaseConfig } from "#/server/game-releases";
import { startGodotGame } from "#/util/godot";

type GameProgress = {
	current: number;
	total: number;
};

export function useGodotGame(
	canvasRef: RefObject<HTMLCanvasElement | null>,
	releaseConfig: GodotReleaseConfig | null,
	assetBase: string,
	gameApiUrl: string,
) {
	const gameStartRef = useRef<Promise<void> | undefined>(undefined);
	const onProgressRef = useRef<
		((current: number, total: number) => void) | undefined
	>(undefined);
	const [progress, setProgress] = useState<GameProgress>();
	const [notice, setNotice] = useState<string>();

	useEffect(() => {
		const canvas = canvasRef.current;
		if (!canvas || !releaseConfig) {
			setNotice("Game release is unavailable.");
			return;
		}

		window.HEAVENLY_CFG ??= {
			leaderboard_api: { base_url: gameApiUrl },
		};
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
		};
	}, [assetBase, canvasRef, gameApiUrl, releaseConfig]);

	return { notice, progress };
}
