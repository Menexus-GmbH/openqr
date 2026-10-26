# OpenQR link specification v1

Status: draft contract for the local OpenQR implementation.
Link-spec v1 is independent of package versions and Nostr record schemas; the initial package release is planned as `0.1.0`.
This specification follows the supplied OpenQR `DESIGN.md` dated 2026-10-26, including its joint CMP-01/04 connection-review boundary.

## Scope and ownership

OpenQR encodes public links, classifies scanned text, verifies supplied public Nostr records, and provides a host callback contract.
Flutter widgets capture and render codes using existing scanner and QR dependencies.
The package performs no HTTP, relay or Firestore I/O and owns no authentication, application routes, wallet, signing, settlement, contact storage or access grants.
It never obtains signing keys, transfers money, consumes a ticket or approves a connection.
Successful parsing identifies a public key or reference; it does not verify a person or authorize an action.

## Origins and canonical paths

Skyzai's canonical origin is exactly `https://skyzai.com`, with no userinfo or nondefault port.
Canonical output omits an explicit default port.
Another host may explicitly configure its own canonical HTTPS origin and exact accepted origins; wildcard domains and preferred-domain redirects are not allowed.
An identical path on an untrusted origin is never a Skyzai target.

Placeholders below are illustrative, not valid literal IDs.
All paths and query names are case-sensitive.

| Path | Query emitted | Kind | Meaning |
|---|---|---|---|
| `/<npub>` | None | `identity` | Stable personal QR, with profile intent. |
| `/<npub>/payment` | None | `identity` | Existing explicit Pay entry, with pay intent. |
| `/pay/<paymentId>` | `v=1` | `payment` | Merchant, booking or ticket payment reference; host record determines the payment type. |
| `/request/<requestId>` | `v=1` | `walletRequest` | Reserved amount-request reference; host owns terms, expiry and consumption. |
| `/booking/<sessionId>` | Optional `v=1` | `bookingSession` | Temporary browser-to-phone booking handoff. |
| `/bookings/<bookingId>` | `v=1` | `booking` | Booking reference for authorized lookup or checking. |
| `/verify/<ticketRef>` | Optional `v=1` | `ticket` | Existing ticket reference; resolution is separate from check-in. |
| `/connect/<pairingId>` | `v=1` | `pairing` | Reserved nonsecret pairing reference. |
| `/wallet/<address>` | Required `v=1`, `chain`, `network`, `type`; optional `asset` | `walletAddress` | Explicit chain-specific or external-wallet receive link. |

The personal QR remains `/<npub>` wherever displayed, including an ordinary wallet-link sheet.
Explicit Pay hyperlinks and old `/payment` QR images remain supported.
Task-specific codes remain distinct from that stable identity.

### Segment and wallet fields

`npub` must have a valid Bech32 checksum, decode to exactly one 32-byte public key, and round-trip exactly to canonical lowercase form.
Preserve the existing `PublicProfileRoute` behavior for ordinary identity links, including decoder compatibility for one terminal slash; canonical output omits that slash.
New Nostr aliases belong at the decoder boundary.

Opaque reference IDs are one decoded segment matching `[A-Za-z0-9_-]{1,128}`.
Their appearance conveys no authorization or meaning.
A real issued legacy reference outside this grammar requires fixtures and an explicit adapter owned by that domain.
Addresses use their selected chain's validation rather than the opaque-reference grammar.

`chain` is an explicitly supported host chain key, `network` an explicitly supported ledger/network identifier, and `type` the host's existing wallet/trading vocabulary.
Unknown values are unsupported and must never default to Hedera, mainnet or checking.
`asset`, when supplied, is a stable identifier validated against the selected chain; ticker text alone cannot select a token.
New wallet-address links carry no amount.
Legacy amount text stays decimal text without floating-point conversion; exact base units, precision, limits and fees are host responsibilities.

### Reserved targets

`walletRequest` and `pairing` are disabled until the host explicitly enables the corresponding tested resolver and lifecycle.
The encoder refuses their emission while disabled, and decoding yields a finite unsupported/unavailable result without executing them.
An amount request must not be sent to a merchant payment handler without a matching host request adapter.
Connect must approve a reference-based, authenticated, replay-safe exchange before `/connect` is emitted.
Wrapping the current `symKey` payload in HTTPS, or making the key anonymously downloadable, does not satisfy that gate.

## Versions, query fields and input validation

- Bare identity and `/payment` output keep their compact unversioned form.
  New purpose links emit exactly one `v=1`, with the optional version forms for `/booking` and `/verify` retained as listed above.
  Unversioned existing paths decode as v1 compatibility forms; existing wallet URLs may instead require their host legacy adapter.
  An unknown or duplicated version is unsupported, with no legacy fallback that bypasses this refusal.
- Reject unknown query fields on v1 purpose links and duplicate keys on every known link.
  Existing profile URLs may discard only explicitly allowlisted non-action analytics fields such as `utm_source`, `utm_medium` and `utm_campaign`; canonical identity output contains none.
  A query-supplied `action`, `redirect`, `return_url`, relay URL, address or amount cannot override a record reference.
- Canonical output contains no fragment.
  Reject fragments on known purpose links instead of concealing extra instructions there.
- Cap raw input at 4 KiB (4096 UTF-8 bytes), trim only outer whitespace, and reject embedded controls, malformed UTF-8 or escapes, encoded path separators, backslashes, dot segments and extra segments.
  Decode each segment once and reject an encoded separator still revealed by double decoding.
  Validate the original representation before a platform URL parser can normalize away forbidden path syntax.
- Apply decoder precedence in this order: size/encoding checks, exact trusted HTTPS origin, supported version and exact path, Nostr public identifiers, narrow foreign Hedera form, explicit host legacy adapter, then unknown.
  A rejected known link cannot fall through to a permissive legacy parser.
- Results and diagnostics use safe reason enums, never the scanned value.
  Unknown/foreign HTTPS links may receive a host external-link preview, but never automatic browser launch or execution.

## Decoder-only compatibility and foreign codes

Canonical encoders never emit custom schemes, inline JSON or foreign codes.
Keep compatibility decoders for old printed codes until their owners approve retirement; there is no automatic removal date.

| Input family | Classification and boundary |
|---|---|
| `skyzai://profile/<npub>[/payment]` | Compatible identity after the same public-key validation, preserving explicit Pay intent. |
| `skyzai://pay?id=...` | Compatible payment through an explicit adapter and reference validation. |
| Existing wallet URLs/JSON | Host legacy adapter preserves recipient, chain and amount review; `amt` is a repeatable hint, not a single-use invoice. |
| Booking JSON, legacy event intents | Explicit domain adapters; raw booking IDs or ticket references are allowed only in their specialized host context. |
| Raw `npub...` or `nostr:npub...` | Foreign public identity after checksum and canonical public-key validation, without a Skyzai user claim. |
| `nostr:nprofile...` | Optional public-identifier support; decode the public key and ignore untrusted relay hints instead of connecting to them. |
| Other valid Nostr identifier kinds | Unsupported, never silently reinterpreted as people. |
| `nsec...` or `nostr:nsec...` | Invalid secret material, with no value included in the result or diagnostics. |
| Raw `0.0.<number>` or `hedera:0.0.<number>` | Foreign Hedera account candidate; preserve supported checksum suffixes for ledger-aware host validation and leave missing network unknown. |
| Other `hedera:` forms | Foreign/unsupported pending real issuer fixtures and wallet-owner grammar; arbitrary query parameters are not payment instructions. |
| WalletConnect (`wc:`), current `skyzai-connect:` | Opaque legacy protocol classification only; existing host SDK owns parsing and consent. |
| Retired debug OpenQR JSON | Unsupported; no new JSON OpenQR protocol. |

A foreign account never becomes a verified Skyzai person, and digits alone never select a ledger.
The Nostr public/private prefix distinction is described in [NIP-19](https://github.com/nostr-protocol/nips/blob/master/19.md) and [NIP-21](https://github.com/nostr-protocol/nips/blob/master/21.md).
OpenQR may recognize a legacy pairing scheme but must not parse, persist, log, verify, encrypt or expose its keys as typed values.
Legacy raw bytes are never a property of a serializable public decode result.
Where the zero-key boundary excludes even transient opaque capture, key-bearing legacy codes remain in the host capture adapter until secret-free pairing ships.

## Never in a newly encoded QR

- Bank account details or linked private contacts.
- Private-key material, seed phrases, `nsec` or symmetric encryption keys.
- Provider/API keys, auth cookies/JWTs or merchant credentials.
- Long-lived access/refresh tokens, full signed transactions or personal wallet memos.
- Inline profile/payment JSON, Firebase UID or relay lists in the personal code.

These exclusions also apply to query strings, fragments and nested/base64 payloads.
Opaque ticket/request/session references are short-lived or resource-scoped references, not reusable authorization credentials.
IDs never replace host authentication and backend authorization.
Existing event-duration ticket references and secret-bearing Connect codes are not retroactively made compliant by this contract.

## Typed boundary and invocation

Dart enums and TypeScript literal unions share this vocabulary.
`OpenQrLink` is a sealed/discriminated union with the fields below.

| Kind | Public fields |
|---|---|
| `identity` | `npub`, `publicKeyHex`, `intent` (`profile` or `pay`) |
| `payment` | `paymentId` |
| `walletRequest` | `requestId` |
| `bookingSession` | `sessionId` |
| `booking` | `bookingId` |
| `ticket` | `ticketRef` |
| `pairing` | `pairingId` |
| `walletAddress` | `address`, `chain`, `network`, `walletType`, optional `asset`; foreign candidates retain missing information for host review |

`decode(raw, policy)` returns `recognized(link, source)`, `legacy(protocol)`, `invalid(reason)` or `unsupported(reason)`.
Sources distinguish canonical, compatible/custom-scheme and foreign input without changing authorization.
Safe reasons include `malformed`, `untrustedOrigin`, `secretMaterial`, `unsupportedVersion` and `unknownKind`.
`LegacyProtocol` identifies wallet JSON/URL, booking JSON/ID, ticket legacy, WalletConnect or Connect without decoding their keys.

`encode(link, policy)` produces a validated canonical URI in Dart and URL string in TypeScript.
It refuses foreign, legacy, secret-bearing and disabled reserved targets.
`OpenQrPolicy` contains the canonical origin, exact accepted origins and enabled target kinds, with no auth client, relay client or private configuration.
Host-supported wallet vocabulary and any compatibility adapter are explicit rather than inferred from scanned data.

Scan contexts are `general`, `pay`, `network`, `connect`, `bookingCheck`, `ticketCheck` and `walletConnect`.
`OpenQrHandler` is an asynchronous host callback taking a typed link and an `OpenQrInvocation`; it is not a screen registry or an auto-executing router.
The invocation carries context plus host-supplied `isCurrent()` and `isCancelled()` guards over account/session generation, caller revision, caller return state and operation generation.
The QR cannot supply or replace those guards.
Check them after each awaited resolution and immediately before any host effect, completion or caller restoration.

| Outcome | Meaning |
|---|---|
| `handled` | Accepted for review/navigation, without claiming payment, admission or consent. |
| `cancelled` | Review ended without applying an action. |
| `obsolete` | Account, caller or operation changed; discard the late result. |
| `unsupported` | No enabled host continuation; show a finite local result. |

Pause capture before calling the host once; resume only on cancellation or explicit retry and prevent concurrent dispatch.
The host UI catches callback errors without reporting payloads globally.
Cancellation cannot undo an already dispatched transfer, grant or admission; its owner retains proof, idempotency and recovery status.
Return only to the still-current caller, preserving its draft, selected wallet and unsent input.

### Context selects identity actions, never changes a purpose

| Target | General | Pay | Network |
|---|---|---|---|
| Bare identity | Profile with explicit Follow / Pay / Save | Verified receiving choices, then recipient/payment review | Profile with explicit Follow / Save |
| Identity with `/payment` | Pay | Pay | Pay |
| Payment, request, booking, ticket, pairing | Exact target review/consent | Exact target review/consent | Exact target review/consent |
| Foreign Hedera account | External-recipient preview with Pay | Transfer recipient review | Preview with Pay, without fabricated person identity |
| Unknown or foreign HTTPS link | Unsupported/external-link preview | Same | Same |

The host checks specialized expected-event, booking-owner or partner constraints.
Every follow, contact insertion, grant and payment requires explicit action with existing permissions and eligibility.
Save is a public-contact action; it does not expose private contact fields or bypass mutual-follow rules.
Anonymous web Follow requires native/auth continuation; public Save may offer a previewed public-only `.vcf` export.
Current public web Pay is receiving-address discovery, not browser settlement.

## Public signed-record verification

Accept only the public NIP-01 envelope: `id`, `pubkey`, integer `created_at` in seconds, `kind`, string `tags`, `content` and `sig`.
No key-pair or signing API is exposed.
`isVerifiedNostrRecord` checks envelope shape, requested author, expected kind, a `d` tag exactly matching the requested value, recomputed event ID and Schnorr signature; malformed records fail verification.
Skyzai's kinds 30301/30302 are existing custom profile/payment contracts, not universal Nostr identity or payment standards.

`newestVerifiedRecord` filters verified envelopes for the requested `(pubkey, kind, d)` coordinate, then orders by descending timestamp and ascending event ID for equal timestamps.
This preserves the reviewed `isVerifiedNostrRecord` and `compareNostrRecords` semantics.
Nostr event hashing and signature semantics follow [NIP-01](https://github.com/nostr-protocol/nips/blob/master/01.md).

Select the newest verified envelope before interpreting its content.
A valid empty replacement removes old endpoints; malformed content in the newest verified record is an error, never permission to revive an older address.
Bound event counts and content sizes, and validate domain fields separately from signature verification.
The host owns relay reads, completion/timeouts, stale display policy, account UID/public-key mapping and post-fix snapshot fences.
A relay can omit a newer signed event: a valid signature does not prove global freshness, receiving-address ownership, human identity or settlement.

## Host lifecycle, capture and rendering

The owning service binds recipient, chain, asset, authoritative amount, purpose, expiry and status to a resolved request.
It rechecks authentication, proof and expiry and atomically consumes/settles when appropriate.
Camera cooldowns and signed timestamps are not replay protection; OpenQR keeps no used-code ledger.
`/verify` resolves a ticket under host authorization; expected-event checks and atomic admission belong to the event owner.
Never consume on preview, GET, unfurl or camera decode.

Resolvers use fixed trusted endpoints; a future user-influenced server fetch needs the host's hardened fetch helper and SSRF checks.
Reference pages use no-store/no-referrer and no third-party analytics.
Logs, screenshots and support errors exclude full ticket/pairing URLs.
If consented host analytics already exist, compatibility counts may aggregate kind/version, never scanned values.

The scanner uses one decode callback for camera, paste and chosen images; owns controller start/stop/disposal; suspends in background; blocks concurrent dispatch; and exposes denied/unavailable/retry states.
The host supplies platform permission/settings actions, localized copy and chrome.
Camera permission enables capture only, not business actions.
Rendering supplies a real quiet zone, high contrast, a bounded optional center mark, an accessible text/link alternative and safe local errors.
Sharing, downloading, wallpaper and contact export remain host features.
Widget tests do not establish camera/device or OS app-link support.

## Shared conformance and real-host qualification

Both `dart/openqr` and `ts/` must run the same `fixtures/*.json` corpus.
The corpus covers canonical round trips, malformed/checksum/private-key inputs, foreign Hedera/Nostr codes, hostile origins/userinfo/ports, versions/duplicates, encoded separators, input limits and legacy classification.
Record fixtures cover forgeries, wrong coordinates, shuffled order, equal-time ties, empty newest content and malformed newest content without stale fallback.
Imports must start no networking and require no Firebase, wallet, React, DOM or camera API in the pure packages.

The first real host to qualify is the existing native general scan-to-profile review; skyzai.com's anonymous public profile/Pay host is the second.
Both consume the Dart codec/verifier and invocation contract, with their own permission, account, cancellation and return tests.
Fixtures, an offline example, TypeScript parity or a simulated receipt do not substitute for these host acceptance gates.
Map the seam jointly to CMP-01/04 until exact source-pinned family labels are shared; do not invent individual ownership assignments.
OpenQR is a reusable capability, not an eighth product, transport owner or general business framework.
Preserve Skyzai's ACK handling, account-switch protection, private bank/memo containment and stale-state fixes during later migration.
