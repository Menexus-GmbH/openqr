/// Checks policy trust, immutable configuration and bounded record selection.
/// Refusals never hand hostile known links to an installed legacy parser.
library;

import 'package:openqr/openqr.dart';
import 'package:test/test.dart';

import 'fixture_host.dart';

void main() {
  test('configuration requires exact HTTPS origins', () {
    for (final origin in [
      'http://skyzai.com',
      'https://*.example',
      'https://user@skyzai.com',
      'https://@skyzai.com',
      'https://skyzai.com:444',
      'https://skyzai.com/path',
      'https://skyzai.com?redirect=1',
    ]) {
      expect(
        () => OpenQrPolicy(canonicalOrigin: origin),
        throwsFormatException,
      );
    }
    final kinds = {OpenQrKind.ticket};
    final policy = OpenQrPolicy(enabledKinds: kinds);
    kinds.clear();
    expect(policy.enabledKinds, {OpenQrKind.ticket});
    expect(() => policy.enabledKinds.clear(), throwsUnsupportedError);
  });
  test('invalid syntax, origin and version cannot fall through to legacy', () {
    var calls = 0;
    final policy = OpenQrPolicy(
      legacyAdapter: (_) {
        calls++;
        return const Legacy(LegacyProtocol.ticketLegacy);
      },
    );
    for (final raw in [
      'https://evil.example/pay/id',
      'https://@skyzai.com/pay/id',
      'https://skyzai.com/wallet/id?v=2',
      'https://skyzai.com/ignored/../pay/id?v=1',
      'https://skyzai.com/pay/id?v=1&redirect=evil',
      'https://skyzai.com/pay/id?v=1#extra',
    ]) {
      expect(decode(raw, policy: policy), isNot(isA<Legacy>()));
    }
    expect(calls, 0);
    expect(decode('old-host-code', policy: policy), isA<Legacy>());
    expect(calls, 1);
  });
  test('malformed UTF-16 is rejected without echoing input', () {
    final raw = String.fromCharCode(0xd800);
    expect(decode(raw, policy: OpenQrPolicy()).toJson(), {
      'status': 'invalid',
      'reason': 'malformed',
    });
  });
  test('record limits reject content and whole batches', () {
    final records = fixture('records');
    final original = records['records']['newer'] as Map<String, dynamic>;
    final oversized = {
      ...original,
      'content': 'a' * (maxRecordContentBytes + 1),
    };
    expect(NostrRecord.tryParse(oversized), isNull);
    expect(
      () => newestVerifiedRecord(
        List.filled(maxRecordCount + 1, null),
        kind: original['kind'] as int,
        publicKeyHex: original['pubkey'] as String,
        dTag: 'payments',
      ),
      throwsStateError,
    );
    final record = NostrRecord.tryParse(original)!;
    expect(() => record.tags.clear(), throwsUnsupportedError);
    expect(() => record.tags.first.clear(), throwsUnsupportedError);
  });
}
