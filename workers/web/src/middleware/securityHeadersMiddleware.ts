import { createMiddleware } from "@tanstack/react-start";
import { getStartContext } from "@tanstack/start-storage-context";
import { env } from "cloudflare:workers";

function createNonce() {
	const bytes = crypto.getRandomValues(new Uint8Array(16));
	return btoa(String.fromCharCode(...bytes));
}

const tanStackDevtoolsStyleSrc = [
	"style-src 'self' 'unsafe-inline' https://fonts.googleapis.com",
	"style-src-attr 'unsafe-inline'",
];

function securityHeaders(nonce: string) {
	return {
		"Content-Security-Policy": [
			"default-src 'self'",
			"base-uri 'self'",
			"object-src 'none'",
			"frame-ancestors 'none'",
			"form-action 'self'",
			`script-src 'self' 'nonce-${nonce}' 'wasm-unsafe-eval' ${env.GAME_RELEASES_URL}`,
			...(import.meta.env.DEV
				? tanStackDevtoolsStyleSrc
				: ["style-src 'self' https://fonts.googleapis.com"]),
			"font-src 'self' data: https://fonts.gstatic.com",
			`img-src 'self' blob: data: ${env.GAME_RELEASES_URL}`,
			`connect-src 'self' ${env.GAME_API_URL} ${env.GAME_RELEASES_URL}`,
			`worker-src 'self' blob: ${env.GAME_RELEASES_URL}`,
		].join("; "),
		"Permissions-Policy":
			"camera=(), geolocation=(), microphone=(), payment=(), usb=()",
		"Referrer-Policy": "strict-origin-when-cross-origin",
		"Strict-Transport-Security": "max-age=31536000; includeSubDomains",
		"X-Content-Type-Options": "nosniff",
		"X-Frame-Options": "DENY",
	};
}

export const securityHeadersMiddleware = createMiddleware().server(
	async ({ next }) => {
		const nonce = createNonce();
		const router = await getStartContext().getRouter();

		router.update({
			ssr: { ...router.options.ssr, nonce },
		});

		const result = await next();

		for (const [name, value] of Object.entries(securityHeaders(nonce))) {
			result.response.headers.set(name, value);
		}

		return result;
	},
);
