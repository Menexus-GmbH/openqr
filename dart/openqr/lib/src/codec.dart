/// Strict v1 codec with raw-path checks before Dart URI normalization.
/// The reviewed profile decoder's checksum, round trip and one-slash compatibility survive extraction.
library;

import 'dart:convert';

import 'package:dart_nostr/nostr/core/utils.dart';
import 'package:dart_nostr/nostr/instance/bech32/bech32.dart';
import 'package:dart_nostr/nostr/model/debug_options.dart';

import 'policy.dart';
import 'types.dart';

final _bech32 = NostrBech32(
  logger: NostrLogger(
    passedDebugOptions: NostrDebugOptions(tag: 'OpenQR', isLogsEnabled: false),
  ),
);
final _reference = RegExp(r'^[A-Za-z0-9_-]{1,128}$');
final _hedera = RegExp(r'^0\.0\.[0-9]+(?:-[a-z]{5})?$');
final _controls = RegExp(r'[\x00-\x1f\x7f-\x9f]');
const _malformed = Invalid(OpenQrReason.malformed);
const _unknown = Unsupported(OpenQrReason.unknownKind);

OpenQrDecode decode(String raw, {required OpenQrPolicy policy}) {
  if (utf8.encode(raw).length > 4096) {
    return const Invalid(OpenQrReason.inputTooLong);
  }
  if (utf8.decode(utf8.encode(raw)) != raw) return _malformed;
  final text = raw.trim();
  if (text.isEmpty || _controls.hasMatch(text)) {
    return _malformed;
  }
  try {
    if (text.startsWith('{')) return _legacy(text, policy);
    if (text.contains('\\')) return _malformed;
    Uri.decodeComponent(text); // Reject invalid escapes and escaped UTF-8.
    final publicText = text.startsWith('nostr:') ? text.substring(6) : text;
    if (publicText.toLowerCase().startsWith('nsec')) {
      return const Invalid(OpenQrReason.secretMaterial);
    }

    // Opaque protocol recognition does not interpret keys or SDK parameters.
    if (text.toLowerCase().startsWith('wc:')) {
      return const Legacy(LegacyProtocol.walletConnect);
    }
    if (text.toLowerCase().startsWith('skyzai-connect:')) {
      return const Legacy(LegacyProtocol.connect);
    }

    final rawUrl = RegExp(
      r'^[A-Za-z][A-Za-z0-9+.-]*://([^/?#]*)(/[^?#]*)?',
    ).firstMatch(text);
    if (rawUrl?.group(1)?.contains('@') ?? false) {
      return const Invalid(OpenQrReason.untrustedOrigin);
    }
    final rawPath = rawUrl?.group(2);
    if (rawPath != null) {
      for (final part in rawPath.split('/')) {
        final decoded = Uri.decodeComponent(part);
        if (decoded == '.' ||
            decoded == '..' ||
            decoded.contains('/') ||
            decoded.contains('\\') ||
            _controls.hasMatch(decoded) ||
            RegExp(r'%(?:2f|5c)', caseSensitive: false).hasMatch(decoded)) {
          return _malformed;
        }
      }
    }

    final uri = Uri.parse(text);
    if (uri.scheme == 'https' || uri.scheme == 'http') {
      final origin = Uri(scheme: uri.scheme, host: uri.host);
      if (uri.scheme != 'https' ||
          uri.authority.contains('@') ||
          uri.port != 443 ||
          !policy.acceptedOrigins.contains(origin)) {
        return const Invalid(OpenQrReason.untrustedOrigin);
      }
      return _decodeUri(
        uri,
        text,
        policy,
        origin == policy.canonicalOrigin
            ? OpenQrSource.canonical
            : OpenQrSource.compatible,
      );
    }
    if (uri.scheme == 'skyzai') {
      if (uri.authority.contains('@') || uri.hasPort || !uri.hasAuthority) {
        return _malformed;
      }
      if (uri.host == 'profile') {
        return _decodeUri(uri, text, policy, OpenQrSource.compatible);
      }
      final rejected = _queryError(uri);
      if (rejected != null) return rejected;
      return _legacy(text, policy);
    }
    if (publicText.toLowerCase().startsWith('npub')) {
      final identity = _identity(publicText, OpenQrIntent.profile);
      return identity == null
          ? _malformed
          : _recognized(identity, OpenQrSource.foreign, policy);
    }
    final address = text.startsWith('hedera:') ? text.substring(7) : text;
    if (_hedera.hasMatch(address)) {
      return _recognized(
        WalletAddressLink(
          address: address,
          chain: 'hedera',
          network: null,
          walletType: null,
        ),
        OpenQrSource.foreign,
        policy,
      );
    }
    return _legacy(text, policy);
  } on FormatException {
    return _malformed;
  } on ArgumentError {
    return _malformed;
  }
}

OpenQrDecode? _queryError(Uri uri) {
  final query = uri.queryParametersAll;
  final version = query['v'];
  if (version != null && (version.length != 1 || version.single != '1')) {
    return const Unsupported(OpenQrReason.unsupportedVersion);
  }
  if (uri.hasFragment || query.values.any((values) => values.length != 1)) {
    return _malformed;
  }
  return null;
}

OpenQrDecode _decodeUri(
  Uri uri,
  String text,
  OpenQrPolicy policy,
  OpenQrSource source,
) {
  final rejected = _queryError(uri);
  if (rejected != null) return rejected;
  final query = uri.queryParameters;
  final parts = uri.pathSegments.toList();
  if (parts.isNotEmpty && parts.first.toLowerCase().startsWith('npub')) {
    if (query.keys.any((key) => !policy.analyticsQueryKeys.contains(key))) {
      return _malformed;
    }
    if (parts.last.isEmpty) {
      parts.removeLast();
      source = OpenQrSource.compatible;
    }
    if (parts.length != 1 && parts.length != 2) return _malformed;
    if (parts.length == 2 && parts[1] != 'payment') return _malformed;
    final identity = _identity(
      parts.first,
      parts.length == 2 ? OpenQrIntent.pay : OpenQrIntent.profile,
    );
    if (identity == null) return _malformed;
    if (query.isNotEmpty) source = OpenQrSource.compatible;
    return _recognized(identity, source, policy);
  }
  if (uri.scheme == 'skyzai') return _unknown;
  final kind = parts.isEmpty
      ? null
      : switch (parts.first) {
          'pay' => OpenQrKind.payment,
          'request' => OpenQrKind.walletRequest,
          'booking' => OpenQrKind.bookingSession,
          'bookings' => OpenQrKind.booking,
          'verify' => OpenQrKind.ticket,
          'connect' => OpenQrKind.pairing,
          'wallet' => OpenQrKind.walletAddress,
          _ => null,
        };
  if (kind == null) return _legacy(text, policy);
  if (parts.length != 2 || parts[1].isEmpty) return _malformed;
  if (kind == OpenQrKind.walletAddress && !query.containsKey('v')) {
    return _legacy(text, policy);
  }
  final allowed = kind == OpenQrKind.walletAddress
      ? {'v', 'chain', 'network', 'type', 'asset'}
      : {'v'};
  if (query.keys.any((key) => !allowed.contains(key))) return _malformed;
  if (!query.containsKey('v')) source = OpenQrSource.compatible;
  final OpenQrLink link;
  if (kind == OpenQrKind.walletAddress) {
    if (!query.keys.toSet().containsAll({'chain', 'network', 'type'})) {
      return _malformed;
    }
    link = WalletAddressLink(
      address: parts[1],
      chain: query['chain']!,
      network: query['network'],
      walletType: query['type'],
      asset: query['asset'],
    );
  } else {
    if (!_reference.hasMatch(parts[1])) return _malformed;
    link = switch (kind) {
      OpenQrKind.payment => PaymentLink(parts[1]),
      OpenQrKind.walletRequest => WalletRequestLink(parts[1]),
      OpenQrKind.bookingSession => BookingSessionLink(parts[1]),
      OpenQrKind.booking => BookingLink(parts[1]),
      OpenQrKind.ticket => TicketLink(parts[1]),
      OpenQrKind.pairing => PairingLink(parts[1]),
      _ => throw StateError('Unexpected OpenQR kind'),
    };
  }
  final error = _linkError(link, policy);
  if (error != null) {
    return error == OpenQrReason.unsupportedWallet
        ? Unsupported(error)
        : Invalid(error);
  }
  return _recognized(link, source, policy);
}

OpenQrDecode _legacy(String text, OpenQrPolicy policy) {
  final result = policy.legacyAdapter?.call(text) ?? _unknown;
  if (result is Recognized) {
    return _recognized(result.link, OpenQrSource.compatible, policy);
  }
  return result;
}

OpenQrDecode _recognized(
  OpenQrLink link,
  OpenQrSource source,
  OpenQrPolicy policy,
) => policy.enabledKinds.contains(link.kind)
    ? Recognized(link, source)
    : const Unsupported(OpenQrReason.disabledKind);

IdentityLink? _identity(String npub, OpenQrIntent intent) {
  if (!RegExp(
    r'^npub1[023456789acdefghjklmnpqrstuvwxyz]{58}$',
  ).hasMatch(npub)) {
    return null;
  }
  try {
    final key = _bech32.decodeNpubKeyToPublicKey(npub);
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(key) ||
        _bech32.encodePublicKeyToNpub(key) != npub) {
      return null;
    }
    return IdentityLink(npub: npub, publicKeyHex: key, intent: intent);
  } catch (_) {
    return null;
  }
}

OpenQrReason? _linkError(OpenQrLink link, OpenQrPolicy policy) {
  switch (link) {
    case IdentityLink():
      if (_identity(link.npub, link.intent)?.publicKeyHex !=
          link.publicKeyHex) {
        return OpenQrReason.malformed;
      }
    case WalletAddressLink():
      final wallet = policy.wallets[link.chain];
      if (wallet == null ||
          !wallet.networks.contains(link.network) ||
          !wallet.walletTypes.contains(link.walletType) ||
          (link.asset != null && !wallet.assets.contains(link.asset))) {
        return OpenQrReason.unsupportedWallet;
      }
      if (!wallet.isValidAddress(link.address)) return OpenQrReason.malformed;
    default:
      final id = switch (link) {
        PaymentLink(:final paymentId) => paymentId,
        WalletRequestLink(:final requestId) => requestId,
        BookingSessionLink(:final sessionId) => sessionId,
        BookingLink(:final bookingId) => bookingId,
        TicketLink(:final ticketRef) => ticketRef,
        PairingLink(:final pairingId) => pairingId,
        _ => throw StateError('Unexpected OpenQR kind'),
      };
      if (!_reference.hasMatch(id)) return OpenQrReason.malformed;
  }
  return null;
}

Uri encode(OpenQrLink link, {required OpenQrPolicy policy}) {
  if (!policy.enabledKinds.contains(link.kind)) {
    throw const FormatException('Disabled OpenQR kind');
  }
  if (_linkError(link, policy) != null) {
    throw const FormatException('Invalid OpenQR target');
  }
  final parts = switch (link) {
    IdentityLink(:final npub, :final intent) => [
      npub,
      if (intent == OpenQrIntent.pay) 'payment',
    ],
    PaymentLink(:final paymentId) => ['pay', paymentId],
    WalletRequestLink(:final requestId) => ['request', requestId],
    BookingSessionLink(:final sessionId) => ['booking', sessionId],
    BookingLink(:final bookingId) => ['bookings', bookingId],
    TicketLink(:final ticketRef) => ['verify', ticketRef],
    PairingLink(:final pairingId) => ['connect', pairingId],
    WalletAddressLink(:final address) => ['wallet', address],
  };
  final query = link is IdentityLink
      ? null
      : {
          'v': '1',
          if (link is WalletAddressLink) ...{
            'chain': link.chain,
            'network': link.network!,
            'type': link.walletType!,
            if (link.asset != null) 'asset': link.asset!,
          },
        };
  final uri = Uri(
    scheme: 'https',
    host: policy.canonicalOrigin.host,
    pathSegments: parts,
    queryParameters: query,
  );
  if (utf8.encode(uri.toString()).length > 4096) {
    throw const FormatException('OpenQR target too long');
  }
  return uri;
}
