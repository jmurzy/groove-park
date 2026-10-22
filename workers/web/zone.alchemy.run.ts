import * as Alchemy from "alchemy";
import { adopt } from "alchemy/AdoptPolicy";
import * as Cloudflare from "alchemy/Cloudflare";
import * as Effect from "effect/Effect";

const ROOT_ZONE_NAME = "gunbarrelhaus.com";

const zone = Cloudflare.Zone.Zone("GunbarrelHausZone", {
	name: ROOT_ZONE_NAME,
}).pipe(adopt(true));

const redirects = (zone: Cloudflare.Zone.Zone) =>
	Cloudflare.Ruleset.Ruleset("GunbarrelHausRedirects", {
		zone,
		phase: "http_request_dynamic_redirect",
		name: "default",
		description: "",
		rules: [
			{
				description:
					"Permanently upgrades every HTTP request to the equivalent HTTPS URL.",
				expression: '(http.request.full_uri wildcard r"http://*")',
				action: "redirect",
				actionParameters: {
					fromValue: {
						preserveQueryString: false,
						statusCode: 301,
						targetUrl: {
							expression: `wildcard_replace(http.request.full_uri, r"http://*", r"https://\${1}")`,
						},
					},
				},
			},
			{
				description:
					"Permanently redirects HTTPS requests from www.gunbarrelhaus.com to the canonical gunbarrelhaus.com hostname.",
				expression: '(http.request.full_uri wildcard r"https://www.*")',
				action: "redirect",
				actionParameters: {
					fromValue: {
						preserveQueryString: false,
						statusCode: 301,
						targetUrl: {
							expression: `wildcard_replace(http.request.full_uri, r"https://www.*", r"https://\${1}")`,
						},
					},
				},
			},
			{
				description:
					"Temporarily redirects /city/complaints to the City of South Lake Tahoe complaints document.",
				expression:
					'(http.request.full_uri eq "https://gunbarrelhaus.com/city/complaints")',
				action: "redirect",
				actionParameters: {
					fromValue: {
						preserveQueryString: false,
						statusCode: 302,
						targetUrl: {
							value: "https://www.cityofslt.gov/documentcenter/view/23701",
						},
					},
				},
			},
			{
				description:
					"Temporarily redirects /city/code to the City of South Lake Tahoe vacation-home-rental code page.",
				expression:
					'(http.request.full_uri eq "https://gunbarrelhaus.com/city/code")',
				action: "redirect",
				actionParameters: {
					fromValue: {
						preserveQueryString: false,
						statusCode: 302,
						targetUrl: {
							value: "https://www.cityofslt.gov/2510/Vacation-Home-Rentals",
						},
					},
				},
			},
			{
				description:
					"Temporarily redirects /friendsandfamily to the California Lodge ski-in/ski-out Notion page.",
				expression:
					'(http.request.full_uri eq "https://gunbarrelhaus.com/friendsandfamily")',
				action: "redirect",
				actionParameters: {
					fromValue: {
						preserveQueryString: false,
						statusCode: 302,
						targetUrl: {
							value:
								"https://booming-pail-96c.notion.site/California-Lodge-Ski-in-Ski-out-a4d98210dac74b04bf93ae492d778234",
						},
					},
				},
			},
			{
				description:
					"Temporarily redirects /house-rules to the Gunbarrel House Rules Notion document.",
				expression:
					'(http.request.full_uri eq "https://gunbarrelhaus.com/house-rules")',
				action: "redirect",
				actionParameters: {
					fromValue: {
						preserveQueryString: false,
						statusCode: 302,
						targetUrl: {
							value:
								"https://www.notion.so/Gunbarrel-House-Rules-342526ec956780c0844dd915e5d25ceb?source=copy_link",
						},
					},
				},
			},
			{
				description:
					"Temporarily redirects the site homepage to the Gunbarrel House welcome Notion page.",
				expression: '(http.request.full_uri eq "https://gunbarrelhaus.com/")',
				action: "redirect",
				actionParameters: {
					fromValue: {
						preserveQueryString: false,
						statusCode: 302,
						targetUrl: {
							value:
								"https://www.notion.so/Welcome-to-Gunbarrel-House-34a526ec9567802c8fb2e36582e0bcd8",
						},
					},
				},
			},
		],
	});

const records = (zone: Cloudflare.Zone.Zone) =>
	Effect.gen(function* () {
		yield* Cloudflare.DNS.Record("GunbarrelHausApex", {
			zoneId: zone.zoneId,
			name: ROOT_ZONE_NAME,
			type: "A",
			content: "192.0.2.1",
			proxied: true,
		}).pipe(adopt(true));
		yield* Cloudflare.DNS.Record("GunbarrelHausWww", {
			zoneId: zone.zoneId,
			name: `www.${ROOT_ZONE_NAME}`,
			type: "A",
			content: "192.0.2.1",
			proxied: true,
		}).pipe(adopt(true));
		yield* Cloudflare.DNS.Record("GunbarrelHausMail", {
			zoneId: zone.zoneId,
			name: ROOT_ZONE_NAME,
			type: "MX",
			content: "alt1.aspmx.l.google.com",
			priority: 20,
			ttl: "1",
			proxied: false,
		}).pipe(adopt(true));
		yield* Cloudflare.DNS.Record("GunbarrelHausGoogleVerification", {
			zoneId: zone.zoneId,
			name: ROOT_ZONE_NAME,
			type: "TXT",
			content:
				'"google-site-verification=HmJP6iMPBF6H5LM9k6g3UvIIYOuKyCFQeqKPkd72jDQ"',
			ttl: "1",
			proxied: false,
		}).pipe(adopt(true));
	});

export default Alchemy.Stack(
	"gunbarrelhaus-redirects",
	{ providers: Cloudflare.providers(), state: Cloudflare.state() },
	Effect.gen(function* () {
		const managedZone = yield* zone;
		yield* Cloudflare.Rum.Site("GunbarrelHausWebAnalytics", {
			zoneTag: managedZone.zoneId,
			enabled: true,
			autoInstall: true,
			lite: false,
		}).pipe(adopt(true));
		yield* records(managedZone);
		const ruleset = yield* redirects(managedZone);
		return { rulesetId: ruleset.rulesetId };
	}),
);
