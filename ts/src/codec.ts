/** Strict v1 codec. Validate raw syntax before URL can normalize forbidden paths. */
import { decode as decodeNip19, npubEncode } from "nostr-tools/nip19";
import type { OpenQrPolicy } from "./policy.js";
import type {
  OpenQrDecode,
  OpenQrLink,
  OpenQrReason,
  OpenQrSource,
} from "./types.js";

const reference = /^[A-Za-z0-9_-]{1,128}$/;
const hedera = /^0\.0\.[0-9]+(?:-[a-z]{5})?$/;
const controls = /[\x00-\x1f\x7f-\x9f]/;
const utf8 = new TextEncoder();
const malformed = { status: "invalid", reason: "malformed" } as const;
const unknown = { status: "unsupported", reason: "unknownKind" } as const;

export function decode(raw: string, policy: OpenQrPolicy): OpenQrDecode {
  const bytes = utf8.encode(raw);
  if (bytes.length > 4096) return { status: "invalid", reason: "inputTooLong" };
  if (new TextDecoder().decode(bytes) !== raw) return malformed;
  const text = raw.trim();
  if (!text || controls.test(text)) return malformed;
  try {
    if (text.startsWith("{")) return legacy(text, policy);
    if (text.includes("\\")) return malformed;
    decodeURIComponent(text); // Reject malformed escapes and escaped UTF-8.
    const publicText = text.startsWith("nostr:") ? text.slice(6) : text;
    if (publicText.toLowerCase().startsWith("nsec")) {
      return { status: "invalid", reason: "secretMaterial" };
    }
    if (text.toLowerCase().startsWith("wc:"))
      return { status: "legacy", protocol: "walletConnect" };
    if (text.toLowerCase().startsWith("skyzai-connect:"))
      return { status: "legacy", protocol: "connect" };

    const rawUrl = /^[A-Za-z][A-Za-z0-9+.-]*:\/\/([^/?#]*)(\/[^?#]*)?/.exec(
      text,
    );
    if (rawUrl?.[1].includes("@"))
      return { status: "invalid", reason: "untrustedOrigin" };
    for (const part of (rawUrl?.[2] ?? "").split("/")) {
      const decoded = decodeURIComponent(part);
      if (
        decoded === "." ||
        decoded === ".." ||
        /[/\\]/.test(decoded) ||
        controls.test(decoded) ||
        /%(?:2f|5c)/i.test(decoded)
      )
        return malformed;
    }

    const uri = /^[A-Za-z][A-Za-z0-9+.-]*:/.test(text) ? new URL(text) : null;
    if (uri?.protocol === "https:" || uri?.protocol === "http:") {
      if (
        !rawUrl ||
        uri.protocol !== "https:" ||
        uri.port ||
        !policy.acceptedOrigins.includes(uri.origin)
      ) {
        return { status: "invalid", reason: "untrustedOrigin" };
      }
      return decodeUri(
        uri,
        text,
        policy,
        uri.origin === policy.canonicalOrigin ? "canonical" : "compatible",
      );
    }
    if (uri?.protocol === "skyzai:") {
      if (!rawUrl || uri.port) return malformed;
      if (uri.hostname === "profile")
        return decodeUri(uri, text, policy, "compatible");
      return queryError(uri, text) ?? legacy(text, policy);
    }
    if (publicText.toLowerCase().startsWith("npub")) {
      const link = identity(publicText, "profile");
      return link ? recognized(link, "foreign", policy) : malformed;
    }
    const address = text.startsWith("hedera:") ? text.slice(7) : text;
    if (hedera.test(address)) {
      return recognized(
        {
          kind: "walletAddress",
          address,
          chain: "hedera",
          network: null,
          walletType: null,
        },
        "foreign",
        policy,
      );
    }
    return legacy(text, policy);
  } catch (error) {
    if (
      error instanceof URIError ||
      error instanceof TypeError ||
      error instanceof SyntaxError
    )
      return malformed;
    throw error;
  }
}

function queryError(uri: URL, text: string): OpenQrDecode | null {
  const query = uri.searchParams;
  const versions = query.getAll("v");
  if (versions.length && (versions.length !== 1 || versions[0] !== "1")) {
    return { status: "unsupported", reason: "unsupportedVersion" };
  }
  if (
    text.includes("#") ||
    [...query.keys()].some((key) => query.getAll(key).length !== 1)
  )
    return malformed;
  return null;
}

function decodeUri(
  uri: URL,
  text: string,
  policy: OpenQrPolicy,
  source: OpenQrSource,
): OpenQrDecode {
  const rejected = queryError(uri, text);
  if (rejected) return rejected;
  const query = uri.searchParams;
  const parts = uri.pathname.slice(1).split("/").map(decodeURIComponent);
  if (parts[0].toLowerCase().startsWith("npub")) {
    if (
      [...query.keys()].some((key) => !policy.analyticsQueryKeys.includes(key))
    )
      return malformed;
    if (parts.at(-1) === "") {
      parts.pop();
      source = "compatible";
    }
    if (
      (parts.length !== 1 && parts.length !== 2) ||
      (parts.length === 2 && parts[1] !== "payment")
    )
      return malformed;
    const link = identity(parts[0], parts.length === 2 ? "pay" : "profile");
    if (!link) return malformed;
    return recognized(link, query.size ? "compatible" : source, policy);
  }
  if (uri.protocol === "skyzai:") return unknown;
  let link: OpenQrLink;
  const id = parts[1];
  switch (parts[0]) {
    case "pay":
      link = { kind: "payment", paymentId: id };
      break;
    case "request":
      link = { kind: "walletRequest", requestId: id };
      break;
    case "booking":
      link = { kind: "bookingSession", sessionId: id };
      break;
    case "bookings":
      link = { kind: "booking", bookingId: id };
      break;
    case "verify":
      link = { kind: "ticket", ticketRef: id };
      break;
    case "connect":
      link = { kind: "pairing", pairingId: id };
      break;
    case "wallet":
      link = {
        kind: "walletAddress",
        address: id,
        chain: query.get("chain") ?? "",
        network: query.get("network"),
        walletType: query.get("type"),
        ...(query.has("asset") ? { asset: query.get("asset")! } : {}),
      };
      break;
    default:
      return legacy(text, policy);
  }
  if (parts.length !== 2 || !id) return malformed;
  if (link.kind === "walletAddress" && !query.has("v"))
    return legacy(text, policy);
  const allowed =
    link.kind === "walletAddress"
      ? ["v", "chain", "network", "type", "asset"]
      : ["v"];
  if ([...query.keys()].some((key) => !allowed.includes(key))) return malformed;
  if (
    link.kind === "walletAddress" &&
    ["chain", "network", "type"].some((key) => !query.has(key))
  )
    return malformed;
  const error = linkError(link, policy);
  if (error)
    return {
      status: error === "unsupportedWallet" ? "unsupported" : "invalid",
      reason: error,
    };
  return recognized(link, query.has("v") ? source : "compatible", policy);
}

function legacy(text: string, policy: OpenQrPolicy): OpenQrDecode {
  const result = policy.legacyAdapter?.(text) ?? unknown;
  return result.status === "recognized"
    ? recognized(result.link, "compatible", policy)
    : result;
}

function recognized(
  link: OpenQrLink,
  source: OpenQrSource,
  policy: OpenQrPolicy,
): OpenQrDecode {
  return policy.enabledKinds.includes(link.kind)
    ? { status: "recognized", link, source }
    : { status: "unsupported", reason: "disabledKind" };
}

function identity(
  npub: string,
  intent: "profile" | "pay",
): Extract<OpenQrLink, { kind: "identity" }> | null {
  if (!/^npub1[023456789acdefghjklmnpqrstuvwxyz]{58}$/.test(npub)) return null;
  try {
    const decoded = decodeNip19(npub);
    if (
      decoded.type !== "npub" ||
      !/^[a-f0-9]{64}$/.test(decoded.data) ||
      npubEncode(decoded.data) !== npub
    )
      return null;
    return { kind: "identity", npub, publicKeyHex: decoded.data, intent };
  } catch {
    return null;
  }
}

function segments(link: OpenQrLink): string[] {
  switch (link.kind) {
    case "identity":
      return link.intent === "pay" ? [link.npub, "payment"] : [link.npub];
    case "payment":
      return ["pay", link.paymentId];
    case "walletRequest":
      return ["request", link.requestId];
    case "bookingSession":
      return ["booking", link.sessionId];
    case "booking":
      return ["bookings", link.bookingId];
    case "ticket":
      return ["verify", link.ticketRef];
    case "pairing":
      return ["connect", link.pairingId];
    case "walletAddress":
      return ["wallet", link.address];
  }
}

function linkError(
  link: OpenQrLink,
  policy: OpenQrPolicy,
): OpenQrReason | null {
  if (link.kind === "identity") {
    const decoded = identity(link.npub, link.intent);
    if (
      !["profile", "pay"].includes(link.intent) ||
      !decoded ||
      decoded.publicKeyHex !== link.publicKeyHex
    )
      return "malformed";
  } else if (link.kind === "walletAddress") {
    const wallet = Object.hasOwn(policy.wallets, link.chain)
      ? policy.wallets[link.chain]
      : undefined;
    if (
      !wallet ||
      link.network === null ||
      !wallet.networks.includes(link.network) ||
      link.walletType === null ||
      !wallet.walletTypes.includes(link.walletType) ||
      (link.asset !== undefined && !wallet.assets?.includes(link.asset))
    )
      return "unsupportedWallet";
    if (!wallet.isValidAddress(link.address)) return "malformed";
  } else {
    const id = segments(link)[1];
    if (typeof id !== "string" || !reference.test(id)) return "malformed";
  }
  return null;
}

export function encode(link: OpenQrLink, policy: OpenQrPolicy): string {
  if (!policy.enabledKinds.includes(link.kind))
    throw new TypeError("Disabled OpenQR kind");
  if (linkError(link, policy)) throw new TypeError("Invalid OpenQR target");
  const uri = new URL(policy.canonicalOrigin);
  uri.pathname = "/" + segments(link).map(encodeURIComponent).join("/");
  if (link.kind !== "identity") uri.searchParams.set("v", "1");
  if (link.kind === "walletAddress") {
    uri.searchParams.set("chain", link.chain);
    uri.searchParams.set("network", link.network!);
    uri.searchParams.set("type", link.walletType!);
    if (link.asset !== undefined) uri.searchParams.set("asset", link.asset);
  }
  const result = uri.href;
  if (utf8.encode(result).length > 4096)
    throw new TypeError("OpenQR target too long");
  return result;
}
