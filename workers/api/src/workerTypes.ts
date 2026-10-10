import type { Context } from "hono";

import type { ApiWorkerEnv } from "../alchemy.run";
import type { RequestVariables } from "./utils/observability";

export type WorkerApp = import("hono").Hono<{ Bindings: ApiWorkerEnv; Variables: RequestVariables }>;
export type WorkerContext = Context<{ Bindings: ApiWorkerEnv; Variables: RequestVariables }>;
