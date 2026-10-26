# OpenQR for TypeScript

Typed ESM public-link encoding, classification, invocation guards and supplied Nostr record verification.
The [v1 contract](../SPEC.md) and [shared fixtures](../fixtures/README.md) define the wire behavior.
This local `0.1.0-draft` package is private and unpublished.

```ts
import { OpenQrPolicy, decode, encode } from '@menexus-gmbh/openqr';

const policy = new OpenQrPolicy();
const link = { kind: 'ticket', ticketRef: 'ticket_01' } as const;
const url = encode(link, policy);
const result = decode(url, policy);
```

The package exports ESM JavaScript and declarations through its root export.
It uses standard URL and UTF-8 APIs and `nostr-tools` public identifier/verification modules, without React, Firebase, DOM, camera or relay initialization.
Node requires version 20.19 or newer to match the pinned cryptography dependency.
Web hosts supply their own bundler, renderer and capture UI; Skyzai's Flutter web host should use the Dart package directly.

## Policy and results

`OpenQrPolicy` defaults to the exact `https://skyzai.com` origin, with wallet requests and pairing disabled until the host qualifies their resolvers.
Other canonical/accepted origins, enabled kinds, analytics keys and wallet vocabulary must be configured explicitly.
Policy arrays and wallet configurations are copied and frozen.

For each supported chain, `wallets` supplies `networks`, `walletTypes`, optional stable `assets` and an `isValidAddress(address)` host validator.
An unconfigured chain never defaults to another chain or network.
Foreign Hedera candidates preserve `network: null` and `walletType: null` until host review and cannot be encoded without those fields and a supported wallet policy.

`OpenQrLink` and `OpenQrDecode` are discriminated unions.
Decode results expose `recognized` with a typed link/source, `legacy` with a protocol, or `invalid`/`unsupported` with a safe reason.
Results never include scanned text or opaque legacy payloads.
Encoding refuses invalid or disabled targets with safe errors.

Legacy formats require an explicit `legacyAdapter(raw)` supplied by the host.
It runs after size/encoding checks and applicable origin, version and known-path checks; rejected known links cannot fall through to it.
The adapter validates its domain grammar and returns a safe result or `null` without persisting or logging payloads.
Connect and WalletConnect receive scheme-only opaque classifications; their SDK parsing and consent remain host-owned.
Where even transient key-bearing capture is excluded, capture those legacy protocols outside OpenQR until secret-free pairing ships.

## Host callback

```ts
import { OpenQrInvocation } from '@menexus-gmbh/openqr';
import type { OpenQrHandler } from '@menexus-gmbh/openqr';

const invocation = new OpenQrInvocation({
  context: 'ticketCheck',
  isCurrent: () => accountAndCallerStillCurrent,
  isCancelled: () => reviewCancelled,
});
const handler: OpenQrHandler = async (link, scope) => {
  await resolveThroughExistingHostService(link);
  if (scope.interruption) return scope.interruption;
  showExistingHostReview(link);
  return 'handled';
};
const outcome = await invocation.run(link, handler);
```

The host supplies the illustrated state checks, resolver and review functions.
Guards close over account/session, caller and operation revisions; QR contents cannot replace them.
`run` checks before dispatch and after completion; the host must check `interruption` after each awaited resolution and before effects or caller restoration.
The UI pauses capture, blocks concurrent dispatch and catches callback errors locally.
Outcomes are `handled`, `cancelled`, `obsolete` and `unsupported`; `handled` means accepted for review/navigation, without claiming payment, admission or consent.
Guards cannot undo an operation already dispatched by its owning host service.

## Public records

```ts
import { newestVerifiedRecord } from '@menexus-gmbh/openqr';

const record = newestVerifiedRecord(suppliedPublicEnvelopes, {
  kind: 30302,
  publicKeyHex: expectedAuthor,
  dTag: expectedCoordinate,
});
```

`isVerifiedNostrRecord(event, expected)` accepts unknown input and checks public envelope shape, integer timestamp/kind, author, exact `d` tag, event ID and Schnorr signature.
It copies envelope fields before calling `nostr-tools`, so a caller cannot supply the library's cached verification marker or cause verification to mutate its input.
Only the public envelope is exposed; no signing, private-key or relay API is exported.

`newestVerifiedRecord` returns a frozen public envelope or `null`, choosing descending timestamp and ascending event ID for ties, consistent with [NIP-01](https://github.com/nostr-protocol/nips/blob/master/01.md).
It selects before interpreting content: empty or malformed newest content cannot revive an older endpoint.
Content is limited to 64 KiB of UTF-8 and batches to 100 envelopes; an oversized batch throws rather than silently truncating history.
The host validates domain content and owns fetch completeness, global freshness, authentication, expiry, replay protection and atomic consumption.

## Local validation

Run from this directory:

```sh
npm ci --ignore-scripts
npm test
npm run format:check
npm pack --dry-run --ignore-scripts
```

Tests execute every case from both shared JSON files directly, then check guard races, legacy refusals, record bounds, verification-cache spoofing and imports without host initialization.
The test command also builds JavaScript/declarations and typechecks a consumer through the package exports.
Browser-condition imports are tested in Node without DOM or Node globals; real browser hosts and devices remain separate qualification gates.

No package is published and registry ownership is unchecked.
The intended public npm distribution requires separate release authorization and removal of the local `private` gate.
Consumers with an existing private `@menexus-gmbh` registry mapping will need deliberate public-registry configuration at release.
OpenQR performs no HTTP/relay/Firestore I/O and owns no wallets, signing keys, settlement or permissions.
