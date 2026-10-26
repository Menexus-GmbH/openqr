/** Synthetic host adapters for shared fixtures, never production legacy parsers. */
import { readFileSync } from "node:fs";
import { OpenQrPolicy } from "@menexus-gmbh/openqr";

export function fixture(name) {
  return JSON.parse(
    readFileSync(
      new URL(`../../fixtures/${name}.json`, import.meta.url),
      "utf8",
    ),
  );
}

export function policyFromJson(json) {
  const legacy = new Set(json.legacyProtocols);
  return new OpenQrPolicy({
    ...json,
    wallets: Object.fromEntries(
      Object.entries(json.wallets).map(([chain, wallet]) => [
        chain,
        {
          ...wallet,
          isValidAddress: (address) =>
            chain === "hedera"
              ? /^0\.0\.[0-9]+(?:-[a-z]{5})?$/.test(address)
              : chain === "ethereum" && /^0x[0-9a-fA-F]{40}$/.test(address),
        },
      ]),
    ),
    legacyAdapter(raw) {
      if (raw.startsWith("{")) {
        const data = JSON.parse(raw);
        if (data && typeof data === "object" && !Array.isArray(data)) {
          if (
            legacy.has("walletJson") &&
            typeof data.walletAddress === "string" &&
            ("value" in data || "token" in data)
          )
            return { status: "legacy", protocol: "walletJson" };
          if (legacy.has("bookingJson") && typeof data.bookingId === "string")
            return { status: "legacy", protocol: "bookingJson" };
        }
        return null;
      }
      if (!/^[A-Za-z][A-Za-z0-9+.-]*:/.test(raw)) return null;
      const uri = new URL(raw);
      if (
        legacy.has("paymentScheme") &&
        uri.protocol === "skyzai:" &&
        uri.hostname === "pay" &&
        !uri.pathname &&
        uri.searchParams.size === 1 &&
        /^[A-Za-z0-9_-]{1,128}$/.test(uri.searchParams.get("id") ?? "")
      ) {
        return {
          status: "recognized",
          source: "compatible",
          link: { kind: "payment", paymentId: uri.searchParams.get("id") },
        };
      }
      const parts = uri.pathname.slice(1).split("/");
      if (uri.protocol !== "https:") return null;
      if (
        legacy.has("walletUrl") &&
        parts.length === 2 &&
        parts[0] === "wallet" &&
        !uri.searchParams.has("v")
      )
        return { status: "legacy", protocol: "walletUrl" };
      if (
        legacy.has("ticketLegacy") &&
        parts.length === 3 &&
        parts[0] === "events"
      )
        return { status: "legacy", protocol: "ticketLegacy" };
      return null;
    },
  });
}
