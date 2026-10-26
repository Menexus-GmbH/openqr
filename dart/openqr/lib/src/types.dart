/// Typed public targets and safe classifier results.
/// No result stores scanned text, credentials or opaque legacy payloads.
library;

enum OpenQrKind {
  identity,
  payment,
  walletRequest,
  bookingSession,
  booking,
  ticket,
  pairing,
  walletAddress,
}

enum OpenQrIntent { profile, pay }

enum OpenQrSource { canonical, compatible, foreign }

enum OpenQrReason {
  malformed,
  untrustedOrigin,
  secretMaterial,
  unsupportedVersion,
  unknownKind,
  inputTooLong,
  disabledKind,
  unsupportedWallet,
}

enum LegacyProtocol {
  paymentScheme,
  walletUrl,
  walletJson,
  bookingJson,
  bookingId,
  ticketLegacy,
  walletConnect,
  connect,
}

sealed class OpenQrLink {
  const OpenQrLink();
  OpenQrKind get kind;

  Map<String, Object?> toJson() => {
    'kind': kind.name,
    ...switch (this) {
      IdentityLink(:final npub, :final publicKeyHex, :final intent) => {
        'npub': npub,
        'publicKeyHex': publicKeyHex,
        'intent': intent.name,
      },
      PaymentLink(:final paymentId) => {'paymentId': paymentId},
      WalletRequestLink(:final requestId) => {'requestId': requestId},
      BookingSessionLink(:final sessionId) => {'sessionId': sessionId},
      BookingLink(:final bookingId) => {'bookingId': bookingId},
      TicketLink(:final ticketRef) => {'ticketRef': ticketRef},
      PairingLink(:final pairingId) => {'pairingId': pairingId},
      WalletAddressLink(
        :final address,
        :final chain,
        :final network,
        :final walletType,
        :final asset,
      ) =>
        {
          'address': address,
          'chain': chain,
          'network': network,
          'walletType': walletType,
          'asset': ?asset,
        },
    },
  };
}

final class IdentityLink extends OpenQrLink {
  const IdentityLink({
    required this.npub,
    required this.publicKeyHex,
    this.intent = OpenQrIntent.profile,
  });
  final String npub;
  final String publicKeyHex;
  final OpenQrIntent intent;
  @override
  OpenQrKind get kind => OpenQrKind.identity;
}

final class PaymentLink extends OpenQrLink {
  const PaymentLink(this.paymentId);
  final String paymentId;
  @override
  OpenQrKind get kind => OpenQrKind.payment;
}

final class WalletRequestLink extends OpenQrLink {
  const WalletRequestLink(this.requestId);
  final String requestId;
  @override
  OpenQrKind get kind => OpenQrKind.walletRequest;
}

final class BookingSessionLink extends OpenQrLink {
  const BookingSessionLink(this.sessionId);
  final String sessionId;
  @override
  OpenQrKind get kind => OpenQrKind.bookingSession;
}

final class BookingLink extends OpenQrLink {
  const BookingLink(this.bookingId);
  final String bookingId;
  @override
  OpenQrKind get kind => OpenQrKind.booking;
}

final class TicketLink extends OpenQrLink {
  const TicketLink(this.ticketRef);
  final String ticketRef;
  @override
  OpenQrKind get kind => OpenQrKind.ticket;
}

final class PairingLink extends OpenQrLink {
  const PairingLink(this.pairingId);
  final String pairingId;
  @override
  OpenQrKind get kind => OpenQrKind.pairing;
}

final class WalletAddressLink extends OpenQrLink {
  const WalletAddressLink({
    required this.address,
    required this.chain,
    required this.network,
    required this.walletType,
    this.asset,
  });
  final String address;
  final String chain;
  final String? network;
  final String? walletType;
  final String? asset;
  @override
  OpenQrKind get kind => OpenQrKind.walletAddress;
}

sealed class OpenQrDecode {
  const OpenQrDecode();
  Map<String, Object?> toJson() => switch (this) {
    Recognized(:final link, :final source) => {
      'status': 'recognized',
      'source': source.name,
      'link': link.toJson(),
    },
    Legacy(:final protocol) => {'status': 'legacy', 'protocol': protocol.name},
    Invalid(:final reason) => {'status': 'invalid', 'reason': reason.name},
    Unsupported(:final reason) => {
      'status': 'unsupported',
      'reason': reason.name,
    },
  };
}

final class Recognized extends OpenQrDecode {
  const Recognized(this.link, this.source);
  final OpenQrLink link;
  final OpenQrSource source;
}

final class Legacy extends OpenQrDecode {
  const Legacy(this.protocol);
  final LegacyProtocol protocol;
}

final class Invalid extends OpenQrDecode {
  const Invalid(this.reason);
  final OpenQrReason reason;
}

final class Unsupported extends OpenQrDecode {
  const Unsupported(this.reason);
  final OpenQrReason reason;
}
