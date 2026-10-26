/// Executes every shared link, refusal, signature and replacement vector.
/// Expected results are read directly from fixtures, never derived from the codec.
library;

import 'package:openqr/openqr.dart';
import 'package:test/test.dart';

import 'fixture_host.dart';

void main() {
  final links = fixture('links');
  final policies = {
    for (final entry in (links['policies'] as Map<String, dynamic>).entries)
      entry.key: policyFromJson(entry.value as Map<String, dynamic>),
  };
  group('shared decoder corpus', () {
    for (final c in links['decodeCases'] as List) {
      test(c['id'] as String, () {
        final policy = policies[c['policy']]!;
        final result = decode(c['raw'] as String, policy: policy);
        expect(result.toJson(), c['expected']);
        if (c['canonicalUrl'] != null) {
          final link = (result as Recognized).link;
          final encoded = encode(link, policy: policy).toString();
          expect(encoded, c['canonicalUrl']);
          expect(decode(encoded, policy: policy).toJson(), {
            'status': 'recognized',
            'source': 'canonical',
            'link': link.toJson(),
          });
        }
      });
    }
  });
  group('shared encoder refusal corpus', () {
    for (final c in links['encodeRejectCases'] as List) {
      test(c['id'] as String, () {
        expect(
          () => encode(
            linkFromJson(c['link'] as Map<String, dynamic>),
            policy: policies[c['policy']]!,
          ),
          throwsFormatException,
        );
      });
    }
  });
  final records = fixture('records');
  final envelopes = records['records'] as Map<String, dynamic>;
  group('shared verification corpus', () {
    for (final c in records['verifyCases'] as List) {
      test(c['id'] as String, () {
        final expected = c['expected'];
        expect(
          isVerifiedNostrRecord(
            envelopes[c['record']],
            kind: expected['kind'] as int,
            publicKeyHex: expected['publicKeyHex'] as String,
            dTag: expected['dTag'] as String,
          ),
          c['verified'],
        );
      });
    }
  });
  group('shared replacement corpus', () {
    for (final c in records['selectionCases'] as List) {
      test(c['id'] as String, () {
        final expected = c['expected'];
        final selected = newestVerifiedRecord(
          (c['records'] as List).map((name) => envelopes[name]),
          kind: expected['kind'] as int,
          publicKeyHex: expected['publicKeyHex'] as String,
          dTag: expected['dTag'] as String,
        );
        expect(
          selected?.toJson(),
          c['selected'] == null ? null : envelopes[c['selected']],
        );
      });
    }
  });
}
