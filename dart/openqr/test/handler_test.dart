/// Exercises cancellation and account/caller invalidation around async host work.
/// Guarded navigation outcomes never assert that a business action completed.
library;

import 'dart:async';

import 'package:openqr/openqr.dart';
import 'package:test/test.dart';

void main() {
  const link = TicketLink('ticket_01');
  for (final outcome in OpenQrHandling.values) {
    test('preserves ${outcome.name} and the exact ticket/context', () async {
      final invocation = OpenQrInvocation(
        context: OpenQrScanContext.pay,
        isCurrent: () => true,
        isCancelled: () => false,
      );
      var calls = 0;
      final result = await invocation.run(link, (target, scope) async {
        calls++;
        expect(identical(target, link), isTrue);
        expect(identical(scope, invocation), isTrue);
        expect(scope.context, OpenQrScanContext.pay);
        return outcome;
      });
      expect(result, outcome);
      expect(calls, 1);
    });
  }
  for (final obsolete in [false, true]) {
    test(
      'blocks ${obsolete ? 'obsolete' : 'cancelled'} invocation before callback',
      () async {
        final invocation = OpenQrInvocation(
          context: OpenQrScanContext.general,
          isCurrent: () => !obsolete,
          isCancelled: () => !obsolete,
        );
        final result = await invocation.run(
          link,
          (_, _) async => fail('Must not dispatch'),
        );
        expect(
          result,
          obsolete ? OpenQrHandling.obsolete : OpenQrHandling.cancelled,
        );
      },
    );
    test(
      'discards delayed ${obsolete ? 'obsolete' : 'cancelled'} completion',
      () async {
        var current = true;
        var cancelled = false;
        var effects = 0;
        final resolved = Completer<void>();
        final invocation = OpenQrInvocation(
          context: OpenQrScanContext.network,
          isCurrent: () => current,
          isCancelled: () => cancelled,
        );
        final result = invocation.run(link, (_, scope) async {
          await resolved.future;
          if (scope.interruption case final interruption?) return interruption;
          effects++;
          return OpenQrHandling.handled;
        });
        current = !obsolete;
        cancelled = !obsolete;
        resolved.complete();
        expect(
          await result,
          obsolete ? OpenQrHandling.obsolete : OpenQrHandling.cancelled,
        );
        expect(effects, 0);
      },
    );
  }
  test('rechecks even when callback returns a stale handled outcome', () async {
    var current = true;
    final invocation = OpenQrInvocation(
      context: OpenQrScanContext.general,
      isCurrent: () => current,
      isCancelled: () => false,
    );
    expect(
      await invocation.run(link, (_, _) async {
        current = false;
        return OpenQrHandling.handled;
      }),
      OpenQrHandling.obsolete,
    );
  });
  test('errors reach the host UI boundary', () async {
    final invocation = OpenQrInvocation(
      context: OpenQrScanContext.general,
      isCurrent: () => true,
      isCancelled: () => false,
    );
    await expectLater(
      invocation.run(link, (_, _) async => throw StateError('host error')),
      throwsStateError,
    );
  });
}
