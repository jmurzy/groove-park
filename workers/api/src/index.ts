import { Hono } from "hono";

import { getLeaderboard, qualifyLeaderboard, submitLeaderboard } from "./leaderboard/handlers";
import { getResort } from "./liftie/handlers";
import { error } from "./utils/http";
import type { WorkerEnv } from "./workerTypes";

export { GlobalLeaderboard } from "./leaderboard/durableObject";

const app = new Hono<{ Bindings: WorkerEnv }>();

app.get("/api/liftie/resort/:resortName", getResort);

app.get("/api/leaderboard", getLeaderboard);
app.post("/api/leaderboard/qualify", qualifyLeaderboard);
app.post("/api/leaderboard/submissions", submitLeaderboard);

app.notFound(() => error("NOT_FOUND", 404));

export default app;
