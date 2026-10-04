export function json(value: unknown, status = 200, headers?: HeadersInit): Response {
	return Response.json(value, { status, headers });
}

export function error(code: string, status: number, headers?: HeadersInit): Response {
	return json({ error: { code } }, status, headers);
}

export async function requestJson(
	request: Request,
): Promise<{ ok: true; value: Record<string, unknown> } | { ok: false; response: Response }> {
	try {
		const value: unknown = await request.json();
		if (!value || typeof value !== "object" || Array.isArray(value)) {
			return { ok: false, response: error("INVALID_JSON", 400) };
		}
		return { ok: true, value: value as Record<string, unknown> };
	} catch {
		return { ok: false, response: error("INVALID_JSON", 400) };
	}
}
