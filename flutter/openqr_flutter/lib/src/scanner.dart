/// One guarded input path for camera, host-pasted text and chosen images.
/// Detector errors invalidate pending work and hold capture until retry().
/// No navigation, raw-payload logging or interpretation of opaque legacy keys.
library;

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:openqr/openqr.dart';

enum OpenQrScannerStatus {
  starting,
  scanning,
  paused,
  processing,
  handled,
  cancelled,
  obsolete,
  unsupported,
  permissionDenied,
  unavailable,
  noCode,
  error,
}

typedef OpenQrDecodedCallback =
    Future<OpenQrHandling> Function(
      OpenQrDecode result,
      OpenQrInvocation invocation,
    );

typedef OpenQrLegacyCallback =
    Future<OpenQrHandling> Function(
      LegacyProtocol protocol,
      String raw,
      OpenQrInvocation invocation,
    );

/// The builder must keep [preview] mounted; all chrome and copy are host-owned.
typedef OpenQrScannerBuilder =
    Widget Function(
      BuildContext context,
      Widget preview,
      OpenQrScannerState scanner,
    );

class OpenQrScanner extends StatefulWidget {
  const OpenQrScanner({
    super.key,
    required this.policy,
    required this.invocation,
    required this.onDecoded,
    required this.builder,
    this.onLegacy,
  });

  final OpenQrPolicy policy;
  final OpenQrInvocation invocation;
  final OpenQrDecodedCallback onDecoded;
  final OpenQrLegacyCallback? onLegacy;
  final OpenQrScannerBuilder builder;

  @override
  State<OpenQrScanner> createState() => OpenQrScannerState();
}

class OpenQrScannerState extends State<OpenQrScanner>
    with WidgetsBindingObserver {
  final _camera = MobileScannerController(
    autoStart: false,
    formats: const [BarcodeFormat.qrCode],
  );
  Future<void> _cameraWork = Future.value();
  OpenQrScannerStatus _status = OpenQrScannerStatus.starting;
  bool _foreground = true;
  bool _busy = false;
  bool _hold = false;
  bool _cancelled = false;
  int _generation = 0;

  OpenQrScannerStatus get status => _status;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _foreground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncCamera());
  }

  void _show(OpenQrScannerStatus value) {
    if (mounted) setState(() => _status = value);
  }

  OpenQrInvocation _scope() {
    final generation = _generation;
    final host = widget.invocation;
    return OpenQrInvocation(
      context: host.context,
      isCurrent: () => mounted && generation == _generation && host.isCurrent(),
      isCancelled: () => _cancelled || host.isCancelled(),
    );
  }

  void _cameraError(Object? error) => _show(
    error is MobileScannerException &&
            error.errorCode == MobileScannerErrorCode.permissionDenied
        ? OpenQrScannerStatus.permissionDenied
        : OpenQrScannerStatus.unavailable,
  );

  // Serialize native start/stop, including a background/dispose during startup.
  Future<void> _syncCamera() => _cameraWork = _cameraWork.then((_) async {
    try {
      if (mounted && _foreground && !_hold && !_busy) {
        final interrupted = _scope().interruption;
        if (interrupted != null) {
          _hold = true;
          _show(OpenQrScannerStatus.values.byName(interrupted.name));
          await _camera.stop();
          return;
        }
        await _camera.start();
        if (!mounted || !_foreground || _hold || _busy) {
          await _camera.stop();
          return;
        }
        if (_camera.value.error != null) {
          _cameraError(_camera.value.error);
        } else {
          _show(OpenQrScannerStatus.scanning);
        }
      } else {
        await _camera.stop();
      }
    } catch (_) {
      if (mounted && _foreground && !_busy && !_hold) _cameraError(null);
    }
  });

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground) {
      _generation++;
      _show(OpenQrScannerStatus.paused);
    }
    unawaited(_syncCamera());
  }

  @override
  void didUpdateWidget(OpenQrScanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.invocation != widget.invocation ||
        oldWidget.policy != widget.policy) {
      _generation++;
      _hold = true;
      _show(OpenQrScannerStatus.obsolete);
      unawaited(_syncCamera());
    }
  }

  String? _firstCode(BarcodeCapture capture) {
    for (final barcode in capture.barcodes) {
      if (barcode.rawValue case final String raw when raw.isNotEmpty) {
        return raw;
      }
    }
    return null;
  }

  void _capture(BarcodeCapture capture) {
    final raw = _firstCode(capture);
    if (raw != null) unawaited(submitText(raw));
  }

  /// Uses the same decoder/callback as camera input; text is never retained.
  Future<void> submitText(String raw) => _process(() async => raw);

  /// Host chooses the image and owns gallery permission; unsupported platforms
  /// report [OpenQrScannerStatus.unavailable] and can offer paste instead.
  Future<void> analyzeImage(String path) => _process(() async {
    final capture = await _camera.analyzeImage(
      path,
      formats: const [BarcodeFormat.qrCode],
    );
    return capture == null ? null : _firstCode(capture);
  });

  Future<void> _process(Future<String?> Function() read) async {
    if (!mounted || !_foreground || _busy || _hold) return;
    _busy = true;
    _hold = true;
    final generation = _generation;
    final invocation = _scope();
    _show(OpenQrScannerStatus.processing);
    try {
      await _syncCamera();
      if (generation != _generation) return;
      if (invocation.interruption case final OpenQrHandling stopped) {
        _show(OpenQrScannerStatus.values.byName(stopped.name));
        return;
      }
      final raw = await read();
      if (generation != _generation) return;
      if (invocation.interruption case final OpenQrHandling stopped) {
        _show(OpenQrScannerStatus.values.byName(stopped.name));
        return;
      }
      if (raw == null) {
        _show(OpenQrScannerStatus.noCode);
        return;
      }
      final result = decode(raw, policy: widget.policy);
      final outcome = result is Legacy && widget.onLegacy != null
          ? await widget.onLegacy!(result.protocol, raw, invocation)
          : await widget.onDecoded(result, invocation);
      if (generation != _generation) return;
      final finalOutcome = invocation.interruption ?? outcome;
      _show(OpenQrScannerStatus.values.byName(finalOutcome.name));
      if (finalOutcome == OpenQrHandling.cancelled && !_cancelled) {
        _hold = false;
      }
    } on UnsupportedError {
      if (generation == _generation) _show(OpenQrScannerStatus.unavailable);
    } catch (_) {
      // Host callback exceptions can contain secrets, so expose only safe state.
      if (generation == _generation) _show(OpenQrScannerStatus.error);
    } finally {
      _busy = false;
      if (mounted) unawaited(_syncCamera());
    }
  }

  /// Stops capture and invalidates the pending invocation without navigation.
  void cancel() {
    _cancelled = true;
    _hold = true;
    _show(OpenQrScannerStatus.cancelled);
    unawaited(_syncCamera());
  }

  /// Explicit retry after handled/unsupported/error or a changed host scope.
  Future<void> retry() async {
    if (!mounted || _busy) return;
    _generation++;
    _cancelled = false;
    _hold = false;
    _show(OpenQrScannerStatus.starting);
    await _syncCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _generation++;
    _hold = true;
    unawaited(
      _syncCamera().then((_) async {
        try {
          await _camera.dispose();
        } catch (_) {
          // Disposal cannot report a platform exception into a departed host UI.
        }
      }),
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(
    context,
    MobileScanner(
      controller: _camera,
      useAppLifecycleState: false,
      onDetect: _capture,
      onDetectError: (_, _) {
        _generation++;
        _hold = true;
        unawaited(_syncCamera());
        _show(OpenQrScannerStatus.error);
      },
      errorBuilder: (_, _) => const SizedBox.shrink(),
    ),
    this,
  );
}
