/// Detector-error regression from the review, using widgets_test's fake platform
/// and the real MobileScanner controller; no hardware or host effects run.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:openqr_flutter/openqr_flutter.dart';

import 'widgets_test.dart' as fixture;

void main() {
  for (final queuedImmediately in [false, true]) {
    testWidgets(
      'detection errors pause capture until explicit retry (queued immediately: $queuedImmediately)',
      (tester) async {
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
        var callbacks = 0;
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
                return OpenQrHandling.handled;
              },
              builder: (_, preview, state) =>
                  Stack(children: [preview, Text(state.status.name)]),
            ),
          ),
        );
        await tester.pump();
        expect(platform.running, isTrue);

        final camera = tester.widget<MobileScanner>(find.byType(MobileScanner));
        camera.onDetectError(
          StateError('synthetic detection failure'),
          StackTrace.empty,
        );
        if (queuedImmediately) {
          camera.onDetect!(fixture.capture(fixture.ticket));
        }
        await tester.pump();
        expect(key.currentState!.status, OpenQrScannerStatus.error);
        expect(
          find.textContaining('synthetic detection failure'),
          findsNothing,
        );
        expect(
          platform.running,
          isFalse,
          reason: 'Error must stop camera capture',
        );

        // Exercise the gate even if one already-queued capture arrives after stop.
        if (!queuedImmediately) {
          camera.onDetect!(fixture.capture(fixture.ticket));
        }
        await tester.pump();
        expect(
          callbacks,
          0,
          reason: 'An error requires explicit retry before dispatch',
        );
        expect(
          platform.running,
          isFalse,
          reason: 'Error must stop camera capture',
        );

        await key.currentState!.retry();
        expect(platform.running, isTrue);
        platform.emit(fixture.ticket);
        await tester.pump();
        expect(callbacks, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
