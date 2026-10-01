import type { Context } from "hono";

export type WorkerEnv = Env & { LIFTIE_USER_AGENT: string; TZ: string };
export type WorkerApp = import("hono").Hono<{ Bindings: WorkerEnv }>;
export type WorkerContext = Context<{ Bindings: WorkerEnv }>;
