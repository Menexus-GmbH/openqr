/// Verifies supplied public envelopes and orders addressable replacements.
/// Extracted from Skyzai's reviewed nostr_event_verifier.dart; raw validation precedes adaptation.
library;

import 'dart:convert';

import 'package:dart_nostr/nostr/model/event/event.dart';

final _hex32 = RegExp(r'^[a-f0-9]{64}$');
final _hex64 = RegExp(r'^[a-f0-9]{128}$');
const maxRecordContentBytes = 64 * 1024;
const maxRecordCount = 100;

final class NostrRecord {
  NostrRecord({
    required this.id,
    required this.pubkey,
    required this.createdAt,
    required this.kind,
    required List<List<String>> tags,
    required this.content,
    required this.sig,
  }) : tags = List.unmodifiable(
         tags.map((tag) => List<String>.unmodifiable(tag)),
       );

  final String id;
  final String pubkey;
  final int createdAt;
  final int kind;
  final List<List<String>> tags;
  final String content;
  final String sig;

  /// Strict envelope conversion; no timestamp, tag or null-content coercion.
  static NostrRecord? tryParse(Object? value) {
    if (value is NostrRecord) value = value.toJson();
    if (value is! Map) return null;
    final id = value['id'],
        pubkey = value['pubkey'],
        time = value['created_at'];
    final kind = value['kind'],
        tags = value['tags'],
        content = value['content'];
    final sig = value['sig'];
    if (id is! String ||
        !_hex32.hasMatch(id) ||
        pubkey is! String ||
        !_hex32.hasMatch(pubkey) ||
        time is! int ||
        time < 0 ||
        time > 8640000000000 ||
        kind is! int ||
        kind < 0 ||
        kind > 65535 ||
        tags is! List ||
        tags.any((tag) => tag is! List || tag.any((v) => v is! String)) ||
        content is! String ||
        utf8.encode(content).length > maxRecordContentBytes ||
        sig is! String ||
        !_hex64.hasMatch(sig)) {
      return null;
    }
    return NostrRecord(
      id: id,
      pubkey: pubkey,
      createdAt: time,
      kind: kind,
      tags: [for (final tag in tags) List<String>.from(tag as List)],
      content: content,
      sig: sig,
    );
  }

  Map<String, Object> toJson() => {
    'id': id,
    'pubkey': pubkey,
    'created_at': createdAt,
    'kind': kind,
    'tags': tags,
    'content': content,
    'sig': sig,
  };
}

bool isVerifiedNostrRecord(
  Object? event, {
  required int kind,
  required String publicKeyHex,
  required String dTag,
}) {
  final record = NostrRecord.tryParse(event);
  if (record == null) return false;
  try {
    final adapted = NostrEvent(
      id: record.id,
      pubkey: record.pubkey,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        record.createdAt * 1000,
        isUtc: true,
      ),
      kind: record.kind,
      tags: record.tags,
      content: record.content,
      sig: record.sig,
    );
    return adapted.kind == kind &&
        adapted.pubkey == publicKeyHex &&
        adapted.tags!.any(
          (tag) => tag.length >= 2 && tag[0] == 'd' && tag[1] == dTag,
        ) &&
        adapted.id ==
            NostrEvent.getEventId(
              kind: adapted.kind!,
              content: adapted.content!,
              createdAt: adapted.createdAt!,
              tags: adapted.tags!,
              pubkey: adapted.pubkey,
            ) &&
        adapted.isVerified();
  } catch (_) {
    return false;
  }
}

int compareNostrRecords(NostrRecord a, NostrRecord b) {
  final time = b.createdAt.compareTo(a.createdAt);
  return time != 0 ? time : a.id.compareTo(b.id);
}

/// Returns the newest envelope without interpreting its content.
/// An over-limit batch throws instead of selecting from a truncated history.
NostrRecord? newestVerifiedRecord(
  Iterable<Object?> events, {
  required int kind,
  required String publicKeyHex,
  required String dTag,
}) {
  NostrRecord? newest;
  var count = 0;
  for (final event in events) {
    if (++count > maxRecordCount) {
      throw StateError('OpenQR record batch too large');
    }
    final record = NostrRecord.tryParse(event);
    if (record == null ||
        !isVerifiedNostrRecord(
          record,
          kind: kind,
          publicKeyHex: publicKeyHex,
          dTag: dTag,
        )) {
      continue;
    }
    if (newest == null || compareNostrRecords(record, newest) < 0) {
      newest = record;
    }
  }
  return newest;
}
