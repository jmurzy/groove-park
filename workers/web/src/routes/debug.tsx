import { env } from "cloudflare:workers";
import { createFileRoute } from "@tanstack/react-router";
import { createServerFn } from "@tanstack/react-start";
import ThemeToggle from "#/components/ThemeToggle";
import { getGameReleaseConfig, getGameReleaseId } from "#/server/gameReleases";

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

export const Route = createFileRoute("/debug")({
	loader: async () => ({
		exampleMessage2: await getExampleMessage2(),
		hasExampleSecret2: await getExampleSecret2Status(),
		hasExampleSecret: await getExampleSecretStatus(),
		releaseId: await getGameReleaseId(),
		releaseConfig: JSON.stringify(await getGameReleaseConfig()),
	}),
	component: DebugPage,
});

function DebugPage() {
	const {
		hasExampleSecret,
		exampleMessage2,
		hasExampleSecret2,
		releaseId,
		releaseConfig,
	} = Route.useLoaderData();

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
			<pre>
				<code>{releaseConfig ?? "Release config unavailable."}</code>
			</pre>
		</main>
	);
}
