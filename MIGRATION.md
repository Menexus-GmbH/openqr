# Migrating Skyzai to OpenQR

This guide describes future Skyzai integration work against the local `0.1.0-draft` packages.
The package implementation and shared-fixture checks are complete; Skyzai native/web integration, devices and backend lifecycles remain unqualified.
No Skyzai, Functions, Pay SDK or Connect SDK source was changed by this extraction.
The normative wire rules are in [SPEC.md](SPEC.md), with executable examples in the [shared corpus](fixtures/README.md).

The migration order follows the 2026-10-26 OpenQR design, including its alignment with Yves' organisation.
Its app inventory was pinned to Skyzai commit `2e98a5afcfef78149f8aa01bbbaad1422f59c90e`; the fix-round verifier and QR sources were also inspected as working-tree evidence.
App-relative paths below identify migration seams, not a claim that those fixes are integrated or approved.
Reconcile them with the accepted host revision before editing.

## 0. Freeze the accepted post-fix baseline

The Skyzai integrator first records the accepted commit for F1-F5/F7/F8 and decision A, including the shared `lib/core/services/nostr_event_verifier.dart` and `PublicProfileRoute` behavior.
Retain its failing-first evidence, focused tests, independent review and analyzer baseline with no new findings.
Preserve ACK handling, account generation fences, private bank/memo containment and stale-state protections throughout extraction.
Do not mix repairs to those host features into package adoption.

Apply Skyzai's own per-file documentation, change reports, context/README updates, available project-map tooling and PENDING acceptance-workbook requirements to each host assignment.
Package test results do not close those acceptance rows.

## 1. Lock the contract and install locally

Use the nine paths, version/query rules, trust policy and never-in-a-QR list in [SPEC.md](SPEC.md) without introducing a second host grammar.
Both language suites read `fixtures/links.json` and `fixtures/records.json` directly.
When an actual issued legacy code requires compatibility, add a synthetic equivalent to that corpus and the relevant host-adapter tests before changing interpretation.
Keep compatibility decoders until their owners approve an issued-code and partner-SDK retirement path.

For a local native Flutter integration, add paths to this checkout in the consuming application's root `pubspec.yaml`:

```yaml
dependencies:
  openqr:
    path: /path/to/openqr/dart/openqr
  openqr_flutter:
    path: /path/to/openqr/flutter/openqr_flutter
dependency_overrides:
  web_socket_channel: ^3.0.1
```

The root override matches Skyzai's current resolution of its Git-pinned Nostr and Pretty QR forks; dependency-level overrides are ignored by Pub.
See the [Flutter package guide](flutter/openqr_flutter/README.md) for the pins and scanner contract.
A consumer needing only encoding, incoming-link classification and verification can depend on the [Dart core](dart/openqr/README.md) without the widget package.
Skyzai's Flutter web host uses Dart directly; it does not need a JavaScript bridge or second router.
The [TypeScript package](ts/README.md) supplies ESM and declarations for separate Node/web consumers, with no host initialization on import.

Create an `OpenQrPolicy` from host configuration, never from scanned fields.
Keep the canonical origin `https://skyzai.com`, explicitly enumerate any additional trusted HTTPS origins, and supply the existing chain-specific validators and supported network/type/asset vocabulary through `OpenQrWalletPolicy`.
The wire wallet types are `wallet` and `trading`; an unknown chain, network or type must not become a default wallet or mainnet selection.
`walletRequest` and `pairing` remain disabled until steps 6 and 7 qualify their owning services.
The corpus's enabled-reserved policy is a hypothetical test host, not approval to enable them in Skyzai.

## 2a. Qualify the native connection-review host

Start with the existing general scan-to-profile entry in `lib/features/app_user/presentation/widgets/user_info_model.dart`, its shared scanner, `QRDataHandler`, `PublicProfileRoute` and `NetworkProfile` continuation.
Lock the actual signed-in host behavior before replacing its implementation with package calls.
An offline example, package fixture, simulated receipt or M1 prototype does not qualify this host.

Keep the organisation mapping jointly **CMP-01/04** until source-pinned definitions and the connection-review proof are supplied through the existing owner channel.
Do not invent individual CMP responsibilities, appoint maintainers, fetch the private fork or adopt unrelated capability slices.
OpenQR is a reusable capability within the existing product organisation; transport, credentials, relationships, permissions and financial domain ownership remain with their owners.

| Boundary | Native acceptance required, then repeated for the web adapter |
|---|---|
| Parsing | Canonical identity, explicit `/payment`, foreign npub, wrong host, malformed input and unsupported purpose give the specified review or safe refusal. |
| Confidence | A checksum proves identifier syntax; an author/kind/exact-`d`/hash/signature check establishes only that record's provenance. Invalid, unresolved, stale, empty and error states cannot inherit previous verified evidence. |
| Permission | Follow, Save, Pay and Connect require their existing eligibility checks and explicit actions. Camera permission authorizes capture only; contact permission is limited to the confirmed public-contact write. |
| Account/caller revision | Capture session/account generation, expected UID/public author, caller instance/revision and operation generation; invalidate work on account switch, caller replacement or superseding input. |
| Cancellation/return | Cancel camera, review, permission or auth without changing the still-current caller's draft, selected wallet or focus. Discard late work after disposal or caller replacement rather than popping unrelated routes. |
| Completion | Preserve repeated-scan protection and return typed outcomes. Navigation-only acceptance cannot mark a connection, payment or ticket action complete. |
| Cancellation after dispatch | Existing services retain proof, idempotency, pending/completed state and recovery for already-dispatched operations; UI cancellation only prevents stale updates. |

Use a host-created `OpenQrInvocation` with `context`, `isCurrent` and `isCancelled` guards closing over that captured state.
Recheck `invocation.interruption` after every awaited resolution and immediately before effects, completion or caller restoration.
`run` checks before dispatch and after completion; it cannot protect effects inside a host callback that ignores its guards.
Return `handled`, `cancelled`, `obsolete` or `unsupported`; `handled` means accepted for review/navigation, not paid, admitted or approved.
Catch callback failures at the host UI boundary with finite local messages and no raw payload or exception logging.

## 2b. Delegate the proven shared boundary

After the native contract is locked, introduce the local dependencies behind small adapters and keep that host suite green.
Register host dependencies in `lib/locator.dart`; retain `RouterInfo`, authentication, storage, relays and domain services in Skyzai.

| Existing app seam | Package delegation and retained host behavior |
|---|---|
| `lib/core/services/qr/qr_data_handler.dart` and `qr_result.dart` | Call `decode` and adapt recognized targets to existing caller contracts; safe `Invalid`/`Unsupported` results end classification, without retrying the old permissive parser after a rejected origin, version or known-path shape. |
| `lib/core/utils/public_profile_route.dart` | Adapt recognized identity to the existing route shape, public key and `showPayments` intent, retaining checksum validation, the accepted trailing slash, canonical profile/Pay routes and host-owned custom-scheme app CTA construction. |
| `lib/core/services/nostr_event_verifier.dart` | Delegate public envelope checks and ordering to `isVerifiedNostrRecord`, `compareNostrRecords` or `newestVerifiedRecord`; replace the duplicated helper only after all readers are migrated. |
| `lib/features/open_qr/data/datasources/openqr_remote_data_source.dart` | Retain owner relay fetch, signing/publication, timeouts and snapshot fences; pass only supplied public envelopes to the package. No key-pair or relay client crosses the boundary. |
| `lib/features/web/data/repositories/public_web_profile_repository_impl.dart` | Keep `fetchProfile`/`fetchPayments` and public-only projection access; delegate verification/selection before domain content parsing. |
| `lib/core/services/qr/skyzai_qr_router.dart`, `lib/core/utils/intent_handler.dart` and `lib/core/utils/router.dart` | Adapt typed targets into guarded host reviews and existing app-link/auth continuations. Keep navigation outside the package and preserve each caller's scanner-pop ownership. |

Supply the raw public NIP-01 envelope with integer `created_at` seconds, string tags/content and public `id`, `pubkey`, `kind` and `sig` fields.
The package uses `publicKeyHex` for the expected author argument; the reviewed app helper used `publicKey`.
Do not let a deserializer coerce malformed timestamps, tags or null content into valid records before verification.
Bind expected kind, public author and exact `d` tag from host state, not a QR-supplied coordinate.
Skyzai kinds 30301/30302 and their UID mapping remain its custom record/content contract.

Select the newest verified envelope before parsing domain content, ordered by descending timestamp and ascending event ID for ties.
An empty replacement removes old endpoints; malformed newest content must produce the host's empty/error state without reviving older addresses.
Keep private bank details and personal memos out of public projections and receiving-record output.
Handle the package's 100-envelope batch limit and 64 KiB content limit explicitly; do not silently truncate history to manufacture a latest record.
Relay completeness, global freshness, error-versus-empty display and domain schema validation remain host responsibilities.

Legacy compatibility is explicit host code, not a new package protocol.
Install narrow adapters for real issued wallet URLs/JSON, booking JSON, payment schemes or legacy event shapes, with exact origin and domain validation.
Preserve legacy amount text until the wallet validates exact base units; do not reintroduce the reference classifier's floating-point normalization.
Never restore debug OpenQR JSON or a generic last-path-segment/raw-booking-ID fallback in the general scanner.
Connect/WalletConnect parsing stays in their SDK adapters, with the complete URI preserved.
For the strict zero-key package boundary, retain key-bearing legacy capture in the host until secret-free pairing exists.
The widget's optional opaque `onLegacy` handoff necessarily receives raw bytes and is unsuitable for a policy excluding even transient key-bearing capture.

## 2c. Qualify skyzai.com as the second consumer

Keep anonymous `/<npub>` and `/<npub>/payment` on `PublicProfilePage`, backed by get-only `publicProfiles`/`publicProfileKeys` projections and the verified public receiving-record reader.
Do not introduce anonymous `Users` reads or replace the public projection with an owner repository.
Public Pay currently discovers/copies verified receiving addresses; retain its explicit app-transfer CTA and never label it browser settlement.
Follow requires an explicit app/auth continuation; Save is a public-only VCF preview/export with current relationship and permission rules, not private-contact access.
Do not activate retained legacy Nostr web pages to obtain these actions.

Run the existing `test/web/public_profile_route_test.dart`, `public_profile_repository_test.dart` and `public_profile_integration_test.dart` against the adapter.
Add real-host cases for stale tabs, account/auth return, cancellation, permission refusal, safe external links, explicit app CTA and unchanged caller state.
Native and web execute the same contract fixtures with their own adapters; TypeScript/package import tests are separate evidence.
Only after both host slices pass should broad scanner and producer consolidation proceed.

## 3. Converge capture and preserve caller contracts

Use `OpenQrScanner(policy: ..., invocation: ..., onDecoded: ..., builder: ...)` for compatible capture surfaces.
Keep policy/invocation objects stable during ordinary rebuilds, replace the invocation on account/caller revision changes and retry explicitly when the new scope is ready.
The host builder owns chrome, localization, bounded layout, permission/settings actions, paste controls and gallery selection; pass chosen local image paths to `analyzeImage`.
Retain Material 3 and BottomAppBar navigation in changed Skyzai screens.

| Scanner/caller group under `lib/features/` | Context and adapter requirement |
|---|---|
| `qr_scanner/presentation/pages/skyzai_qr_scanner.dart`; `app_user/presentation/widgets/user_info_model.dart`; private scanner sheet in `app_user/presentation/pages/user_qr_screen.dart` | `general`; retain the current typed-return versus auto-handle contract and avoid closing a scanner twice after its sheet already returned. |
| `wallet/presentation/widgets/transfer_qr_scanner.dart`; callers `wallet_action_row.dart`, `transfer_receipent_widget.dart` and `token_transfer_screen.dart` in the same widgets directory | `pay`; adapt separately to callback, wallet-data/map and raw-recipient return shapes, preserving the wallet coordinator and unsent recipient form. |
| `connect/presentation/pages/connected_apps_screen.dart` and `skyzai_connect_screen.dart` | `connect`; preserve explicit consent and grants reload, with host-owned legacy key-bearing capture until the new exchange. |
| `wallet/presentation/widgets/event_qr_scanner.dart`; `events/presentation/pages/common/manage_event_participants.dart` | `ticketCheck`; require a typed ticket and expected event, retaining host-only lookup/admission and confining any validated raw legacy ticket support to this context. |
| `products/presentation/pages/booking_scanner_page.dart`; `manage_product_screen.dart`; `booking/presentation/pages/booking_details_page.dart` | `bookingCheck`; retain role/owner checks and authorized lookup, confining validated raw legacy booking IDs to this context. |
| `qr_scanner/presentation/pages/qr_scanner_page.dart`; `exchange/presentation/pages/dex_connect_page.dart` | `walletConnect`; keep the entire URI for `DexCubit.pairWithUri` and its explicit submit, rather than the generic router's snackbar. |

The same fixture through camera callback, gallery and paste must produce the same typed target and one dispatch despite duplicate scans.
Verify pending-review exclusion, cancellation/resume, callback/platform errors, account switch, caller replacement, background/foreground and disposal through the real host adapter.
Capture stays paused after handled/unsupported/errors/obsolete work until explicit retry; a cancelled review resumes only if the invocation remains current and uncancelled.
Use safe camera-denied/unavailable/no-code states with paste or supported gallery alternatives.
The old `lib/core/platform/qr_scanner*.dart` web stub is not proof of working web capture; remove wrappers only after each supported platform is qualified.

| Typed target | Existing host continuation |
|---|---|
| Identity | `RouterInfo`/`NetworkProfile` or public `PublicProfilePage`; bare identity suggests Pay review from `pay`, Follow/Save from `network`, and Follow/Pay/Save from `general`, while explicit `/payment` keeps Pay intent in every context. |
| Wallet address | Adapt to `WalletQrData` and `WalletQrFlowCoordinator.start`, retaining chain availability, self-send, exact asset and confirmation checks; foreign Hedera candidates keep unknown network/type until host review and never become a fabricated person. |
| Payment | `SkyzaiPayConfirmationScreen(paymentId: ...)`, with authoritative payment type, current proof, expiry and recovery behavior. |
| Booking session | `WebBookingConfirmationPage(sessionId: ...)`, with existing auth and session expiry checks. |
| Booking reference | `IBookingRepository.getBookingById` and authorized `BookingDetailsPage`, retaining expected booking/owner constraints. |
| Ticket | Host-only `verifyTicket`, expected-event comparison in `checkParticipantStatus`, then the event owner's `AttendanceMarkingDialog`/check-in contract. |
| Pairing or wallet request | Finite unavailable/unsupported state until the respective owning resolver is qualified, without routing wallet requests to merchant payment confirmation by default. |
| Legacy Connect/WalletConnect | Existing `PairingRequest.parse`/`ConnectConsentScreen` or `DexCubit.pairWithUri` inside the host boundary. |

A ticket, invoice or booking retains its purpose even when scanned from Pay or Network.
Unknown/foreign HTTPS input gets an explicit external-link preview or safe refusal, never automatic browser launch.
Follow still uses `FollowFollowingCubit.followUser` after confirmation; Save still uses the host preview, eligibility and `FlutterContacts.insertContact` permission flow.
Optional-avatar failures and existing contact-feature repairs remain separately owned.

## 4. Unify personal QR producers

Generate each static personal code as `encode(IdentityLink(npub: ..., publicKeyHex: ...), policy: ...)`, yielding `https://skyzai.com/<npub>`.
Use `OpenQrView` for typed rendering while the host retains sharing, screenshots, saving, wallpaper and optional public VCF export.
The default widget has no avatar/center-image customization; preserve required host branding/export through a separately qualified renderer rather than assuming those options exist.

| Producers under `lib/features/` | Migration |
|---|---|
| `app_user/presentation/pages/user_qr_screen.dart`; `network_user/presentation/pages/network_social_media_list.dart` | Emit identical personal identity URLs, preserving current share/save/wallpaper affordances. |
| `information_management/widgets/links_bar.dart` | Make the static Wallet Link QR personal identity; keep `/payment` for explicit Pay hyperlinks and old scanned images. |
| `network_user/presentation/widgets/profile/profile_qr_section.dart`; `profile_share_dialog.dart` in that directory; `network_user/presentation/pages/network_profile_nostr_web.dart` callers | Consolidate reached profile QR surfaces and replace QR VCard content with identity while preserving explicit public `.vcf` sharing, without activating unused routes. |
| `user_profile/presentation/widgets/qr_view.dart` | Delegate validated rendering, retaining accessibility, contrast, quiet zone and host export behavior. |
| `wallet/presentation/pages/trading_wallet_qr_page.dart`; `wallet/presentation/widgets/transfer_qr_scanner.dart` share sheets | Default personal Hedera receive to identity; retain deliberate trading/external chain/address choices as typed `/wallet/<address>` links with explicit network/type/asset policy. |
| `open_qr/presentation/widgets/open_qr_section.dart` | Replace diagnostic JSON display according to accepted decision A, without establishing a JSON OpenQR protocol. |

Treat `share_qr_screen.dart` and `custom_qr_widget.dart` as inventory candidates until an active caller is established.
Leave commented QR examples in `business_home_bottom_bar.dart` and `receive_widget.dart` inactive.
Check identical strings across personal producers, context-specific reviews, old `/payment`, foreign-recipient evidence, self-send protections, quiet zone/contrast/semantics, large text and local capacity errors.

## 5. Migrate purpose producers with their owners

For merchant and booking payments, coordinate `functions/src/payment/createPayment.ts`, `getPayment.ts`, `cancelPayment.ts`, the booking payment dialog and `aureus-pay-sdk/src/Payment.js`.
Emit `/pay/<paymentId>?v=1` as the new `qrCode` consistently across all three responses while retaining the existing `deepLink` during compatibility.
Account for stored legacy `qrCode` values as well as response fallbacks; updating only payment creation leaves older get/cancel responses inconsistent.
Keep `Payment._update`/`getQRCode` server-value precedence and legacy fallback.
Require SDK contract tests for all three responses plus current expiry, proof, recovery and idempotence regressions.

Keep `web_booking_qr_dialog.dart` and `PendingWebBooking` on `/booking/<sessionId>`, with optional `v=1` for new output.
Change `booking_details_page.dart` and `booking_qr_dialog.dart` output from booking/user/product/variant JSON to `/bookings/<bookingId>?v=1` after the host resolver is ready.
Omit excess identifiers and local issued timestamps; backend terms, auth and expected-owner checks remain authoritative.
Keep `web_booking_qr_dialog_test.dart` and issued-code fixtures passing.

Unify both normal/expanded `user_event_qr_ticket.dart` renderers, `functions/src/applePass.ts`, `generateGoogleWalletURL.ts` and `event_repository.dart` wallet-pass inputs around `/verify/<ticketRef>`.
Preserve issued references and wallet-pass validity; caller-supplied pass barcodes and the legacy `eventId:userId` fallback are not authenticated admission.
Require wrong-host, wrong-event, expired and duplicate-admission tests under the event owner's policy, including any approved multi-entry behavior.
`verifyTicket` is an authenticated host lookup, not atomic consumption; retain or implement the owner's separate check-in operation.
A URL GET, preview, unfurl or decode must never pay, grant access or consume a ticket.

## 6. Enable real wallet amount requests only after lifecycle qualification

The wallet owner must supply authoritative creation, resolution, expiry and atomic single-use settlement for `/request/<requestId>?v=1` before enabling `OpenQrKind.walletRequest`.
Then migrate the amount cards in `trading_wallet_qr_page.dart`, `transfer_screen.dart` and `receive_qr_bottom_sheet.dart` away from `amt` URLs and inline token/value JSON.
Retain HBAR/HTS/EVM scope; do not reuse a merchant-only USDC service for unsupported assets.
Bind exact decimal/base-unit amount, recipient, network, chain, stable asset, limits, expiry and purpose to backend terms.
Qualify concurrent/repeated settlement, account switching, rejected/replayed proof, cancelled requests and pending recovery.
Until then, existing amount-bearing wallet URLs remain repeatable hints reviewed by the wallet, not one-use invoices.

## 7. Enable secret-free Connect only after exchange approval

The Connect owner must approve a reference-based exchange and migrate `skyzai_connect_sdk/packages/consumer-ts/src/pairing/create.ts`, host consent and backend together before enabling `OpenQrKind.pairing`.
New `/connect/<pairingId>?v=1` codes carry only a nonsecret reference, never `symKey`, a token or a nested secret-bearing URI.
Do not replace key-in-QR with an anonymously retrievable plaintext-key endpoint.
Require app identity, requested scopes, initiator/session binding, expiry, authenticated key agreement, replay protection and already-approved/mismatched-session tests.
Preserve old partner-code support through the host adapter and preserve the strict zero-key capture boundary described in step 2b.
OpenQR implements reference encoding/classification only; key handling, grant delivery and consent stay with Connect.

## 8. Broaden web/OS support and prepare a separately authorized release

After both real host slices pass, add purpose landing pages only as each host resolver becomes available.
Show finite unavailable/expired/used states and explicit app continuation without exposing private booking/participant data to anonymous previews.
Use no-store/no-referrer for resource-reference pages, exclude third-party analytics there and remove full payload/URL logging from migrated paths.
Resolve through fixed trusted services; any future user-influenced server URL fetch must use the host's hardened fetch helper.
Never automatically redirect to signed `preferredDomain` metadata.

Preserve existing profile/Pay custom-scheme CTAs until purpose mappings are registered in both intent handling and platform manifests.
Keep a safe typed pending target across auth; do not promise deferred-install return, which is not proven.
Keep static association files ahead of SPA fallback and preserve API/agent-commerce rewrites.
Run `test/web/public_profile_hosting_test.dart` and focused route checks; qualify Android installed/not-installed cold/warm links, auth return, store fallback, gallery and foreground/background on devices.
iOS AASA/HTTPS Universal Links remain owner-deferred; retain browser and explicit app/store fallback without guessing a Team ID or enabling AASA.
Retire old scanners only after caller parity and platform qualification.

All three packages are currently `0.1.0-draft` and blocked from publication by `publish_to: none` or npm `private`.
Before an authorized release, check names/ownership, MIT notices, dependency licenses, Git-pin/hosted-package eligibility, archives, exported types/imports and browser/runtime acceptance.
Choose reviewed hosted dependencies or approved fork publication for Dart without silently replacing cryptography.
Consumers with a private `@menexus-gmbh` registry mapping need deliberate public-registry configuration; do not require an APU token or copy restricted registry settings.
Repository creation, publication, deployment and cloud operations are outside this local migration guide.

## Local package checks and remaining acceptance

Run the existing checks from the indicated directory:

| Directory | Commands |
|---|---|
| Repository root | `node --test fixtures/integrity.test.mjs` |
| `dart/openqr` | `dart pub get`, `dart test`, `dart analyze --fatal-infos`, `dart format --output=none --set-exit-if-changed lib test` |
| `flutter/openqr_flutter` | `flutter pub get`, `flutter test --no-pub`, `dart analyze --fatal-infos`, `dart format --output=none --set-exit-if-changed lib test` |
| `ts/` | `npm ci --ignore-scripts`, `npm test`, `npm run format:check`, `npm pack --dry-run --ignore-scripts` |

`npm test` includes JavaScript/declaration build, exported consumer typechecking and Node/browser-condition import checks.
Package fixtures and widget tests establish local conformance only; the native/web acceptance gates above, cameras, permissions, OS links, live relays and real payment/admission remain PENDING.
Signature validity cannot prove a human, address ownership, global record freshness or settlement; host guards cannot undo an already-dispatched action.
