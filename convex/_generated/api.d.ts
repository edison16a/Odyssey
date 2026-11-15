/* eslint-disable */
/**
 * Generated `api` utility.
 *
 * THIS CODE IS AUTOMATICALLY GENERATED.
 *
 * To regenerate, run `npx convex dev`.
 * @module
 */

import type * as admin from "../admin.js";
import type * as adventures from "../adventures.js";
import type * as auth from "../auth.js";
import type * as files from "../files.js";
import type * as history from "../history.js";
import type * as http from "../http.js";
import type * as lib from "../lib.js";
import type * as memory from "../memory.js";
import type * as phoneAuth from "../phoneAuth.js";
import type * as places from "../places.js";
import type * as recommend from "../recommend.js";
import type * as scanAnalysis from "../scanAnalysis.js";
import type * as scans from "../scans.js";
import type * as seed from "../seed.js";
import type * as social from "../social.js";
import type * as taste from "../taste.js";
import type * as users from "../users.js";

import type {
  ApiFromModules,
  FilterApi,
  FunctionReference,
} from "convex/server";

declare const fullApi: ApiFromModules<{
  admin: typeof admin;
  adventures: typeof adventures;
  auth: typeof auth;
  files: typeof files;
  history: typeof history;
  http: typeof http;
  lib: typeof lib;
  memory: typeof memory;
  phoneAuth: typeof phoneAuth;
  places: typeof places;
  recommend: typeof recommend;
  scanAnalysis: typeof scanAnalysis;
  scans: typeof scans;
  seed: typeof seed;
  social: typeof social;
  taste: typeof taste;
  users: typeof users;
}>;

/**
 * A utility for referencing Convex functions in your app's public API.
 *
 * Usage:
 * ```js
 * const myFunctionReference = api.myModule.myFunction;
 * ```
 */
export declare const api: FilterApi<
  typeof fullApi,
  FunctionReference<any, "public">
>;

/**
 * A utility for referencing Convex functions in your app's internal API.
 *
 * Usage:
 * ```js
 * const myFunctionReference = internal.myModule.myFunction;
 * ```
 */
export declare const internal: FilterApi<
  typeof fullApi,
  FunctionReference<any, "internal">
>;

export declare const components: {};
