# Changelog

## 0.1.0-draft - 2026-10-26

Local, unpublished draft of link-spec v1, licensed under MIT, copyright Menexus GmbH.
No remote repository has been created and no Skyzai host has been migrated by this work.

### Added

- A shared contract for all nine identity, Pay, request, booking, ticket, pairing and explicit-wallet paths, with exact-origin policy, versioning, compatibility rules and data excluded from newly encoded QRs.
- A shared JSON corpus with 89 decode cases, 11 encoding refusals, 29 signed-record verification cases and nine newest-record selection cases, consumed directly by Dart and TypeScript.
- Pure Dart `openqr`: typed encoder/classifier, explicit wallet and legacy policies, guarded host invocation/outcomes, public signed-record verification and deterministic replacement selection.
- Flutter `openqr_flutter`: high-contrast QR rendering with a four-module quiet zone and accessible text, plus unified guarded camera/gallery/paste capture using Skyzai's existing scanner and Pretty QR dependencies.
- Typed ESM `@menexus-gmbh/openqr`: equivalent codec/verifier/handler behavior, declaration exports and imports without host, DOM, Firebase or network initialization.
- A [Skyzai migration guide](MIGRATION.md) covering native-first/web-second CMP-01/04 qualification, caller adapters, personal QR convergence, purpose producers and owner-gated request/Connect lifecycles.

### Validated locally

- Dart: 152 passing tests, including every shared corpus case.
- TypeScript: 155 passing tests, including every shared corpus case, JavaScript/declaration build, exported consumer typechecking and Node/browser-condition import checks.
- Flutter: 16 passing widget tests, including 69 shared link cases through camera callback, gallery analysis and paste for 207 dispatches.
- Shared fixture integrity: five passing checks.
- Dart core and Flutter static analysis with fatal infos, Dart formatting, TypeScript formatting and documentation/source-reference checks.

### Draft limits

All packages remain gated against publication with `publish_to: none` or npm `private`.
Git-pinned Dart/Flutter dependency licenses and hosted-package eligibility, registry ownership and real browser/runtime release acceptance remain unchecked.
Native/web host acceptance, devices, camera permissions, OS links, live relays and real payment/admission remain unqualified; iOS Universal Links remain owner-deferred.
Wallet requests and secret-free pairing stay disabled by default until their owners qualify authoritative resolvers and lifecycles.
Legacy key-bearing Connect/WalletConnect capture stays host-owned under a strict zero-key package boundary.
The packages perform no HTTP, relay or Firestore I/O and own no wallets, keys, settlement, contact writes or access grants.
Verified signatures do not establish human identity, address ownership, global freshness or settlement, and invocation guards cannot undo an already-dispatched host operation.
