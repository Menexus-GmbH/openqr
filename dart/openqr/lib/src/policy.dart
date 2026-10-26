/// Explicit host trust, wallet vocabulary and optional legacy adapter.
/// Wallet validators and legacy parsers belong to the host, never scanned data.
library;

import 'types.dart';

typedef OpenQrLegacyAdapter = OpenQrDecode? Function(String raw);

final class OpenQrWalletPolicy {
  OpenQrWalletPolicy({
    required Set<String> networks,
    required Set<String> walletTypes,
    required this.isValidAddress,
    Set<String> assets = const {},
  }) : networks = Set.unmodifiable(networks),
       walletTypes = Set.unmodifiable(walletTypes),
       assets = Set.unmodifiable(assets);
  final Set<String> networks;
  final Set<String> walletTypes;
  final Set<String> assets;
  final bool Function(String address) isValidAddress;
}

final class OpenQrPolicy {
  OpenQrPolicy({
    String canonicalOrigin = 'https://skyzai.com',
    Set<String>? acceptedOrigins,
    Set<OpenQrKind> enabledKinds = const {
      OpenQrKind.identity,
      OpenQrKind.payment,
      OpenQrKind.bookingSession,
      OpenQrKind.booking,
      OpenQrKind.ticket,
      OpenQrKind.walletAddress,
    },
    Set<String> analyticsQueryKeys = const {
      'utm_source',
      'utm_medium',
      'utm_campaign',
    },
    Map<String, OpenQrWalletPolicy> wallets = const {},
    this.legacyAdapter,
  }) : canonicalOrigin = _origin(canonicalOrigin),
       acceptedOrigins = Set.unmodifiable({
         _origin(canonicalOrigin),
         ...?acceptedOrigins?.map(_origin),
       }),
       enabledKinds = Set.unmodifiable(enabledKinds),
       analyticsQueryKeys = Set.unmodifiable(analyticsQueryKeys),
       wallets = Map.unmodifiable(wallets);

  final Uri canonicalOrigin;
  final Set<Uri> acceptedOrigins;
  final Set<OpenQrKind> enabledKinds;
  final Set<String> analyticsQueryKeys;
  final Map<String, OpenQrWalletPolicy> wallets;
  final OpenQrLegacyAdapter? legacyAdapter;

  static Uri _origin(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.host.contains('*') ||
        value.contains('@') ||
        uri.port != 443 ||
        (uri.path.isNotEmpty && uri.path != '/') ||
        uri.hasQuery ||
        uri.hasFragment ||
        !value.startsWith('https://') ||
        value.contains('\\')) {
      throw const FormatException('Invalid OpenQR origin');
    }
    return Uri(scheme: 'https', host: uri.host);
  }
}
