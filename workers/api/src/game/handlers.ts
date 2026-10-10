import type { ApiWorkerEnv } from "../../alchemy.run";
import type { WorkerContext } from "../workerTypes";

const RELEASE_POINTER_KEY = "current.json";
const RELEASE_ID = /^[0-9a-f]{40}$/;

export async function getGame(context: WorkerContext): Promise<Response> {
	const releaseId = await getReleaseId(context);
	if (!releaseId) return new Response("Game release is unavailable.", {
			status: 503,
			headers: { "Cache-Control": "no-store" },
		});

	const index = await context.env.GAME_RELEASES.get(`releases/${releaseId}/index.html`);
	if (!index) {
		return new Response("Game release is unavailable.", {
			status: 503,
			headers: { "Cache-Control": "no-store" },
		});
	}

	const headers = new Headers();
	index.writeHttpMetadata(headers);
	headers.set("Content-Type", "text/html; charset=utf-8");
	headers.set("Cache-Control", "no-store");

	// Set security headers
	const nonce = crypto.randomUUID();
	const assets = context.env.GAME_ASSET_ORIGIN;
	headers.set(
		"Content-Security-Policy",
		[
			"default-src 'none'",
			`base-uri ${assets}`,
			`connect-src ${context.env.GAME_API_ORIGIN} ${assets}`,
			`img-src 'self' data: blob: ${assets}`,
			`script-src 'nonce-${nonce}' 'strict-dynamic' 'wasm-unsafe-eval' ${assets}`,
			"style-src 'unsafe-inline'",
			"frame-ancestors 'none'",
			"form-action 'none'",
		].join("; "),
	);
	headers.set("Permissions-Policy", "camera=(), geolocation=(), microphone=(), payment=(), usb=()");
	headers.set("Referrer-Policy", "no-referrer");
	headers.set("X-Content-Type-Options", "nosniff");
	headers.set("X-Frame-Options", "DENY");

	return new HTMLRewriter()
		.on("head", {
			element(element) {
				element.prepend(
					`<base href="${context.env.GAME_ASSET_ORIGIN}/releases/${releaseId}/">${webConfig(context.env, nonce)}`,
					{ html: true },
				);
			},
		})
		.on("script", {
			element(element) {
				element.setAttribute("nonce", nonce);
			},
		})
		.transform(new Response(index.body, { headers }));
}

function webConfig(env: ApiWorkerEnv, nonce: string): string {
	const cfg = JSON.stringify({
		leaderboard_api: { base_url: env.GAME_API_ORIGIN },
	}).replaceAll("<", "\\u003c");
	return `<script nonce="${nonce}">window.HEAVENLY_CFG=${cfg};</script>`;
}

async function getReleaseId(context: WorkerContext): Promise<string | null> {
	const pointer = await context.env.GAME_RELEASES.get(RELEASE_POINTER_KEY);
	if (!pointer) return null;
	try {
		const value: unknown = JSON.parse(await pointer.text());
		if (!value || typeof value !== "object" || Array.isArray(value)) return null;
		const release = (value as { release?: unknown }).release;
		return typeof release === "string" && RELEASE_ID.test(release) ? release : null;
	} catch {
		return null;
	}
}
