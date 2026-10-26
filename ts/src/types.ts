/** Public targets and safe results. Scanned text and legacy keys are never result fields. */
export type OpenQrLink =
  | {
      readonly kind: "identity";
      readonly npub: string;
      readonly publicKeyHex: string;
      readonly intent: "profile" | "pay";
    }
  | { readonly kind: "payment"; readonly paymentId: string }
  | { readonly kind: "walletRequest"; readonly requestId: string }
  | { readonly kind: "bookingSession"; readonly sessionId: string }
  | { readonly kind: "booking"; readonly bookingId: string }
  | { readonly kind: "ticket"; readonly ticketRef: string }
  | { readonly kind: "pairing"; readonly pairingId: string }
  | {
      readonly kind: "walletAddress";
      readonly address: string;
      readonly chain: string;
      readonly network: string | null;
      readonly walletType: string | null;
      readonly asset?: string;
    };

export type OpenQrKind = OpenQrLink["kind"];
export type OpenQrSource = "canonical" | "compatible" | "foreign";
export type OpenQrReason =
  | "malformed"
  | "untrustedOrigin"
  | "secretMaterial"
  | "unsupportedVersion"
  | "unknownKind"
  | "inputTooLong"
  | "disabledKind"
  | "unsupportedWallet";
export type LegacyProtocol =
  | "paymentScheme"
  | "walletUrl"
  | "walletJson"
  | "bookingJson"
  | "bookingId"
  | "ticketLegacy"
  | "walletConnect"
  | "connect";
export type OpenQrDecode =
  | {
      readonly status: "recognized";
      readonly link: OpenQrLink;
      readonly source: OpenQrSource;
    }
  | { readonly status: "legacy"; readonly protocol: LegacyProtocol }
  | { readonly status: "invalid"; readonly reason: OpenQrReason }
  | { readonly status: "unsupported"; readonly reason: OpenQrReason };
