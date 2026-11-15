import { httpRouter } from "convex/server";
import { auth } from "./auth";
import { confirmHttp } from "./phoneAuth";

const http = httpRouter();
auth.addHttpRoutes(http);
http.route({ path: "/phone-auth/confirm", method: "POST", handler: confirmHttp });

export default http;
