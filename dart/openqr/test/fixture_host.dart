/// Synthetic host configuration for the shared corpus, not a production adapter.
/// Legacy payloads stay opaque and amounts are never converted to floating point.
library;

import 'dart:convert';
import 'dart:io';

import 'package:openqr/openqr.dart';

Map<String, dynamic> fixture(String name) =>
    jsonDecode(File('../../fixtures/$name.json').readAsStringSync())
        as Map<String, dynamic>;

OpenQrPolicy policyFromJson(Map<String, dynamic> json) {
  final legacy = (json['legacyProtocols'] as List).cast<String>().toSet();
  return OpenQrPolicy(
    canonicalOrigin: json['canonicalOrigin'] as String,
    acceptedOrigins: (json['acceptedOrigins'] as List).cast<String>().toSet(),
    enabledKinds: (json['enabledKinds'] as List)
        .map((name) => OpenQrKind.values.byName(name as String))
        .toSet(),
    analyticsQueryKeys: (json['analyticsQueryKeys'] as List)
        .cast<String>()
        .toSet(),
    wallets: {
      for (final entry in (json['wallets'] as Map<String, dynamic>).entries)
        entry.key: OpenQrWalletPolicy(
          networks: (entry.value['networks'] as List).cast<String>().toSet(),
          walletTypes: (entry.value['walletTypes'] as List)
              .cast<String>()
              .toSet(),
          assets: (entry.value['assets'] as List).cast<String>().toSet(),
          isValidAddress: (address) => switch (entry.key) {
            'hedera' => RegExp(
              r'^0\.0\.[0-9]+(?:-[a-z]{5})?$',
            ).hasMatch(address),
            'ethereum' => RegExp(r'^0x[0-9a-fA-F]{40}$').hasMatch(address),
            _ => false,
          },
        ),
    },
    legacyAdapter: (raw) {
      if (raw.startsWith('{')) {
        final data = jsonDecode(raw);
        if (data is Map) {
          if (legacy.contains('walletJson') &&
              data['walletAddress'] is String &&
              (data.containsKey('value') || data.containsKey('token'))) {
            return const Legacy(LegacyProtocol.walletJson);
          }
          if (legacy.contains('bookingJson') && data['bookingId'] is String) {
            return const Legacy(LegacyProtocol.bookingJson);
          }
        }
        return null;
      }
      final uri = Uri.parse(raw);
      if (legacy.contains('paymentScheme') &&
          uri.scheme == 'skyzai' &&
          uri.host == 'pay' &&
          uri.path.isEmpty &&
          uri.queryParameters.length == 1 &&
          RegExp(
            r'^[A-Za-z0-9_-]{1,128}$',
          ).hasMatch(uri.queryParameters['id'] ?? '')) {
        return Recognized(
          PaymentLink(uri.queryParameters['id']!),
          OpenQrSource.compatible,
        );
      }
      final parts = uri.pathSegments;
      if (uri.scheme != 'https') return null;
      if (legacy.contains('walletUrl') &&
          parts.length == 2 &&
          parts.first == 'wallet' &&
          !uri.queryParameters.containsKey('v')) {
        return const Legacy(LegacyProtocol.walletUrl);
      }
      if (legacy.contains('ticketLegacy') &&
          parts.length == 3 &&
          parts.first == 'events') {
        return const Legacy(LegacyProtocol.ticketLegacy);
      }
      return null;
    },
  );
}

OpenQrLink linkFromJson(Map<String, dynamic> json) => switch (json['kind']) {
  'identity' => IdentityLink(
    npub: json['npub'] as String,
    publicKeyHex: json['publicKeyHex'] as String,
    intent: OpenQrIntent.values.byName(json['intent'] as String),
  ),
  'payment' => PaymentLink(json['paymentId'] as String),
  'walletRequest' => WalletRequestLink(json['requestId'] as String),
  'bookingSession' => BookingSessionLink(json['sessionId'] as String),
  'booking' => BookingLink(json['bookingId'] as String),
  'ticket' => TicketLink(json['ticketRef'] as String),
  'pairing' => PairingLink(json['pairingId'] as String),
  'walletAddress' => WalletAddressLink(
    address: json['address'] as String,
    chain: json['chain'] as String,
    network: json['network'] as String?,
    walletType: json['walletType'] as String?,
    asset: json['asset'] as String?,
  ),
  _ => throw StateError('Unknown fixture kind'),
};
