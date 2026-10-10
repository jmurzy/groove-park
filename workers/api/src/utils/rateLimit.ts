import { error } from "./http";
import type { ApiWorkerEnv } from "../../alchemy.run";

const INSTALLATION_ID_HEADER = "X-Installation-Id";
const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

export async function limitIpRequest(request: Request, env: ApiWorkerEnv): Promise<Response | null> {
	const ipAddress = request.headers.get("CF-Connecting-IP") ?? "unknown";
	const result = await env.IP_RATE_LIMIT.limit({ key: `ip:${ipAddress}` });
	return result.success ? null : error("RATE_LIMITED", 429, { "Retry-After": "60" });
}

export async function limitInstallationRequest(request: Request, env: ApiWorkerEnv): Promise<Response | null> {
	const installationId = request.headers.get(INSTALLATION_ID_HEADER);
	if (!installationId) return error("MISSING_INSTALLATION_ID", 400);
	if (!UUID_PATTERN.test(installationId)) return error("INVALID_INSTALLATION_ID", 400);

	const result = await env.INSTALLATION_RATE_LIMIT.limit({ key: `installation:${installationId}` });
	return result.success ? null : error("RATE_LIMITED", 429, { "Retry-After": "60" });
}
