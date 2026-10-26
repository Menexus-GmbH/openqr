# OpenQR

OpenQR is a public-link codec and QR capture/rendering boundary for Skyzai and other explicitly configured hosts.
One personal QR, `https://skyzai.com/<npub>`, identifies a public profile; payment requests, bookings, tickets and pairing remain distinct task references.
The host decides which review to offer and obtains explicit permission for every action.

The normative draft contract is [SPEC.md](SPEC.md).
The code and documentation are licensed under [MIT](LICENSE), copyright Menexus GmbH.

## Current status

This repository is local-only and contains the contract, shared [conformance corpus](fixtures/README.md), working [pure Dart package](dart/openqr/README.md) and [Flutter widgets](flutter/openqr_flutter/README.md).
The Dart package tests consume both shared JSON files directly, covering links, encoding refusals, signed envelopes and record selection.
Flutter widgets have offline widget tests; TypeScript remains to be implemented.
No packages are published and no remote repository has been created; package names and publication eligibility still require release checks.
Link-spec v1 is independent of the planned initial package version `0.1.0`.

## Packages

| Location | Package | Responsibility |
|---|---|---|
| `dart/openqr` | `openqr` | Pure Dart encoder, decoder/classifier, guarded handler contract and public signed-record verifier. |
| `flutter/openqr_flutter` | `openqr_flutter` | QR rendering and scanner widgets using existing `pretty_qr_code` and `mobile_scanner` capabilities. |
| `ts/` | `@menexus-gmbh/openqr` | Typed ESM codec, classifier, handler contract and verifier, with declaration exports. |
| `fixtures/*.json` | Shared corpus | Identical wire examples and verification cases ready for Dart and TypeScript tests. |

The implementation order is the shared corpus, Dart core, Flutter widgets, TypeScript parity, then the Skyzai migration guide and `0.1.0-draft` changelog.
The corpus integrity check is `node --test fixtures/integrity.test.mjs`.
Run `dart pub get`, `dart test` and `dart analyze` from `dart/openqr` to validate the Dart implementation.
Run `flutter pub get`, `flutter test` and `flutter analyze` from `flutter/openqr_flutter` to validate the widgets.
The Flutter README documents the existing Skyzai dependency override required by consuming hosts.
TypeScript conformance remains pending.
Core and widget packages are separate so a Dart or Flutter-web consumer can use the codec without camera APIs.
TypeScript imports must work without React, Firebase, DOM or network initialization.

## Host integration contract

1. Configure the canonical origin, exact trusted origins, enabled kinds and supported wallet vocabulary.
   Amount-request and secret-free pairing emission remain disabled until the host implements their resolvers and lifecycles.
2. Decode camera, gallery, paste or incoming-link input through the same classifier.
   Invalid/unsupported results contain safe reasons, and legacy protocols require explicit host adapters.
3. Pause capture and invoke one host callback with the typed target, scan context and current/cancelled guards.
   Recheck those guards after awaits and before effects or returning to the caller.
4. Resolve authoritative records and show the appropriate review using existing host services.
   A ticket stays a ticket even from Pay; bare identity can suggest a context-specific action.
5. Return `handled`, `cancelled`, `obsolete` or `unsupported` while preserving the invoking screen's unsent state.
   `handled` means accepted for review/navigation, not paid, admitted or approved.

The package performs no HTTP, relay or Firestore I/O and never opens wallets, obtains signing keys, transfers money, writes contacts or grants access.
Bank details, private contacts, secrets, credentials, signed transactions and personal memos never belong in newly encoded QRs.
Checksum-valid identifiers and verified record signatures do not prove a trusted human, global record freshness or payment settlement.
Hosts own permission, authentication, domain validation, expiry, replay protection and atomic consumption.

Existing key-bearing Connect/WalletConnect formats stay opaque host protocols; their parsing and key handling stay in existing host adapters.
Under a strict zero-key boundary, their capture also stays outside OpenQR until a secret-free exchange is available.
Old printed profile/ticket links keep decoding, while amount-bearing wallet URLs remain repeatable hints rather than single-use invoices.

## Qualification and release boundary

The shared fixture corpus checks hostile inputs and signed-record replacement rules; cross-language parity remains pending the TypeScript implementation.
Flutter validation is initially widget-only; it does not claim device-camera or OS app-link qualification.
The first real integration gate is Skyzai's native scan-to-profile review, followed by skyzai.com's public profile/Pay host using the same Dart boundary.
Package tests and examples do not count as those host acceptance tests.
The organisation mapping remains joint CMP-01/04 until the exact source-pinned definitions are available.

Skyzai migration must preserve existing ACK behavior, account/caller revision fences, bank/memo containment and stale-state protections.
The current Skyzai app uses Git-pinned Nostr and Pretty QR forks; dependency licenses and hosted-publication constraints must be checked before a release.
The intended distribution is pub.dev and public npm, subject to separate authorization and ownership checks.
Consumers with a private `@menexus-gmbh` registry mapping will need explicit public-registry configuration.
