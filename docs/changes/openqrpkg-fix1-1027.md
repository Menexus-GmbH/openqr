# Change report: openqrpkg-fix1-1027

Repo `/Users/darkness/Work/Aureus/openqr`, branch `main`, range `1ff0da2..working tree`.
0 commits, 0 merges, 56 files, +8180 / -0 lines.

Part 1 is written by the authoring agent. Part 2 is generated from git by `agentmail/bin/change-report` and is the ground truth: if they disagree, Part 2 wins and the disagreement is a review finding.

# Part 1: Narrative (authoring agent)

## What and why

The local OpenQR draft provides one public-link contract, shared fixtures, pure Dart and TypeScript codecs and record verification, Flutter capture/rendering, and a Skyzai migration guide.
Business actions remain host-owned, and amount-request and pairing links remain disabled by default.
This report supplies the missing durable handoff identified as finding 2 in the 2026-10-27 review.

Finding 1 identified a Flutter detector-error path that displayed an error while the camera and subsequent dispatch stayed enabled.
`OpenQrScanner` now holds capture synchronously and queues its existing serialized camera shutdown before showing the safe error state.
Round 2 reproduced the remaining P2: a capture already waiting for shutdown could dispatch after a detector error, and a cancelled completion could restart the camera.
Detector errors now also advance the existing invocation generation, and `_process` discards stale results after each await and in its exception paths.
Queued input and captures still awaiting shutdown or image analysis cannot dispatch until the host explicitly calls `retry()`.
An already-dispatched host callback sees an obsolete invocation; its completion cannot overwrite the detector error or release capture.
The host remains responsible for checking that invocation before side effects.
The retained round-1 regressions cover capture after error; the supplied round-2 real-stream regressions cover capture immediately before error.

### Provenance and completion status

- Assignment: `openqr-fix-pkg-1027`, incoming mail `54889e98-7501-4505-a0cb-a7097868fb35`.
- Round-2 assignment: `openqr-fix2-pkg-1027-ramesh`, incoming mail `da327051-bdc4-481c-9718-3434ab131bd5`, explicitly authorizing the single P2 fix, report/README updates and local validation.
- Exact committed provenance range: `1ff0da2b0693aba02660506bbdfb87081c132e65..04bed31d8aa09956fab10edf48fdf49d8100992f` on local `main`.
- That range contains the six draft iteration commits and matches the independently reviewed revision.
- The detector fix, regression and this report are additional working-tree changes on `04bed31d8aa09956fab10edf48fdf49d8100992f`.
- Round-1 Git staging and commit both exited 128 because that session could not create `.git/index.lock` (`Operation not permitted`); round 2 made no Git write attempt.
- Follow-up authority: overseer mail `2587adbf-d5ca-4d9d-ad5e-e41dddddc7f0` explicitly supersedes the commit requirement: leave fixes uncommitted, list changed files and hashes, and let the integrator commit after review.
- No new commit or final fixed SHA exists in this session; the worktree handoff follows that updated brief.
- Finding 2 now has the requested report in the worktree; its inclusion in the final committed tree remains the integrator's acceptance gate.
- Part 2 was generated with `change-report 1ff0da2 --working-tree`, so its files and symbols describe the cumulative current working tree against the empty base, rather than a newly committed range.
- The report file itself is intentionally excluded by the generator; its companion documentation indexes are included.
- A complete patch and checksummed file manifest are preserved with the raw receipts for an authorized committer.

## Flow (step by step)

1. A host supplies the trusted-origin and enabled-kind policy plus current/cancelled invocation guards.
2. Camera, chosen-image and pasted text converge through the Flutter scanner's existing decoder path; pure Dart and TypeScript hosts can call the codec directly.
3. A detector error immediately advances `_generation`, closes `_hold`, queues `_syncCamera()` and displays only `OpenQrScannerStatus.error`.
4. The serialized shutdown stops the controller, including a start already in progress; the shared input guard drops queued captures while held, and generation checks discard earlier work after shutdown, image reads and callback completion.
5. The host calls `retry()` explicitly to reopen input and restart the same controller.
6. Normal input pauses capture before invoking one typed host callback; hosts own resolution, consent, navigation and every domain effect.
7. Public record helpers validate supplied envelopes and select the newest verified replacement before hosts parse domain content.

## How it is implemented

`flutter/openqr_flutter/lib/src/scanner.dart` changes the existing `MobileScanner.onDetectError` callback, `_process` and its file header.
It reuses `_generation`, `_scope`, `_hold`, `_syncCamera()` and `_show()`; it adds no persistent state, dependency, public API or new scanner framework.
Each `_process` captures the generation before waiting; a changed generation causes an early return after camera shutdown, input reading or callback completion, preserving the current status and hold.
Its exception handlers only publish a status for the same generation, so a late `UnsupportedError` cannot replace the detector error with `unavailable`.
The `finally` block still clears `_busy` and synchronizes the camera while the detector's hold remains closed.
Existing startup-error, permission, lifecycle, cancellation and disposal behavior is covered by the full widget suite.
No callers, exports, fixtures or configuration need changing because the public API and link contract are unchanged.

`flutter/openqr_flutter/test/review_detection_error_test.dart` uses the reviewer's supplied fixture with the existing `FakeScannerPlatform` and real plugin controller from `widgets_test.dart`.
Its two timing variants assert safe error state, stopped capture, zero post-error callbacks, and exactly one callback after explicit retry.
Both variants failed against the reviewed production source before the fix.

`flutter/openqr_flutter/test/review_error_during_capture_test.dart` retains both supplied round-2 stream-order cases and verifies zero callbacks, safe error state, stopped camera and recovery only after retry.
Both failed against the inherited round-1 scanner before this correction and passed immediately afterward.
Six additional cases simulate an already-queued detector callback during pending image analysis or host review, covering handled/cancelled results and late `UnsupportedError` without losing the error hold.
`flutter/openqr_flutter/README.md` now states the queued-input and late-completion behavior explicitly.

`docs/changes/openqrpkg-fix1-1027.md` is generated with the standard AgentMail helper and a completed author narrative.
The accompanying `docs/README.md` and `docs/changes/README.md` explain the new documentation folders.
The report acceptance check is an artifact self-check held with the receipts, rather than an unrelated test added to a runtime package.
No configured package acceptance workbook was found; Skyzai's future host ledger remains outside this package assignment.
The project map is an integrator-on-merge responsibility; this task authorizes no merge.

### Original objective coverage

| Deliverable | Current evidence |
|---|---|
| Contract, MIT license and README | `SPEC.md`, root `LICENSE` and `README.md`; nine paths and explicit host policy. |
| Shared corpus | `fixtures/links.json` and `fixtures/records.json`: 89 decode, 11 encode refusal, 29 verification and 9 selection cases, 138 total. |
| Pure Dart | `dart/openqr`: exported codec, policy, typed results, guarded callbacks and supplied-record verification/selection. |
| Flutter | `flutter/openqr_flutter`: accessible renderer and guarded camera/image/paste scanner, now including detector-error pause. |
| TypeScript | `ts`: typed ESM exports, declarations, codec, policy, guards and supplied-record verification/selection. |
| Migration and draft finish | `MIGRATION.md` records native-first/web-second integration, request/Connect ownership and release gates; existing `CHANGELOG.md` records `0.1.0-draft` and was not edited in this fix. |

## How it was verified

Round-2 raw stdout/stderr and the file manifest are retained in [the current local receipt directory](../../../.agent-mail/attachments/morning-review-1027/openqrpkg-fix2/README.md).
The earlier checks below remain preserved in [the round-1 receipt directory](../../../.agent-mail/attachments/morning-review-1027/openqrpkg-fix1/README.md).
These are developer-run local checks, not a new independent review or real-host qualification.
The first table records the historical round-1 validation; the second records this round's complete rerun against the corrected scanner and expanded tests.

| Check | Measured result | Raw receipt |
|---|---|---|
| Original supplied detector fixture, before fix | Exit 1: 0 passed, 1 failed; camera remained running. | [detection-before.log](../../../.agent-mail/attachments/morning-review-1027/openqrpkg-fix1/detection-before.log) |
| Both queued-capture variants, before fix | Exit 1: 0 passed, 2 failed; camera stayed running or error advanced to handled. | [detection-queue-before.log](../../../.agent-mail/attachments/morning-review-1027/openqrpkg-fix1/detection-queue-before.log) |
| Both detector regressions, after fix | Exit 0: 2 passed. | [detection-after.log](../../../.agent-mail/attachments/morning-review-1027/openqrpkg-fix1/detection-after.log) |
| `dart --suppress-analytics test --reporter expanded`, in `dart/openqr` | Exit 0: 152 passed, including all 138 shared cases. | [dart-test.log](../../../.agent-mail/attachments/morning-review-1027/openqrpkg-fix1/dart-test.log) |
| `flutter test --no-pub --reporter expanded`, in `flutter/openqr_flutter` | Exit 0: 18 passed, comprising the original 16 plus 2 detector regressions; original shared-fixture test still covers 207 camera/image/paste dispatches. | [flutter-test.log](../../../.agent-mail/attachments/morning-review-1027/openqrpkg-fix1/flutter-test.log) |
| `npm test`, in `ts` | Exit 0: 155 passed; command also builds JavaScript/declarations and typechecks the exported consumer. | [npm-test.log](../../../.agent-mail/attachments/morning-review-1027/openqrpkg-fix1/npm-test.log) |
| `node --test fixtures/integrity.test.mjs` | Exit 0: 5 passed. | [fixture-integrity.log](../../../.agent-mail/attachments/morning-review-1027/openqrpkg-fix1/fixture-integrity.log) |
| `dart --suppress-analytics analyze --fatal-infos`, both Dart/Flutter packages | Both exit 0, no issues; the introduced packages therefore have zero analyzer findings against the empty base. | [dart-analyze.log](../../../.agent-mail/attachments/morning-review-1027/openqrpkg-fix1/dart-analyze.log), [flutter-analyze.log](../../../.agent-mail/attachments/morning-review-1027/openqrpkg-fix1/flutter-analyze.log) |
| `dart --suppress-analytics format --output=none --set-exit-if-changed lib test`, both packages | Both exit 0: 10 Dart files and 5 Flutter files, zero changes. | [dart-format.log](../../../.agent-mail/attachments/morning-review-1027/openqrpkg-fix1/dart-format.log), [flutter-format.log](../../../.agent-mail/attachments/morning-review-1027/openqrpkg-fix1/flutter-format.log) |
| `npm run format:check` | Exit 0. | [npm-format.log](../../../.agent-mail/attachments/morning-review-1027/openqrpkg-fix1/npm-format.log) |
| `npm pack --dry-run --ignore-scripts --cache <scratch>/npm-cache` | Exit 0: 15 files, no package published or archive created. | [npm-pack-dry-run.log](../../../.agent-mail/attachments/morning-review-1027/openqrpkg-fix1/npm-pack-dry-run.log) |
| Finding 2 acceptance, before report | Exit 1: report absent. | [report-before.log](../../../.agent-mail/attachments/morning-review-1027/openqrpkg-fix1/report-before.log) |

The stock Flutter/Dart launcher initially failed when it attempted to update `/opt/homebrew/share/flutter/bin/cache`, which this session cannot write.
Tests then used a temporary copy-on-write copy of the already installed SDK under `/private/tmp/openqr-fix1-sdk.rltuAA/flutter`, with Flutter analytics suppressed in the environment and Dart's `--suppress-analytics` flag.
No dependency installation, permission escalation, toolchain upgrade or global setting change was needed.
The first direct Dart formatting attempt completed formatting but emitted a telemetry write error; the final formatting checks use the suppression flag and exit cleanly.
Initial analyzer feedback in the new test was corrected; the final fatal-info analyzer receipts show zero issues.
The source and tests remain in the assigned repository; only the SDK cache and npm dry-run cache were relocated.

### Round-2 validation

| Check | Measured result | Raw receipt |
|---|---|---|
| Supplied real-stream capture/error fixture, before round-2 fix | Exit 1: 0 passed, 2 failed; both dispatched after error, and cancelled restarted capture. | [stream-order-before.log](../../../.agent-mail/attachments/morning-review-1027/openqrpkg-fix2/stream-order-before.log) |
| Exact supplied real-stream fixture, immediately after fix | Exit 0: 2 passed. | [stream-order-after.log](../../../.agent-mail/attachments/morning-review-1027/openqrpkg-fix2/stream-order-after.log) |
| `dart --suppress-analytics test --reporter expanded`, in `dart/openqr` | Exit 0: 152 passed, including all 138 shared cases. | [dart-test.log](../../../.agent-mail/attachments/morning-review-1027/openqrpkg-fix2/dart-test.log) |
| `flutter test --no-pub --reporter expanded`, in `flutter/openqr_flutter` | Exit 0: 26 passed, comprising the existing 18 plus 2 real-stream and 6 delayed-completion regressions; the shared-fixture test retains 207 dispatches. | [flutter-test.log](../../../.agent-mail/attachments/morning-review-1027/openqrpkg-fix2/flutter-test.log) |
| `npm test`, in `ts` | Exit 0: 155 passed, including JavaScript/declaration build and exported-consumer typecheck. | [npm-test.log](../../../.agent-mail/attachments/morning-review-1027/openqrpkg-fix2/npm-test.log) |
| `node --test fixtures/integrity.test.mjs` | Exit 0: 5 passed. | [fixture-integrity.log](../../../.agent-mail/attachments/morning-review-1027/openqrpkg-fix2/fixture-integrity.log) |
| Dart and Flutter `dart --suppress-analytics analyze --fatal-infos` | Both exit 0, no issues. | [Dart](../../../.agent-mail/attachments/morning-review-1027/openqrpkg-fix2/dart-analyze.log), [Flutter](../../../.agent-mail/attachments/morning-review-1027/openqrpkg-fix2/flutter-analyze.log) |
| Dart and Flutter format checks | Both exit 0: 10 Dart files and 6 Flutter files, zero changes. | [Dart](../../../.agent-mail/attachments/morning-review-1027/openqrpkg-fix2/dart-format.log), [Flutter](../../../.agent-mail/attachments/morning-review-1027/openqrpkg-fix2/flutter-format.log) |
| `npm run format:check` | Exit 0. | [npm-format.log](../../../.agent-mail/attachments/morning-review-1027/openqrpkg-fix2/npm-format.log) |

The stock Flutter launcher again encountered a denied write to its installed SDK cache.
Round-2 tests used a temporary copy-on-write copy of the same installed SDK at `/private/tmp/openqr-fix2-sdk-wmgseytj/flutter`, with analytics suppressed and existing dependencies unchanged.
An initial copy preserved Homebrew's symlink; it was replaced with a copy of the resolved SDK directory before the reproduced failures and all passing runs.
All tests ran locally in the assigned package directories; no dependency installation, SDK upgrade or permission change was used.
TypeScript package packing was unchanged and was not repeated in this round.
The canonical work-state write tool required approval while this seat has approval policy `never`; it was attempted once and no persistence is claimed.

The report content self-check and standard helper completion check pass once the report is generated.
The separate `--require-tracked` acceptance mode remains expected to fail until the integrator stages this report, as explicitly directed by the updated brief.
This distinction preserves the review's committed-artifact requirement instead of treating an untracked file as completion.

## Deploy / release impact

None for this local correction; no app, service or package release is performed.
The package remains a local draft with Dart/Flutter `publish_to: none` and npm `private: true`.
No pushes, merges, deployments, cloud commands, live relays, transactions, app builds, devices, emulators, terminals, browser sessions or subagents were used.
No background watcher or server was started; Codex checks its inbox between steps.
Native/web host integration, hardware capture, OS links/permissions, request/Connect lifecycles, dependency security/license qualification, registry ownership and publication eligibility remain unverified gates.
The independent reviewer must review this working-tree patch or the eventual committed revision before acceptance.

The integrator reviews and commits the tested fix and report locally on `main`, preserving this report's exact committed provenance and refreshing its Git facts for the resulting fixed range.
This seat leaves all changes uncommitted as explicitly directed and provides a SHA-256 file manifest with DONE.
No final fixed commit is claimed.

# Part 2: Facts (generated from git)

## Sensitive areas touched

- **Dependencies** (3): `dart/openqr/pubspec.yaml`, `flutter/openqr_flutter/pubspec.yaml`, `ts/package.json`
- **Payments / money** (1): `ts/src/index.ts`

## Dependency changes

`dart/openqr/pubspec.yaml`:
```diff
+name: openqr
+description: Public QR link codecs, guarded host callbacks and Nostr record verification.
+version: 0.1.0-draft
+publish_to: none
+environment:
+  sdk: '>=3.8.0 <4.0.0'
+dependencies:
+  dart_nostr:
+    git:
+      url: https://github.com/ramesh-aureus/nostr
+      ref: f6e097f3b5d1b931b1fc70ae38a2ebe77d44d286
+dev_dependencies:
+  lints: ^6.1.0
+  test: ^1.25.0
```
`flutter/openqr_flutter/pubspec.yaml`:
```diff
+name: openqr_flutter
+description: QR rendering and guarded capture widgets for the OpenQR public-link contract.
+version: 0.1.0-draft
+publish_to: none
+environment:
+  sdk: '>=3.8.0 <4.0.0'
+  flutter: '>=3.29.0'
+dependencies:
+  flutter:
+    sdk: flutter
+  openqr:
+    path: ../../dart/openqr
+  mobile_scanner: ^7.0.1
+  pretty_qr_code:
+    git:
+      url: https://github.com/Menexus-GmbH/flutter_pretty_qr.git
+      ref: faa96f0af39b36172ac78aede096a1a54a712dc5
+dev_dependencies:
+  flutter_test:
+    sdk: flutter
+  flutter_lints: ^6.0.0
+dependency_overrides:
+  web_socket_channel: ^3.0.1
```
`ts/package.json`:
```diff
+{
+  "name": "@menexus-gmbh/openqr",
+  "version": "0.1.0-draft",
+  "private": true,
+  "description": "Typed public-link codecs and supplied Nostr record verification without host I/O",
+  "type": "module",
+  "license": "MIT",
+  "author": "Menexus GmbH",
+  "sideEffects": false,
+  "main": "./dist/index.js",
+  "types": "./dist/index.d.ts",
+  "exports": {
+    ".": {
+      "types": "./dist/index.d.ts",
+      "import": "./dist/index.js"
+    }
+  },
+  "files": [
+    "dist",
+    "README.md",
+    "LICENSE"
+  ],
+  "engines": {
+    "node": ">=20.19"
+  },
+  "scripts": {
+    "build": "tsc -p tsconfig.json",
+    "typecheck": "tsc -p test/tsconfig.json",
+    "test": "npm run build && npm run typecheck && node --test test/*.test.mjs",
+    "format": "prettier --write src test package.json tsconfig.json",
+    "format:check": "prettier --check src test package.json tsconfig.json"
+  },
+  "dependencies": {
+    "nostr-tools": "2.25.2"
+  },
+  "devDependencies": {
+    "prettier": "3.6.2",
+    "typescript": "5.9.3"
+  }
+}
```

## Commits


## Source files (31)

### `.gitignore` (added, +6/-0)

### `LICENSE` (added, +21/-0)

### `dart/openqr/LICENSE` (added, +21/-0)

### `dart/openqr/analysis_options.yaml` (added, +1/-0)

### `dart/openqr/lib/openqr.dart` (added, +9/-0)

### `dart/openqr/lib/src/codec.dart` (added, +330/-0)
- Added: `_decodeUri()`, `_identity()`, `_legacy()`, `_linkError()`, `_queryError()`, `_recognized()`, `decode()`, `encode()`
- Changed: `_bech32`, `_controls`, `_hedera`, `_malformed`, `_reference`, `_unknown`

### `dart/openqr/lib/src/handler.dart` (added, +48/-0)
- Added: `Function()`, `class OpenQrInvocation`, `enum OpenQrHandling`, `enum OpenQrScanContext`, `run()`

### `dart/openqr/lib/src/policy.dart` (added, +76/-0)
- Added: `_origin()`, `class OpenQrPolicy`, `class OpenQrWalletPolicy`

### `dart/openqr/lib/src/records.dart` (added, +160/-0)
- Added: `class NostrRecord`, `compareNostrRecords()`, `isVerifiedNostrRecord()`, `newestVerifiedRecord()`, `toJson()`, `tryParse()`
- Changed: `_hex32`, `_hex64`, `maxRecordContentBytes`, `maxRecordCount`

### `dart/openqr/lib/src/types.dart` (added, +186/-0)
- Added: `class BookingLink`, `class BookingSessionLink`, `class IdentityLink`, `class Invalid`, `class Legacy`, `class OpenQrDecode`, `class OpenQrLink`, `class PairingLink`, `class PaymentLink`, `class Recognized`, `class TicketLink`, `class Unsupported`, `class WalletAddressLink`, `class WalletRequestLink`, `enum LegacyProtocol`, `enum OpenQrIntent`, `enum OpenQrKind`, `enum OpenQrReason`, `enum OpenQrSource`, `toJson()`

### `dart/openqr/pubspec.lock` (added, +486/-0)

### `dart/openqr/pubspec.yaml` (added, +14/-0)

### `fixtures/links.json` (added, +1301/-0)

### `fixtures/records.json` (added, +758/-0)

### `flutter/openqr_flutter/LICENSE` (added, +21/-0)

### `flutter/openqr_flutter/analysis_options.yaml` (added, +1/-0)

### `flutter/openqr_flutter/lib/openqr_flutter.dart` (added, +7/-0)

### `flutter/openqr_flutter/lib/src/scanner.dart` (added, +289/-0)
- Added: `Function()`, `_cameraError()`, `_capture()`, `_firstCode()`, `_process()`, `_scope()`, `_show()`, `_syncCamera()`, `analyzeImage()`, `build()`, `cancel()`, `class OpenQrScanner`, `class OpenQrScannerState`, `createState()`, `didChangeAppLifecycleState()`, `didUpdateWidget()`, `dispose()`, `enum OpenQrScannerStatus`, `initState()`, `retry()`, `submitText()`

### `flutter/openqr_flutter/lib/src/view.dart` (added, +62/-0)
- Added: `build()`, `class OpenQrView`

### `flutter/openqr_flutter/pubspec.lock` (added, +691/-0)

### `flutter/openqr_flutter/pubspec.yaml` (added, +24/-0)

### `ts/LICENSE` (added, +21/-0)

### `ts/package-lock.json` (added, +157/-0)

### `ts/package.json` (added, +40/-0)

### `ts/src/codec.ts` (added, +313/-0)
- Added: `decode()`, `decodeUri()`, `encode()`, `identity()`, `legacy()`, `linkError()`, `queryError()`, `recognized()`, `segments()`
- Changed: `controls`, `hedera`, `malformed`, `reference`, `unknown`, `utf8`

### `ts/src/handler.ts` (added, +53/-0)
- Added: `class OpenQrInvocation`, `interface OpenQrInvocationOptions`, `type OpenQrHandler`, `type OpenQrHandling`, `type OpenQrScanContext`

### `ts/src/index.ts` (added, +6/-0)

### `ts/src/policy.ts` (added, +82/-0)
- Added: `class OpenQrPolicy`, `interface OpenQrPolicyOptions`, `interface OpenQrWalletPolicy`, `origin()`, `type OpenQrLegacyAdapter`

### `ts/src/records.ts` (added, +118/-0)
- Added: `compareNostrRecords()`, `interface NostrRecord`, `interface OpenQrExpectedRecord`, `isVerifiedNostrRecord()`, `newestVerifiedRecord()`, `parseRecord()`, `verifiedRecord()`
- Changed: `hex32`, `hex64`, `maxRecordContentBytes`, `maxRecordCount`

### `ts/src/types.ts` (added, +52/-0)
- Added: `type LegacyProtocol`, `type OpenQrDecode`, `type OpenQrKind`, `type OpenQrLink`, `type OpenQrReason`, `type OpenQrSource`

### `ts/tsconfig.json` (added, +14/-0)

## Test files (15)

### `dart/openqr/test/boundaries_test.dart` (added, +82/-0)
- Added: `main()`
- Changed: `test 'configuration requires exact HTTPS origins'`, `test 'invalid syntax, origin and version cannot fall through to legacy'`, `test 'malformed UTF-16 is rejected without echoing input'`, `test 'record limits reject content and whole batches'`
- Test cases added/edited (4): configuration requires exact HTTPS origins; invalid syntax, origin and version cannot fall through to legacy; malformed UTF-16 is rejected without echoing input; record limits reject content and whole batches

### `dart/openqr/test/corpus_test.dart` (added, +83/-0)
- Added: `main()`
- Changed: `test 'shared decoder corpus'`, `test 'shared encoder refusal corpus'`, `test 'shared replacement corpus'`, `test 'shared verification corpus'`
- Test cases added/edited (4): shared decoder corpus; shared encoder refusal corpus; shared verification corpus; shared replacement corpus

### `dart/openqr/test/fixture_host.dart` (added, +109/-0)
- Added: `fixture()`, `linkFromJson()`, `policyFromJson()`

### `dart/openqr/test/handler_test.dart` (added, +105/-0)
- Added: `main()`
- Changed: `test 'errors reach the host UI boundary'`, `test 'preserves ${outcome.name} and the exact ticket/context'`, `test 'rechecks even when callback returns a stale handled outcome'`
- Test cases added/edited (3): preserves ${outcome.name} and the exact ticket/context; rechecks even when callback returns a stale handled outcome; errors reach the host UI boundary

### `fixtures/integrity.test.mjs` (added, +166/-0)
- Added: `eventHash()`, `read()`, `uniqueIds()`
- Changed: `linkFields`, `links`, `reasons`, `records`, `test 'fixture versions, case IDs and policy references are valid'`, `test 'input limits use actual UTF-8 bytes before trimming'`, `test 'positive record expectations have complete public envelopes and exact hashes'`, `test 'public decode expectations contain only safe, typed result fields'`, `test 'selection expectations agree with verification cases and deterministic ordering'`
- Test cases added/edited (5): fixture versions, case IDs and policy references are valid; public decode expectations contain only safe, typed result fields; input limits use actual UTF-8 bytes before trimming; positive record expectations have complete public envelopes and exact hashes; selection expectations agree with verification cases and deterministic ordering

### `flutter/openqr_flutter/test/review_detection_error_test.dart` (added, +96/-0)
- Added: `main()`

### `flutter/openqr_flutter/test/review_error_during_capture_test.dart` (added, +171/-0)
- Added: `main()`

### `flutter/openqr_flutter/test/widgets_test.dart` (added, +591/-0)
- Added: `analyzeImage()`, `buildCameraView()`, `callback()`, `capture()`, `class FakeScannerPlatform`, `close()`, `dispose()`, `emit()`, `main()`, `scanner()`, `start()`, `stop()`
- Changed: `test 'account switch discards a delayed completion'`, `test 'missing code and unavailable gallery produce finite states'`, `test 'new caller scope invalidates the old in-flight review'`, `ticket`
- Test cases added/edited (3): account switch discards a delayed completion; new caller scope invalidates the old in-flight review; missing code and unavailable gallery produce finite states

### `ts/test/boundaries.test.mjs` (added, +118/-0)
- Changed: `expected`, `original`, `test 'JavaScript callers cannot encode missing or coerced reference fields'`, `test 'caller-supplied nostr-tools verification cache cannot bypass signatures'`, `test 'configuration accepts exact HTTPS origins and snapshots host vocabulary'`, `test 'malformed UTF-16 and empty fragment markers are safely refused'`, `test 'record bounds fail safely and selection returns immutable public fields'`, `test 'rejected known links cannot fall through to a permissive legacy parser'`
- Test cases added/edited (6): configuration accepts exact HTTPS origins and snapshots host vocabulary; rejected known links cannot fall through to a permissive legacy parser; malformed UTF-16 and empty fragment markers are safely refused; JavaScript callers cannot encode missing or coerced reference fields; record bounds fail safely and selection returns immutable public fields; caller-supplied nostr-tools verification cache cannot bypass signatures

### `ts/test/corpus.test.mjs` (added, +58/-0)
- Changed: `links`, `policies`, `records`, `test 'shared decode: ${c.id}'`, `test 'shared encode refusal: ${c.id}'`, `test 'shared selection: ${c.id}'`, `test 'shared verification: ${c.id}'`
- Test cases added/edited (4): shared decode: ${c.id}; shared encode refusal: ${c.id}; shared verification: ${c.id}; shared selection: ${c.id}

### `ts/test/fixture-host.mjs` (added, +79/-0)
- Added: `fixture()`, `policyFromJson()`

### `ts/test/handler.test.mjs` (added, +94/-0)
- Changed: `link`, `test 'blocks ${outcome} before invoking the host'`, `test 'callback errors reach the host UI boundary'`, `test 'discards delayed ${outcome} completion and host effects'`, `test 'preserves ${outcome}, the exact ticket and pay context'`, `test 'rechecks guards even when the callback returns stale handled'`
- Test cases added/edited (5): preserves ${outcome}, the exact ticket and pay context; blocks ${outcome} before invoking the host; discards delayed ${outcome} completion and host effects; rechecks guards even when the callback returns stale handled; callback errors reach the host UI boundary

### `ts/test/import.test.mjs` (added, +43/-0)
- Changed: `test 'browser-condition and Node imports need no host initialization'`
- Test cases added/edited (1): browser-condition and Node imports need no host initialization

### `ts/test/tsconfig.json` (added, +5/-0)

### `ts/test/types.ts` (added, +52/-0)
- Added: `handler()`
- Changed: `expected`, `invalid`, `invocation`, `newest`, `outcome`, `policy`, `record`, `result`, `ticket`, `url`

## Docs and context files (10)

### `CHANGELOG.md` (added, +33/-0)

### `MIGRATION.md` (added, +255/-0)

### `README.md` (added, +70/-0)

### `SPEC.md` (added, +233/-0)

### `dart/openqr/README.md` (added, +71/-0)
- Changed: `invocation`, `outcome`, `policy`, `result`, `uri`

### `docs/README.md` (added, +4/-0)

### `docs/changes/README.md` (added, +5/-0)

### `fixtures/README.md` (added, +69/-0)

### `flutter/openqr_flutter/README.md` (added, +112/-0)

### `ts/README.md` (added, +108/-0)
- Added: `handler()`
- Changed: `invocation`, `link`, `outcome`, `policy`, `record`, `result`, `url`
