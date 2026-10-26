/// Ephemeral host invocation guards and review outcomes.
/// Hosts must also check the guards within callbacks after each awaited lookup.
library;

import 'types.dart';

enum OpenQrScanContext {
  general,
  pay,
  network,
  connect,
  bookingCheck,
  ticketCheck,
  walletConnect,
}

enum OpenQrHandling { handled, cancelled, obsolete, unsupported }

typedef OpenQrHandler =
    Future<OpenQrHandling> Function(
      OpenQrLink link,
      OpenQrInvocation invocation,
    );

final class OpenQrInvocation {
  const OpenQrInvocation({
    required this.context,
    required this.isCurrent,
    required this.isCancelled,
  });
  final OpenQrScanContext context;
  final bool Function() isCurrent;
  final bool Function() isCancelled;

  OpenQrHandling? get interruption => !isCurrent()
      ? OpenQrHandling.obsolete
      : isCancelled()
      ? OpenQrHandling.cancelled
      : null;

  /// Checks before dispatch and after completion; callback errors reach host UI.
  Future<OpenQrHandling> run(OpenQrLink link, OpenQrHandler handler) async {
    final stopped = interruption;
    if (stopped != null) return stopped;
    final outcome = await handler(link, this);
    return interruption ?? outcome;
  }
}
