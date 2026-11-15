import { httpRouter } from "convex/server";
import { auth } from "./auth";
import { confirmHttp } from "./phoneAuth";
import { returnPage, webhook } from "./whop";

const http = httpRouter();
auth.addHttpRoutes(http);
http.route({ path: "/phone-auth/confirm", method: "POST", handler: confirmHttp });
http.route({ path: "/whop", method: "POST", handler: webhook });
http.route({ path: "/whop/return", method: "GET", handler: returnPage });

export default http;
