/** Pure rules shared by checkout, publication and regression tests. Money is calculated in cents. */
export const DAY = 86_400_000;
export const DURATIONS = [1, 7, 14, 30];

function text(value: unknown, label: string, max = 200): string {
  if (typeof value !== "string" || !value.trim() || value.length > max) throw new Error(`Invalid ${label}`);
  return value.trim();
}
function finite(value: unknown, label: string): number {
  if (typeof value !== "number" || !Number.isFinite(value)) throw new Error(`Invalid ${label}`);
  return value;
}
export function bountyQuote(pool: unknown) {
  const value = finite(pool, "bounty pool");
  const poolCents = Math.round(value * 100);
  if (value < 5 || value > 5000 || Math.abs(value * 100 - poolCents) > 0.00001) {
    throw new Error("Pick a bounty between $5 and $5,000, with at most two decimal places");
  }
  const feeCents = Math.round(poolCents / 10);
  return { pool: poolCents / 100, platformFee: feeCents / 100, totalAmount: (poolCents + feeCents) / 100 };
}

/** The app sends coordinates as [lat, lng]; older callers and tests send { lat, lng }. */
function point(value: any): { lat?: unknown; lng?: unknown } | undefined {
  if (Array.isArray(value)) return { lat: value[0], lng: value[1] };
  return value ?? undefined;
}

export function normalizeBounty(input: any) {
  if (!input || typeof input !== "object") throw new Error("Choose a bounty location");
  const quote = bountyQuote(input.pool);
  const center = point(input.center);
  const lat = finite(center?.lat, "latitude");
  const lng = finite(center?.lng, "longitude");
  if (Math.abs(lat) > 90 || Math.abs(lng) > 180) throw new Error("Invalid coordinates");
  const kind = text(input.target?.kind, "target type", 10);
  // `area` and missing new fields support older installed clients and pending records.
  if (!["place", "street", "city", "area"].includes(kind)) throw new Error("Choose a place, street, or city");
  const radius = finite(input.radius, "coverage radius");
  const limit = kind === "place" ? 500 : kind === "street" ? 5000 : 50_000;
  if (radius < 1 || radius > limit) throw new Error("Coverage radius is outside the supported range");
  const durationDays = input.durationDays ?? input.days ?? 14;
  if (!Number.isInteger(durationDays) || !DURATIONS.includes(durationDays)) throw new Error("Choose 1, 7, 14, or 30 days");
  const maxExplorers = input.maxExplorers ?? input.videos ?? Math.max(3, Math.min(20, Math.floor(quote.pool / 10)));
  if (!Number.isInteger(maxExplorers) || maxExplorers < 1 || maxExplorers > 20) throw new Error("Choose 1 to 20 explorers");
  const target: any = { kind, name: text(input.target?.name ?? input.target?.place?.name ?? input.title, "location name") };
  if (kind === "place") target.placeId = text(input.target?.placeId, "place identifier", 250);
  // Store a minimal location snapshot so remote place details survive app restarts.
  if (input.target?.place) {
    const p = input.target.place;
    const coords = point(p.coords);
    if (finite(coords?.lat, "place latitude") !== lat || finite(coords?.lng, "place longitude") !== lng) {
      throw new Error("Location coordinates must match the bounty center");
    }
    target.place = { id: text(p.id, "place identifier", 250), name: text(p.name, "place name"), coords: { lat, lng }, photo: "" };
    if (p.address != null && p.address !== "") target.place.address = text(p.address, "address", 500);
    if (p.source != null && p.source !== "") target.place.source = text(p.source, "place source", 30);
    if (kind === "place" && p.id !== target.placeId) throw new Error("Location identifier must match the bounty target");
  }
  const estimatedRewardCents = Math.floor(Math.round(quote.pool * 100) / maxExplorers);
  return {
    sponsor: text(input.sponsor ?? "An explorer", "sponsor", 100),
    logo: "star", color: "#2b59ff", title: text(input.title, "bounty title"),
    target, center: { lat, lng }, radius, ...quote,
    split: "videos", firstBonus: 0, videos: maxExplorers, maxExplorers,
    recorded: 0, crew: [], days: durationDays, durationDays,
    estimatedReward: estimatedRewardCents / 100,
  };
}

export function expiryFor(data: any, startedAt: number): number {
  const duration = data?.durationDays ?? 14;
  return startedAt + (Number.isInteger(duration) && duration > 0 ? duration : 14) * DAY;
}

export function isBountyActive(row: { active: boolean; createdAt: number; expiresAt?: number; data: any }, now: number): boolean {
  const expires = row.expiresAt ?? row.data?.expiresAt ?? expiryFor(row.data, row.createdAt);
  return row.active && expires > now && (row.data?.recorded ?? 0) < (row.data?.maxExplorers ?? row.data?.videos ?? 1);
}

function money(value: any): number {
  const amount = value && typeof value === "object" ? value.amount : value;
  if (typeof amount !== "string" && typeof amount !== "number") return NaN;
  return Number(amount);
}

/** The caller supplies a payment retrieved server-to-server from Whop, never client payment data. */
export function paymentMatches(payment: any, row: { bountyId: string; checkoutId: string; amount: number; accountId?: string; requestId?: string }) {
  const status = String(payment?.status ?? "").toLowerCase();
  const substatus = String(payment?.substatus ?? "").toLowerCase();
  const paid = ["paid", "succeeded"].includes(status) && !["failed", "refunded", "partially_refunded", "auto_refunded", "blocked", "void", "canceled"].includes(substatus);
  const amount = money(payment?.total ?? payment?.amount_charged ?? payment?.final_amount ?? payment?.amount);
  const currency = String(payment?.total?.currency ?? payment?.currency ?? "").toLowerCase();
  const refunded = money(payment?.refunded_amount ?? 0);
  const bountyId = payment?.metadata?.bountyId ?? payment?.membership?.metadata?.bountyId;
  const checkoutId = payment?.checkout_configuration_id ?? payment?.checkout_configuration?.id;
  return !!payment?.id && paid && !payment?.refunded_at && !payment?.auto_refunded && refunded === 0 &&
    Number.isFinite(amount) && Math.round(amount * 100) === Math.round(row.amount * 100) && currency === "usd" &&
    bountyId === row.bountyId && (!row.accountId || (payment.account_id ?? payment.account?.id ?? payment.company?.id) === row.accountId) &&
    (checkoutId === row.checkoutId || (!row.requestId && !checkoutId));
}
