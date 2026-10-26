/// Offline widget qualification with the real scanner controller and a fake
/// platform; camera hardware, permission dialogs and gallery picking are absent.
// Tests inspect the wrapped renderer's protected configuration to verify contrast.
// ignore_for_file: invalid_use_of_protected_member
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:openqr_flutter/openqr_flutter.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';

const ticket = 'https://skyzai.com/verify/ticket_123?v=1';

class FakeScannerPlatform extends MobileScannerPlatform {
  final captures = StreamController<BarcodeCapture?>.broadcast();
  MobileScannerException? startError;
  Completer<MobileScannerViewAttributes>? pendingStart;
  Completer<BarcodeCapture?>? pendingImage;
  BarcodeCapture? image;
  int starts = 0;
  int stops = 0;
  int disposals = 0;
  bool running = false;
  List<BarcodeFormat>? cameraFormats;
  List<BarcodeFormat>? imageFormats;

  static const attributes = MobileScannerViewAttributes(
    cameraDirection: CameraFacing.back,
    currentTorchMode: TorchState.off,
    size: Size(640, 480),
  );

  @override
  Stream<BarcodeCapture?> get barcodesStream => captures.stream;
  @override
  Stream<TorchState> get torchStateStream => const Stream.empty();
  @override
  Stream<double> get zoomScaleStateStream => const Stream.empty();
  @override
  Widget buildCameraView() => const ColoredBox(color: Colors.black);
  @override
  Future<MobileScannerViewAttributes> start(StartOptions options) async {
    cameraFormats = options.formats;
    starts++;
    if (startError != null) throw startError!;
    final result = await (pendingStart?.future ?? Future.value(attributes));
    running = true;
    return result;
  }

  @override
  Future<void> stop() async {
    stops++;
    running = false;
  }

  @override
  Future<void> dispose() async => disposals++;
  @override
  Future<BarcodeCapture?> analyzeImage(
    String path, {
    List<BarcodeFormat> formats = const [],
  }) async {
    imageFormats = formats;
    if (path == 'unsupported') throw UnsupportedError('no image analysis');
    return pendingImage?.future ?? image;
  }

  void emit(String raw) => captures.add(capture(raw));
}

BarcodeCapture capture(String raw) => BarcodeCapture(
  barcodes: [
    const Barcode(),
    Barcode(rawValue: raw, format: BarcodeFormat.qrCode),
  ],
);

void main() {
  final policy = OpenQrPolicy();
  late FakeScannerPlatform platform;
  late MobileScannerPlatform previousPlatform;
  late GlobalKey<OpenQrScannerState> key;
  var current = true;
  var cancelled = false;
  late OpenQrInvocation invocation;

  setUp(() {
    previousPlatform = MobileScannerPlatform.instance;
    platform = FakeScannerPlatform();
    MobileScannerPlatform.instance = platform;
    key = GlobalKey<OpenQrScannerState>();
    current = true;
    cancelled = false;
    invocation = OpenQrInvocation(
      context: OpenQrScanContext.pay,
      isCurrent: () => current,
      isCancelled: () => cancelled,
    );
  });

  tearDown(() async {
    await platform.captures.close();
    MobileScannerPlatform.instance = previousPlatform;
  });

  Widget scanner({
    required OpenQrDecodedCallback onDecoded,
    OpenQrLegacyCallback? onLegacy,
    OpenQrInvocation? scope,
  }) => MaterialApp(
    home: OpenQrScanner(
      key: key,
      policy: policy,
      invocation: scope ?? invocation,
      onDecoded: onDecoded,
      onLegacy: onLegacy,
      builder: (context, preview, scanner) =>
          Stack(children: [preview, Text(scanner.status.name)]),
    ),
  );

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(platform.running, isFalse);
    expect(platform.disposals, 1);
    expect(tester.takeException(), isNull);
  }

  testWidgets(
    'renders a high-contrast QR, four-module margin and text at large scale',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2)),
              child: Center(
                child: SizedBox(
                  width: 320,
                  child: OpenQrView(
                    link: const TicketLink('ticket_123'),
                    policy: policy,
                    semanticLabel: 'Ticket QR',
                    errorBuilder: (_) => const Text('Unavailable'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      final qr = tester.widget<PrettyQrView>(find.byType(PrettyQrView));
      expect(qr.decoration?.background, Colors.white);
      expect(qr.decoration?.quietZone, const PrettyQrQuietZone.modules(4));
      expect(
        qr.decoration?.shape,
        const PrettyQrSquaresSymbol(color: Colors.black),
      );
      expect(qr.qrImage.errorCorrectLevel, QrErrorCorrectLevel.H);
      expect(find.text(ticket), findsOneWidget);
      expect(find.bySemanticsLabel('Ticket QR'), findsOneWidget);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
  );

  testWidgets(
    'invalid, disabled and oversized output uses only the local error builder',
    (tester) async {
      for (final link in [
        TicketLink('x' * 5000),
        const PairingLink('disabled'),
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            home: OpenQrView(
              link: link,
              policy: policy,
              semanticLabel: 'QR',
              errorBuilder: (_) => const Text('Unavailable'),
            ),
          ),
        );
        expect(find.text('Unavailable'), findsOneWidget);
        expect(find.byType(PrettyQrView), findsNothing);
        expect(find.byType(SelectableText), findsNothing);
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets(
    'camera, gallery and paste preserve shared fixture meaning from Pay',
    (tester) async {
      final fixtures =
          jsonDecode(File('../../fixtures/links.json').readAsStringSync())
              as Map;
      final cases = (fixtures['decodeCases'] as List).cast<Map>().where(
        (item) =>
            item['policy'] == 'skyzai' &&
            (item['raw'] as String).isNotEmpty &&
            ((item['expected'] as Map)['status'] != 'recognized' ||
                ((item['expected'] as Map)['link'] as Map)['kind'] !=
                    'walletAddress'),
      );
      final received = <Map<String, Object?>>[];
      final observations = <Object?>[];
      await tester.pumpWidget(
        scanner(
          onDecoded: (result, scope) async {
            observations.add([
              scope.context,
              scope.interruption,
              platform.running,
            ]);
            received.add(result.toJson());
            return OpenQrHandling.handled;
          },
        ),
      );
      await tester.pump();
      for (final item in cases) {
        for (final source in ['camera', 'gallery', 'paste']) {
          final before = received.length;
          await key.currentState!.retry();
          expect(key.currentState!.status, OpenQrScannerStatus.scanning);
          final raw = item['raw'] as String;
          switch (source) {
            case 'camera':
              // Invoke the plugin's capture callback, including hostile/long data.
              tester
                  .widget<MobileScanner>(find.byType(MobileScanner))
                  .onDetect!(capture(raw));
              await tester.pump();
            case 'gallery':
              platform.image = capture(raw);
              await key.currentState!.analyzeImage('chosen-local-image');
            case 'paste':
              await key.currentState!.submitText(raw);
          }
          expect(
            received.length,
            before + 1,
            reason: '${item['id']}: $source, ${key.currentState!.status}',
          );
          expect(observations.last, [OpenQrScanContext.pay, null, false]);
          expect(
            received.last,
            item['expected'],
            reason: '${item['id']}: $source',
          );
        }
      }
      expect(received.length, cases.length * 3);
      expect(platform.cameraFormats, [BarcodeFormat.qrCode]);
      expect(platform.imageFormats, [BarcodeFormat.qrCode]);
      await close(tester);
    },
  );

  testWidgets(
    'duplicate camera events and paste cannot overlap a pending review',
    (tester) async {
      var calls = 0;
      final review = Completer<OpenQrHandling>();
      OpenQrDecode? received;
      await tester.pumpWidget(
        scanner(
          onDecoded: (result, _) {
            calls++;
            received = result;
            return review.future;
          },
        ),
      );
      await tester.pump();
      platform.emit(ticket);
      platform.emit(ticket);
      await tester.pump();
      await key.currentState!.submitText(ticket);
      expect(calls, 1);
      expect((received as Recognized).link, isA<TicketLink>());
      expect(key.currentState!.status, OpenQrScannerStatus.processing);
      expect(platform.running, isFalse);
      review.complete(OpenQrHandling.handled);
      await tester.pump();
      expect(key.currentState!.status, OpenQrScannerStatus.handled);
      await key.currentState!.submitText(ticket);
      expect(calls, 1);
      await key.currentState!.retry();
      expect(
        platform.running,
        isTrue,
        reason:
            '${key.currentState!.status}, starts=${platform.starts}, stops=${platform.stops}, camera=${tester.widget<MobileScanner>(find.byType(MobileScanner)).controller!.value.error}',
      );
      await close(tester);
    },
  );

  testWidgets(
    'a cancelled review resumes; explicit scanner cancellation stays stopped',
    (tester) async {
      await tester.pumpWidget(
        scanner(onDecoded: (_, _) async => OpenQrHandling.cancelled),
      );
      await tester.pump();
      await key.currentState!.submitText(ticket);
      await tester.pump();
      expect(
        platform.running,
        isTrue,
        reason:
            '${key.currentState!.status}, starts=${platform.starts}, stops=${platform.stops}, camera=${tester.widget<MobileScanner>(find.byType(MobileScanner)).controller!.value.error}',
      );
      key.currentState!.cancel();
      await tester.pump();
      expect(key.currentState!.status, OpenQrScannerStatus.cancelled);
      expect(platform.running, isFalse);
      await close(tester);
    },
  );

  testWidgets(
    'account and cancellation guards block dispatch before a host callback',
    (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        scanner(
          onDecoded: (_, _) async {
            calls++;
            return OpenQrHandling.handled;
          },
        ),
      );
      await tester.pump();
      current = false;
      await key.currentState!.submitText(ticket);
      expect(calls, 0);
      expect(key.currentState!.status, OpenQrScannerStatus.obsolete);
      current = true;
      cancelled = true;
      await key.currentState!.retry();
      expect(key.currentState!.status, OpenQrScannerStatus.cancelled);
      expect(platform.running, isFalse);
      await close(tester);
    },
  );

  testWidgets('account switch discards a delayed completion', (tester) async {
    final review = Completer<OpenQrHandling>();
    OpenQrInvocation? pending;
    await tester.pumpWidget(
      scanner(
        onDecoded: (_, scope) {
          pending = scope;
          return review.future;
        },
      ),
    );
    await tester.pump();
    final processing = key.currentState!.submitText(ticket);
    await tester.pump();
    current = false;
    expect(pending!.interruption, OpenQrHandling.obsolete);
    review.complete(OpenQrHandling.handled);
    await processing;
    expect(key.currentState!.status, OpenQrScannerStatus.obsolete);
    expect(platform.running, isFalse);
    await close(tester);
  });

  testWidgets('new caller scope invalidates the old in-flight review', (
    tester,
  ) async {
    final review = Completer<OpenQrHandling>();
    OpenQrInvocation? pending;
    Future<OpenQrHandling> callback(OpenQrDecode _, OpenQrInvocation scope) {
      pending = scope;
      return review.future;
    }

    await tester.pumpWidget(scanner(onDecoded: callback));
    await tester.pump();
    final processing = key.currentState!.submitText(ticket);
    await tester.pump();
    await tester.pumpWidget(
      scanner(
        onDecoded: callback,
        scope: OpenQrInvocation(
          context: OpenQrScanContext.network,
          isCurrent: () => true,
          isCancelled: () => false,
        ),
      ),
    );
    expect(pending!.interruption, OpenQrHandling.obsolete);
    review.complete(OpenQrHandling.handled);
    await processing;
    expect(key.currentState!.status, OpenQrScannerStatus.obsolete);
    await close(tester);
  });

  testWidgets(
    'background stops capture; foreground resumes only an idle scanner',
    (tester) async {
      await tester.pumpWidget(
        scanner(onDecoded: (_, _) async => OpenQrHandling.handled),
      );
      await tester.pump();
      expect(platform.running, isTrue);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(platform.running, isFalse);
      expect(key.currentState!.status, OpenQrScannerStatus.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(
        platform.running,
        isTrue,
        reason:
            '${key.currentState!.status}, starts=${platform.starts}, stops=${platform.stops}, camera=${tester.widget<MobileScanner>(find.byType(MobileScanner)).controller!.value.error}',
      );
      await key.currentState!.submitText(ticket);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(platform.running, isFalse);
      await close(tester);
    },
  );

  testWidgets(
    'cancellation discards pending image analysis and disposal is safe',
    (tester) async {
      var calls = 0;
      platform.pendingImage = Completer<BarcodeCapture?>();
      await tester.pumpWidget(
        scanner(
          onDecoded: (_, _) async {
            calls++;
            return OpenQrHandling.handled;
          },
        ),
      );
      await tester.pump();
      final state = key.currentState!;
      final analysis = state.analyzeImage('chosen-image');
      await tester.pump();
      state.cancel();
      platform.pendingImage!.complete(capture(ticket));
      await analysis;
      expect(calls, 0);
      expect(state.status, OpenQrScannerStatus.cancelled);
      await close(tester);
    },
  );

  testWidgets(
    'disposed scanner discards late review results and invalidates scope',
    (tester) async {
      final review = Completer<OpenQrHandling>();
      OpenQrInvocation? pending;
      await tester.pumpWidget(
        scanner(
          onDecoded: (_, scope) {
            pending = scope;
            return review.future;
          },
        ),
      );
      await tester.pump();
      final processing = key.currentState!.submitText(ticket);
      await tester.pump();
      await close(tester);
      expect(pending!.interruption, OpenQrHandling.obsolete);
      review.complete(OpenQrHandling.handled);
      await processing;
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'permission refusal exposes safe state, allows paste and supports retry',
    (tester) async {
      platform.startError = const MobileScannerException(
        errorCode: MobileScannerErrorCode.permissionDenied,
      );
      var calls = 0;
      await tester.pumpWidget(
        scanner(
          onDecoded: (_, _) async {
            calls++;
            return OpenQrHandling.handled;
          },
        ),
      );
      await tester.pump();
      expect(key.currentState!.status, OpenQrScannerStatus.permissionDenied);
      await key.currentState!.submitText(ticket);
      expect(calls, 1);
      platform.startError = null;
      await key.currentState!.retry();
      expect(key.currentState!.status, OpenQrScannerStatus.scanning);
      await close(tester);
    },
  );

  testWidgets('missing code and unavailable gallery produce finite states', (
    tester,
  ) async {
    await tester.pumpWidget(
      scanner(onDecoded: (_, _) async => OpenQrHandling.handled),
    );
    await tester.pump();
    await key.currentState!.analyzeImage('no-code');
    expect(key.currentState!.status, OpenQrScannerStatus.noCode);
    await key.currentState!.retry();
    await key.currentState!.analyzeImage('unsupported');
    expect(key.currentState!.status, OpenQrScannerStatus.unavailable);
    await close(tester);
  });

  testWidgets(
    'callback failures do not leak exception messages or restart capture',
    (tester) async {
      await tester.pumpWidget(
        scanner(onDecoded: (_, _) async => throw StateError('private payload')),
      );
      await tester.pump();
      await key.currentState!.submitText(ticket);
      expect(key.currentState!.status, OpenQrScannerStatus.error);
      expect(find.textContaining('private payload'), findsNothing);
      expect(platform.running, isFalse);
      await close(tester);
    },
  );

  testWidgets(
    'legacy handoff preserves the complete URI only for the opted-in host',
    (tester) async {
      const raw = 'wc:topic@2?relay-protocol=irn&symKey=opaque-test-only';
      var calls = 0;
      Object? received;
      await tester.pumpWidget(
        scanner(
          onDecoded: (_, _) async => throw StateError('wrong handoff'),
          onLegacy: (protocol, value, scope) async {
            calls++;
            received = [protocol, value, scope.interruption];
            return OpenQrHandling.handled;
          },
        ),
      );
      await tester.pump();
      await key.currentState!.submitText(raw);
      expect(calls, 1);
      expect(received, [LegacyProtocol.walletConnect, raw, null]);
      expect(key.currentState!.status, OpenQrScannerStatus.handled);
      await close(tester);
    },
  );

  testWidgets(
    'dispose during pending camera startup stops before releasing platform',
    (tester) async {
      platform.pendingStart = Completer<MobileScannerViewAttributes>();
      await tester.pumpWidget(
        scanner(onDecoded: (_, _) async => OpenQrHandling.handled),
      );
      await tester.pump();
      expect(platform.starts, 1);
      await tester.pumpWidget(const SizedBox.shrink());
      platform.pendingStart!.complete(FakeScannerPlatform.attributes);
      await tester.pump();
      expect(platform.running, isFalse);
      expect(platform.stops, 1);
      expect(platform.disposals, 1);
      expect(tester.takeException(), isNull);
    },
  );
}
