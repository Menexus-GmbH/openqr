# openqr_flutter

Flutter capture and rendering for the [OpenQR v1 contract](../../SPEC.md), backed by the [pure Dart package](../../dart/openqr/README.md).
The package re-exports the core API and adds `OpenQrView` and `OpenQrScanner`.
It owns no navigation, authentication, wallets, signing, money movement, contact writes or consent.

## Local installation

```yaml
dependencies:
  openqr_flutter:
    path: /path/to/openqr/flutter/openqr_flutter
dependency_overrides:
  web_socket_channel: ^3.0.1
```

This local draft retains Skyzai's reviewed Pretty QR Git pin, `faa96f0af39b36172ac78aede096a1a54a712dc5`, and `mobile_scanner` 7.x.
The existing Nostr fork requires a 2.x WebSocket dependency while Pretty QR's transitive web dependencies require 3.x; the override above matches Skyzai's existing resolution.
Overrides in dependencies are ignored by Pub, so the consuming app must supply it at its root as well.
The package remains `publish_to: none`; hosted dependency eligibility and licenses require release qualification.

## Rendering

```dart
OpenQrView(
  link: const TicketLink('example_ticket'),
  policy: OpenQrPolicy(),
  size: 256,
  semanticLabel: 'Ticket QR code',
  errorBuilder: (_) => const Text('QR code unavailable'),
)
```

The view validates through `encode`, uses high error correction, black modules on white and a four-module quiet zone, and includes selectable canonical link text.
Encoder refusals and QR-capacity failures render the local error builder without exposing the payload or exception to diagnostics.
Hosts supply localized labels and enough layout space or scrolling for the code and text at large text scales.
Sharing, image export and branding stay with the host; this draft has no center-image customization.

## Scanning

```dart
OpenQrScanner(
  policy: policy,
  invocation: OpenQrInvocation(
    context: OpenQrScanContext.pay,
    isCurrent: isCurrentAccountAndCaller,
    isCancelled: isReviewCancelled,
  ),
  onDecoded: (result, invocation) async {
    // The host shows a review and rechecks these guards after each await.
    return hostReview(result, invocation);
  },
  builder: (context, preview, scanner) {
    return Stack(children: [
      preview,
      hostScannerControls(
        status: scanner.status,
        onRetry: scanner.retry,
        onCancel: scanner.cancel,
        onPaste: scanner.submitText,
        onChosenImage: scanner.analyzeImage,
      ),
    ]);
  },
)
```

The example's policy, guard functions, review and controls are supplied by the application.
Keep the supplied preview mounted in the builder, including in error and paused states.
Use a bounded camera area; the builder owns chrome, localization, accessibility labels, manual paste, image picking and platform permission/settings actions.
`analyzeImage(path)` accepts a chosen local image path without installing a second picker or decoding engine.
Image analysis availability depends on the scanner platform; an unavailable platform can still offer paste.
The initial scanner integration is not a web-camera qualification; Flutter web hosts can use the core package directly for incoming links.

Camera, paste and image analysis share one decoder and callback, including invalid and unsupported results.
Capture stops before the host callback, and a second input cannot overlap pending image analysis or review.
After `handled`, `unsupported`, errors or obsolete work, capture stays stopped until explicit `retry()`.
A detector error invalidates the current invocation, including input awaiting camera shutdown or image analysis.
Queued captures and late callback results cannot replace that error or restart capture; recovery requires explicit `retry()`.
A callback returning `cancelled` resumes capture if its invocation is still current and uncancelled; `cancel()` stops the scanner until retry or disposal.
`handled` means accepted for review/navigation, never payment, admission or approval.

`starting`, `scanning`, `paused` and `processing` describe capture progress.
`permissionDenied`, `unavailable`, `noCode` and `error` are safe local states for host-supplied messages and retry/paste alternatives.
Callback and platform exceptions never supply their messages or raw payloads to the widget tree or global logs.
Backgrounding stops capture and invalidates pending results; an idle scanner resumes on foreground, while an in-flight review requires explicit retry.
Changing the policy or invocation object invalidates the old scope and pauses capture until retry.
Keep those objects stable during ordinary host rebuilds and replace the invocation when the account/caller revision changes.
Disposal invalidates guards and serializes camera shutdown even if startup is still pending.
The package's guard wrapper also reports obsolete/cancelled completion, but the host must check the supplied invocation inside its callback before every side effect.

An optional `onLegacy(protocol, raw, invocation)` performs the explicit opaque in-memory handoff to the existing host adapter.
Without it, the callback receives only the safe `Legacy` result, never raw text.
OpenQR does not parse, log or persist legacy Connect/WalletConnect keys.
Hosts requiring zero transient key bytes inside this package must keep legacy capture outside OpenQR until the secret-free exchange exists.

## Validation

```sh
flutter pub get --offline
flutter test --no-pub
flutter analyze --no-pub
dart format --output=none --set-exit-if-changed lib test
```

Widget tests use the real plugin controller with a fake platform and shared link fixtures through camera callback, image analysis and pasted input.
They cover rendering/semantics at large text scale, safe errors, duplicate dispatch, account/caller guards, cancellation, lifecycle and disposal.
Detector regressions cover both capture/error event orders, including capture before error through the real plugin stream, plus late image and callback results with explicit retry recovery.
No camera, gallery picker, permission dialog or device is opened by these tests.
Real Skyzai native and public web host qualification, camera hardware, platform permissions and OS link handling remain separate integration gates.

Licensed under [MIT](LICENSE), copyright Menexus GmbH.
