import { env } from "cloudflare:workers";
import { useRef } from "react";
import { createFileRoute } from "@tanstack/react-router";
import { createServerFn } from "@tanstack/react-start";
import { LoadingBar } from "#/components/LoadingBar/LoadingBar";
import { Snowfall } from "#/components/Snowfall/Snowfall";
import { getGameReleaseConfig, getGameReleaseId } from "#/server/gameReleases";
import { useGameInputLock } from "#/hooks/useGameInputLock";
import { useFullscreen } from "#/hooks/useFullscreen";
import { useGodotGame } from "#/hooks/useGodotGame";
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
	head: ({ loaderData }) => ({
		meta: [
			{ title: loaderData?.releaseConfig.projectName },
			{
				name: "viewport",
				content: "width=device-width, user-scalable=no, initial-scale=1.0",
			},
		],
	}),
	component: IndexPage,
});

function IndexPage() {
	const { gameApiUrl, releaseConfig, releaseId, releasesUrl } =
		Route.useLoaderData();
	const canvasRef = useRef<HTMLCanvasElement>(null);
	useGameInputLock(canvasRef, Boolean(releaseId && releaseConfig));
	const toggleFullscreen = useFullscreen(canvasRef);

	const assetBase = `${releasesUrl}/releases/${releaseId}/`;
	const heavenlyCfg = {
		leaderboard_api: { base_url: gameApiUrl },
	};
	const { notice, progress } = useGodotGame(
		canvasRef,
		releaseConfig,
		heavenlyCfg,
		assetBase,
	);
	const isShowingSplash = progress || notice;

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
			{isShowingSplash && (
				<div className={styles.status}>
					<Snowfall />
					<div className={styles.content}>
						<img
							className={styles.splash}
							src={new URL(releaseConfig.splash, assetBase).href}
							alt=""
						/>
						{notice ? (
							<div className={styles.notice}>{notice}</div>
						) : (
							progress && (
								<LoadingBar current={progress.current} total={progress.total} />
							)
						)}
					</div>
				</div>
			)}
			{!isShowingSplash && (
				<button
					className={styles.fullscreen}
					onClick={toggleFullscreen}
					type="button"
				>
					Fullscreen
				</button>
			)}
		</main>
	);
}
