import { env } from "cloudflare:workers";
import { createFileRoute } from "@tanstack/react-router";
import { createServerFn } from "@tanstack/react-start";
import ThemeToggle from "#/components/ThemeToggle";

const RELEASE_POINTER_KEY = "current.json";
const RELEASE_ID = /^[0-9a-f]{40}$/;

const exampleMessage = import.meta.env.VITE_EXAMPLE_MESSAGE;
const exampleSecret = import.meta.env.EXAMPLE_SECRET;
const getExampleSecretStatus = createServerFn({ method: "GET" }).handler(() =>
	Boolean(process.env.EXAMPLE_SECRET),
);

const getExampleMessage2 = createServerFn({ method: "GET" }).handler(
	() => env.EXAMPLE_MESSAGE_2,
);
const getExampleSecret2Status = createServerFn({ method: "GET" }).handler(() =>
	Boolean(env.EXAMPLE_SECRET_2),
);

const getReleaseId = createServerFn({ method: "GET" }).handler(async () => {
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
});

export const Route = createFileRoute("/")({
	loader: async () => ({
		exampleMessage2: await getExampleMessage2(),
		hasExampleSecret2: await getExampleSecret2Status(),
		hasExampleSecret: await getExampleSecretStatus(),
		releaseId: await getReleaseId(),
	}),
	component: App,
});

function App() {
	const { hasExampleSecret, exampleMessage2, hasExampleSecret2, releaseId } =
		Route.useLoaderData();

	return (
		<main>
			<ThemeToggle />
			<p>Meta env var value: {exampleMessage}</p>
			<p>meta env secret: {exampleSecret}</p>
			<p>meta env secret configured: {hasExampleSecret ? "yes" : "no"}</p>
			<br />
			<br />
			<p>Cloudflare Worker environment value: {exampleMessage2}</p>
			<p>
				Cloudflare Worker secret configured: {hasExampleSecret2 ? "yes" : "no"}
			</p>
			<p>Game release ID: {releaseId ?? "unavailable"}</p>
		</main>
	);
}
