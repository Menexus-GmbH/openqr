# OpenQR for Dart

Pure Dart public-link encoding, classification, invocation guards and supplied Nostr record verification.
The [v1 contract](../../SPEC.md) and [shared fixtures](../../fixtures/README.md) define the wire behavior.
This local draft is not published.

```dart
import 'package:openqr/openqr.dart';

final policy = OpenQrPolicy();
final uri = encode(const TicketLink('ticket_01'), policy: policy);
final result = decode(uri.toString(), policy: policy);
```

`OpenQrPolicy` defaults to the exact Skyzai HTTPS origin, with amount requests and pairing disabled.
Hosts explicitly configure other accepted origins, enabled kinds and wallet vocabulary.
`OpenQrWalletPolicy` supplies the host's chain-specific address validator and accepted networks, wallet types and stable asset identifiers.
Foreign Hedera candidates retain unknown network and wallet type until host review.
Legacy formats require a host-supplied `legacyAdapter`; Connect and WalletConnect receive opaque scheme classifications only.
The adapter receives raw text only after size, encoding, origin, version and known-path syntax checks.
Its implementation must validate its domain grammar and return safe typed results without persisting or logging the payload.

## Host callback

```dart
final invocation = OpenQrInvocation(
  context: OpenQrScanContext.ticketCheck,
  isCurrent: () => accountAndCallerStillCurrent,
  isCancelled: () => reviewCancelled,
);
final outcome = await invocation.run(link, hostHandler);
```

The host closes over its account, caller and operation revisions in those guards.
`run` checks before calling the handler and after its future completes.
The handler must also check `invocation.interruption` after each awaited resolution and immediately before any effect or caller restoration.
The UI pauses capture, prevents concurrent dispatch and catches callback errors locally.
Outcomes are `handled`, `cancelled`, `obsolete` and `unsupported`.
`handled` means accepted for review/navigation; it does not assert payment, admission or consent.
Guards cannot undo an operation already dispatched by the host.

## Public records

`isVerifiedNostrRecord` accepts a raw public envelope or `NostrRecord`, plus the expected integer kind, author hex key and exact `dTag`.
It validates the envelope before adapting it to the reviewed pinned `dart_nostr` implementation, then checks the event hash and Schnorr signature.
Only the public envelope is exported; there is no key-pair, signing or relay API.

`newestVerifiedRecord` returns an immutable verified envelope ordered by descending timestamp and ascending event ID for ties, following [NIP-01](https://github.com/nostr-protocol/nips/blob/master/01.md).
It selects before content parsing, so empty or malformed newest content cannot revive old endpoints.
Content is limited to 64 KiB of UTF-8, and batches to 100 supplied envelopes.
Oversized batches throw a safe `StateError` instead of silently returning a record from truncated history.
The host validates domain content and owns fetch completeness, expiry, replay protection and freshness policy.

## Local validation

Run from this directory:

```sh
dart pub get
dart test
dart analyze
dart format --output=none --set-exit-if-changed lib test
```

Tests read both shared JSON corpus files directly and exercise every decode, encoding refusal, signature and selection case.
Additional tests cover invocation cancellation, delayed account/caller invalidation, safe legacy boundaries and record limits.
These checks do not qualify a Skyzai native/web host, camera or device.

The dependency uses Skyzai's reviewed Git pin `f6e097f3b5d1b931b1fc70ae38a2ebe77d44d286` for this local extraction.
Hosted publication eligibility and dependency licenses still need review before any release; `publish_to: none` keeps this draft local.
OpenQR performs no HTTP, relay or Firestore I/O and owns no wallet, keys, settlement or permissions.
