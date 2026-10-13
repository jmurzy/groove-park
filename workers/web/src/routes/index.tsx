import { env } from "cloudflare:workers";
import { createFileRoute } from "@tanstack/react-router";
import { createServerFn } from "@tanstack/react-start";
import { useRef } from "react";
import { LoadingBar } from "#/components/LoadingBar/LoadingBar";
import { Snowfall } from "#/components/Snowfall/Snowfall";
import { useFullscreen } from "#/hooks/useFullscreen";
import { useGameInputLock } from "#/hooks/useGameInputLock";
import { useGodotGame, type HeavenlyCfg } from "#/hooks/useGodotGame";
import { getGameReleaseConfig, getGameReleaseId } from "#/server/gameReleases";
import { securityHeadersMiddleware } from "#/middleware/securityHeadersMiddleware";
import styles from "./index.module.css";

const getReleasesUrl = createServerFn({ method: "GET" }).handler(
	() => env.GAME_RELEASES_URL,
);

const getGameApiUrl = createServerFn({ method: "GET" }).handler(
	() => env.GAME_API_URL,
);

const getResortSlug = createServerFn({ method: "GET" }).handler(
	() => env.RESORT_SLUG,
);

export const Route = createFileRoute("/")({
	server: {
		middleware: [securityHeadersMiddleware],
	},
	loader: async () => ({
		releaseConfig: await getGameReleaseConfig(),
		releaseId: await getGameReleaseId(),
		gameApiUrl: await getGameApiUrl(),
		resortSlug: await getResortSlug(),
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
	const { gameApiUrl, releaseConfig, releaseId, releasesUrl, resortSlug } =
		Route.useLoaderData();
	const canvasRef = useRef<HTMLCanvasElement>(null);
	useGameInputLock(canvasRef, Boolean(releaseId && releaseConfig));
	const toggleFullscreen = useFullscreen(canvasRef);

	const assetBase = `${releasesUrl}/releases/${releaseId}/`;
	const heavenlyCfg: HeavenlyCfg = {
		game_api: { base_url: gameApiUrl, resort_slug: resortSlug },
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
