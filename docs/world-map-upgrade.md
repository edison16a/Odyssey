# World Map and bounty upgrade

Implemented in the existing native SwiftUI app on November 15, 2026. This extends the Home map renderer and PR #7's Whop/Convex checkout flow.

## Implemented behavior

- World Map replaces Friends in the bottom bar. Friends remains the same experience, reached beside Notifications in the Home header. Profile, recommendation links, demo links, and `odyssey://friends` still reach Friends.
- Home's large blue Open Map button opens the World Map tab and clears a previously pushed place-details screen. Old explored-map links route to this same tab; their separate map implementation has been removed.
- `WorldMapView` uses `HomeMapView` / `HomeMapCanvas` for both the preview and main map. `WorldMapState` shares camera position, selected destination, visible results, and amenity filters. Bounty-target state and device location are separate.
- Both surfaces support Odyssey pins, native Apple Maps place selection, place preview/details, existing deals and contributor history, amenities where source data exists, directions, and bounty targets. Search destinations have persistent selectable markers.
- Current Location explicitly requests a recent Core Location fix and animates the camera. Panning/searching does not enable tracking or replace the selected bounty target. Denied permission offers Settings; unavailable GPS reports an error.
- One reusable `LocationSearch` service provides MapKit autocomplete and global address/business/street/city search to the map and bounty form. Neither search path needs GPS. Search requests cancel obsolete results.
- Find Nearby uses the visible map center, MapKit searches, and verified Convex amenity points. It includes bathroom, parking, Wi-Fi, water, elevator, study, and café searches; accessible entrances appear only when explicit nearby source tags exist. Results fit the camera, remain tappable, and can be cleared. Parking price, capacity, availability, and accessibility are not invented.
- Existing synthetic amenity tags/pins are shown only in demo mode and labeled accordingly. Real amenities require recorded source tags or verified points. Missing amenity details stay unknown.
- All bounty creation entry points use the full-screen **Create a Bounty** form. It supports changing remote targets, place/street/city coverage, coordinates and map preview, $5–$5,000 pools, 1/7/14/30 days, 1–20 explorers, estimated shares, and a checkout summary. The server supplies a fee quote and the authoritative checkout amount and sandbox flag.
- What are bounties? sheets explain funding, publication, permission to record, and future verification/payout stages. Funded bounties never credit the old simulated cash-payout path. Seed bounties remain visibly labeled as demos.
- Active map surfaces refresh bounty data every 30 seconds. Owner history refreshes saved legacy records with canonical expiry, and duplicate identifiers are merged.

## Backend and compatibility

`bounties` adds optional expiry, duration, maximum explorers, target type, center, radius, pool, platform fee, and total fields. `bountyCheckouts` adds those funding fields plus draft request ID, hosted checkout URL, account, and sandbox status. New indexes cover owner/request ID and payment ID. Amenity verification is optional. All additions preserve older table shapes.

The existing `data` payload remains compatible with older clients; new records also retain `days` and `videos`. New fields are normalized and validated server-side. Missing new fields use the legacy duration/explorer behavior; records without a custom duration expire after 14 days from publication. New durations start at verified payment confirmation. Street and city target types use coverage radii when matching places, and a minimal place snapshot lets remote details survive app restarts.

Checkout computes reward pool and the 10% fee in integer cents. Estimated per-explorer shares round down to cents so allocation cannot exceed the pool. One pending record is reserved per owner/draft, and retries reuse Whop's idempotency key. Closing or returning from hosted checkout never publishes a bounty.

Signed payment events retrieve the canonical Whop payment and check paid status, amount, currency, checkout, account, refund state, and bounty metadata before publication. Event receipt and publication commit atomically. Duplicate events and sync checks preserve one live record and its original expiry; a payment cannot fund multiple bounties. Failed/mismatched events remain retryable. Sync recovery uses supported time filters and pagination, checking up to 1,000 recent receipts per invocation. The legacy public mutation that bypassed checkout now rejects publication.

## Verification actually performed

- `npm test`: **66 tests passed**, using the actual Convex schema and function handlers in `convex-test`, with mocked Whop HTTP responses. Coverage includes target/money/duration/explorer validation, remote creation without GPS, fee and allocation bounds, pending visibility, verified publication, duplicate events, expiry, old pending records, owner history/privacy, closed legacy publication, signed/tampered/stale webhooks, canonical-payment mismatches, paginated recovery, and timeout retries with stable idempotency keys.
- `npm run typecheck`: **passed** for the Convex backend.
- `swiftc -frontend -parse` against the **31 changed production Swift files**: **passed**. This verifies syntax only, not SwiftUI/MapKit type checking or iOS linking.
- `git diff --check`: **passed**.
- Added native Swift Testing cases for navigation, shared map routing, camera/target independence, legacy decoding, payout blocking, expiry/deduplication, explicit amenities, and matching a venue across map providers. **Not executed** here.
- `xcodebuild -list -project Odyssey.xcodeproj`: unavailable; the selected developer directory contains Command Line Tools, and no Xcode installation was found.
- `xcrun simctl` and `xcrun devicectl`: unavailable. Simulator and physical-device tests could not run.
- Full-source parsing was attempted with the installed Swift 5.8 toolchain and fails on existing newer Swift syntax and Swift Testing macros. No full-app build success is claimed.
- `convex codegen --typecheck enable`: could not run because this checkout has no `CONVEX_DEPLOYMENT` configured. Existing generated API declarations already infer added exports from `whop.ts`/`social.ts` and the data-model declaration reads the schema; backend TypeScript checking passes.

## Remaining validation and limits

The iOS build, gesture behavior, sheet layout on device sizes, live MapKit autocomplete/search, GPS prompts/recentering, and navigation regressions still require Xcode and a simulator/device. Follow these scenarios before release:

1. From Home, open Friends and Notifications, return, and tap Open Map; confirm World Map is selected even after previously opening place details there.
2. Pan and zoom, tap Odyssey/native business pins, open details/deals/history, and request directions.
3. Search for a Berkeley café while the device is in San Francisco (and with GPS denied); select it, move the camera elsewhere, and confirm the bounty target remains independent.
4. Test Current Location with not-determined, allowed, denied, and unavailable GPS states. Pan afterward and confirm the map stays where the user leaves it.
5. Test bathroom and parking searches, marker selection, directions, and Clear. Check accessibility is hidden without explicit data.
6. Create place/street/city bounties with each duration and boundary amounts/explorer limits. Confirm the fee, final charge, saved fields, and approximate coverage preview.
7. In the configured Whop sandbox, abandon checkout and verify no publication, then complete a test payment and verify exactly one bounty appears. Deliver a duplicate signed event and repeat sync. Restart the app and verify owner history/expiry.
8. Run the full native test suite and smoke-test Home, Explore, Friends, Profile, and existing scan flows.

No Convex deployment or real hosted Whop sandbox transaction was performed from this checkout. Existing Whop environment variables (`WHOP_API_KEY`, `WHOP_WEBHOOK_SECRET`, `WHOP_ENVIRONMENT`, `WHOP_PLAN_ID`, and the existing return-site configuration) must be present in the target deployment. Deploy the updated schema/functions with the app changes and verify the hosted sandbox path before release.

Street and city coverage is an approximate 350 m / 3 km radius around the chosen result, not an official street corridor or municipal boundary. MapKit results and explicit amenity coverage depend on provider data and connectivity; source search results do not guarantee seating, accessibility, or access. Contribution approval and real-money explorer payouts remain unimplemented; displayed shares are estimates.

## API references consulted

- [Apple: search completer region and worldwide default](https://developer.apple.com/documentation/mapkit/mklocalsearchcompleter/region)
- [Apple: tappable map features](https://developer.apple.com/documentation/mapkit/mapfeature)
- [Apple: resolving map features to map items](https://developer.apple.com/documentation/mapkit/mkmapitemrequest)
- [Whop: idempotent POST requests](https://docs.whop.com/developer/api/idempotency)
- [Whop: canonical payment fields](https://docs.whop.com/api-reference/payments/retrieve-payment)
- [Whop: supported payment filters and pagination](https://docs.whop.com/api-reference/payments/list-payments)
- [Convex: function tests with the schema](https://docs.convex.dev/testing/convex-test)

## Files changed

- Updated: `Odyssey/App/AppRouter.swift`
- Updated: `Odyssey/App/MainShell.swift`
- Updated: `Odyssey/App/RouteViews.swift`
- Added: `Odyssey/Features/Bounty/BountyInfoSheet.swift`
- Updated: `Odyssey/Features/Bounty/BountyParts.swift`
- Updated: `Odyssey/Features/Bounty/BountySheet.swift`
- Updated: `Odyssey/Features/Bounty/SetBountyFlow.swift`
- Removed: `Odyssey/Features/Business/BountyWizardSteps.swift`
- Updated: `Odyssey/Features/Business/BountyWizardView.swift`
- Updated: `Odyssey/Features/DemoGuide/DemoGuideJumps.swift`
- Updated: `Odyssey/Features/Friends/FriendsTab.swift`
- Updated: `Odyssey/Features/Home/HomeAmenities.swift`
- Updated: `Odyssey/Features/Home/HomeMapCanvas.swift`
- Updated: `Odyssey/Features/Home/HomeMapMarkers.swift`
- Updated: `Odyssey/Features/Home/HomeMapView.swift`
- Updated: `Odyssey/Features/Home/HomePlacePreview.swift`
- Updated: `Odyssey/Features/Home/HomeTab.swift`
- Added: `Odyssey/Features/Home/WorldMapState.swift`
- Added: `Odyssey/Features/Home/WorldMapView.swift`
- Added: `Odyssey/Features/Place/PlaceAmenityDetails.swift`
- Updated: `Odyssey/Features/Place/PlaceSections.swift`
- Updated: `Odyssey/Features/Profile/ProfileHeader.swift`
- Updated: `Odyssey/Features/Travel/ExploredMapView.swift`
- Updated: `Odyssey/Models/MoreModels.swift`
- Updated: `Odyssey/Services/Cloud/Cloud.swift`
- Added: `Odyssey/Services/LocationSearch.swift`
- Updated: `Odyssey/Services/LocationService.swift`
- Updated: `Odyssey/Services/WorldPlaces.swift`
- Updated: `Odyssey/Store/AppStore+Amenities.swift`
- Updated: `Odyssey/Store/AppStore+Bounties.swift`
- Updated: `Odyssey/Store/AppStore+Places.swift`
- Updated: `Odyssey/Store/AppStore.swift`
- Updated: `OdysseyTests/OdysseyTests.swift`
- Updated: `convex/amenities.ts`
- Added: `convex/bountyRules.ts`
- Updated: `convex/schema.ts`
- Updated: `convex/social.ts`
- Updated: `convex/whop.ts`
- Added: `docs/world-map-upgrade.md`
- Updated: `package-lock.json`
- Updated: `package.json`
- Added: `tests/bounties.test.ts`
- Added: `vitest.config.ts`
