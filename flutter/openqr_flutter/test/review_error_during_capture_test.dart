/// Review round 2: a native barcode followed by a detector error must not
/// dispatch after entering error or restart capture without explicit retry.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:openqr_flutter/openqr_flutter.dart';

import 'widgets_test.dart' as fixture;

void main() {
  for (final outcome in [OpenQrHandling.handled, OpenQrHandling.cancelled]) {
    testWidgets('detector error fences pending capture ($outcome)', (
      tester,
    ) async {
      final previous = MobileScannerPlatform.instance;
      final platform = fixture.FakeScannerPlatform();
      MobileScannerPlatform.instance = platform;
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        await platform.captures.close();
        MobileScannerPlatform.instance = previous;
      });
      var callbacks = 0;
      final dispatchStatuses = <OpenQrScannerStatus>[];
      final key = GlobalKey<OpenQrScannerState>();
      await tester.pumpWidget(
        MaterialApp(
          home: OpenQrScanner(
            key: key,
            policy: OpenQrPolicy(),
            invocation: OpenQrInvocation(
              context: OpenQrScanContext.general,
              isCurrent: () => true,
              isCancelled: () => false,
            ),
            onDecoded: (_, _) async {
              callbacks++;
              dispatchStatuses.add(key.currentState!.status);
              return outcome;
            },
            builder: (_, preview, scanner) =>
                Stack(children: [preview, Text(scanner.status.name)]),
          ),
        ),
      );
      await tester.pump();
      expect(platform.running, isTrue);

      // Use the plugin's actual stream forwarding, without invoking callbacks.
      platform.emit(fixture.ticket);
      platform.captures.addError(StateError('synthetic detector failure'));
      await tester.pump();

      expect(
        callbacks,
        0,
        reason:
            'Detector error must invalidate undispatched capture; '
            'callback states=$dispatchStatuses, final=${key.currentState!.status}, '
            'running=${platform.running}',
      );
      expect(key.currentState!.status, OpenQrScannerStatus.error);
      expect(platform.running, isFalse);
      expect(find.textContaining('synthetic detector failure'), findsNothing);
      expect(tester.takeException(), isNull);

      platform.emit(fixture.ticket);
      await tester.pump();
      expect(callbacks, 0);
      expect(key.currentState!.status, OpenQrScannerStatus.error);
      expect(platform.running, isFalse);

      await key.currentState!.retry();
      expect(platform.running, isTrue);
      platform.emit(fixture.ticket);
      await tester.pump();
      expect(callbacks, 1);
      expect(tester.takeException(), isNull);
    });
  }

  for (final image in [true, false]) {
    for (final outcome in [
      OpenQrHandling.handled,
      OpenQrHandling.cancelled,
      UnsupportedError('synthetic late failure'),
    ]) {
      testWidgets('detector error fences late result (image: $image, $outcome)', (
        tester,
      ) async {
        final previous = MobileScannerPlatform.instance;
        final platform = fixture.FakeScannerPlatform();
        MobileScannerPlatform.instance = platform;
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
          await platform.captures.close();
          MobileScannerPlatform.instance = previous;
        });

        final key = GlobalKey<OpenQrScannerState>();
        final review = Completer<OpenQrHandling>();
        platform.pendingImage = Completer<BarcodeCapture?>();
        var callbacks = 0;
        OpenQrInvocation? dispatched;
        await tester.pumpWidget(
          MaterialApp(
            home: OpenQrScanner(
              key: key,
              policy: OpenQrPolicy(),
              invocation: OpenQrInvocation(
                context: OpenQrScanContext.general,
                isCurrent: () => true,
                isCancelled: () => false,
              ),
              onDecoded: (_, invocation) {
                callbacks++;
                dispatched = invocation;
                return review.future;
              },
              builder: (_, preview, scanner) =>
                  Stack(children: [preview, Text(scanner.status.name)]),
            ),
          ),
        );
        await tester.pump();
        final processing = image
            ? key.currentState!.analyzeImage('chosen-image')
            : key.currentState!.submitText(fixture.ticket);
        await tester.pump();
        expect(callbacks, image ? 0 : 1);

        // A detector callback queued before shutdown can arrive during either wait.
        final camera = tester.widget<MobileScanner>(find.byType(MobileScanner));
        camera.onDetectError(
          StateError('synthetic detector failure'),
          StackTrace.empty,
        );
        if (dispatched != null) {
          expect(dispatched!.interruption, OpenQrHandling.obsolete);
        }
        if (image) {
          if (outcome is OpenQrHandling) {
            platform.pendingImage!.complete(fixture.capture(fixture.ticket));
          } else {
            platform.pendingImage!.completeError(outcome);
          }
        } else if (outcome is OpenQrHandling) {
          review.complete(outcome);
        } else {
          review.completeError(outcome);
        }
        await processing;
        await tester.pump();
        expect(callbacks, image ? 0 : 1);
        expect(key.currentState!.status, OpenQrScannerStatus.error);
        expect(platform.running, isFalse);
        expect(find.textContaining('synthetic'), findsNothing);
        expect(tester.takeException(), isNull);

        await key.currentState!.retry();
        expect(platform.running, isTrue);
      });
    }
  }
}
