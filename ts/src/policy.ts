/** Explicit host trust, wallet vocabulary and optional host-owned legacy parsing. */
import type { OpenQrDecode, OpenQrKind } from "./types.js";

export type OpenQrLegacyAdapter = (raw: string) => OpenQrDecode | null;
export interface OpenQrWalletPolicy {
  readonly networks: readonly string[];
  readonly walletTypes: readonly string[];
  readonly assets?: readonly string[];
  readonly isValidAddress: (address: string) => boolean;
}
export interface OpenQrPolicyOptions {
  readonly canonicalOrigin?: string;
  readonly acceptedOrigins?: readonly string[];
  readonly enabledKinds?: readonly OpenQrKind[];
  readonly analyticsQueryKeys?: readonly string[];
  readonly wallets?: Readonly<Record<string, OpenQrWalletPolicy>>;
  readonly legacyAdapter?: OpenQrLegacyAdapter;
}

function origin(value: string): string {
  try {
    if (!/^https:\/\/[^/?#@\\\s*]+\/?$/.test(value)) throw new Error();
    const uri = new URL(value);
    if (!uri.hostname || uri.port || uri.pathname !== "/") throw new Error();
    return uri.origin;
  } catch {
    throw new TypeError("Invalid OpenQR origin");
  }
}

export class OpenQrPolicy {
  readonly canonicalOrigin: string;
  readonly acceptedOrigins: readonly string[];
  readonly enabledKinds: readonly OpenQrKind[];
  readonly analyticsQueryKeys: readonly string[];
  readonly wallets: Readonly<Record<string, OpenQrWalletPolicy>>;
  readonly legacyAdapter: OpenQrLegacyAdapter | undefined;

  constructor(options: OpenQrPolicyOptions = {}) {
    this.canonicalOrigin = origin(
      options.canonicalOrigin ?? "https://skyzai.com",
    );
    this.acceptedOrigins = Object.freeze([
      ...new Set([
        this.canonicalOrigin,
        ...(options.acceptedOrigins ?? []).map(origin),
      ]),
    ]);
    this.enabledKinds = Object.freeze([
      ...(options.enabledKinds ?? [
        "identity",
        "payment",
        "bookingSession",
        "booking",
        "ticket",
        "walletAddress",
      ]),
    ]);
    this.analyticsQueryKeys = Object.freeze([
      ...(options.analyticsQueryKeys ?? [
        "utm_source",
        "utm_medium",
        "utm_campaign",
      ]),
    ]);
    this.wallets = Object.freeze(
      Object.fromEntries(
        Object.entries(options.wallets ?? {}).map(([chain, wallet]) => [
          chain,
          Object.freeze({
            networks: Object.freeze([...wallet.networks]),
            walletTypes: Object.freeze([...wallet.walletTypes]),
            assets: Object.freeze([...(wallet.assets ?? [])]),
            isValidAddress: wallet.isValidAddress,
          }),
        ]),
      ),
    );
    this.legacyAdapter = options.legacyAdapter;
    Object.freeze(this);
  }
}
