/** Verify public envelopes before content parsing, preserving the reviewed replacement order. */
import { getEventHash, verifyEvent } from "nostr-tools/pure";

export interface NostrRecord {
  readonly id: string;
  readonly pubkey: string;
  readonly created_at: number;
  readonly kind: number;
  readonly tags: readonly (readonly string[])[];
  readonly content: string;
  readonly sig: string;
}
export interface OpenQrExpectedRecord {
  readonly kind: number;
  readonly publicKeyHex: string;
  readonly dTag: string;
}
export const maxRecordContentBytes = 64 * 1024;
export const maxRecordCount = 100;
const hex32 = /^[a-f0-9]{64}$/;
const hex64 = /^[a-f0-9]{128}$/;

function parseRecord(value: unknown) {
  if (!value || typeof value !== "object" || Array.isArray(value)) return null;
  const { id, pubkey, created_at, kind, tags, content, sig } = value as Record<
    string,
    unknown
  >;
  if (
    typeof id !== "string" ||
    !hex32.test(id) ||
    typeof pubkey !== "string" ||
    !hex32.test(pubkey) ||
    typeof created_at !== "number" ||
    !Number.isInteger(created_at) ||
    created_at < 0 ||
    created_at > 8640000000000 ||
    typeof kind !== "number" ||
    !Number.isInteger(kind) ||
    kind < 0 ||
    kind > 65535 ||
    !Array.isArray(tags) ||
    !tags.every(
      (tag) => Array.isArray(tag) && tag.every((v) => typeof v === "string"),
    ) ||
    typeof content !== "string" ||
    new TextEncoder().encode(content).length > maxRecordContentBytes ||
    typeof sig !== "string" ||
    !hex64.test(sig)
  )
    return null;
  // Copy only envelope fields so a caller cannot supply nostr-tools' cached verification symbol.
  return {
    id,
    pubkey,
    created_at,
    kind,
    tags: tags.map((tag) => [...tag] as string[]),
    content,
    sig,
  };
}

function verifiedRecord(event: unknown, expected: OpenQrExpectedRecord) {
  try {
    const record = parseRecord(event);
    return record &&
      record.kind === expected.kind &&
      record.pubkey === expected.publicKeyHex &&
      record.tags.some(
        (tag) => tag.length >= 2 && tag[0] === "d" && tag[1] === expected.dTag,
      ) &&
      getEventHash(record) === record.id &&
      verifyEvent(record)
      ? record
      : null;
  } catch {
    return null;
  }
}

export function isVerifiedNostrRecord(
  event: unknown,
  expected: OpenQrExpectedRecord,
): event is NostrRecord {
  return verifiedRecord(event, expected) !== null;
}

export function compareNostrRecords(a: NostrRecord, b: NostrRecord): number {
  return (
    b.created_at - a.created_at || (a.id < b.id ? -1 : a.id > b.id ? 1 : 0)
  );
}

/** Whole-batch limits fail rather than selecting from a truncated replacement history. */
export function newestVerifiedRecord(
  events: readonly unknown[],
  expected: OpenQrExpectedRecord,
): NostrRecord | null {
  if (events.length > maxRecordCount)
    throw new RangeError("OpenQR record batch too large");
  let newest: NostrRecord | null = null;
  for (const event of events) {
    const record = verifiedRecord(event, expected);
    if (record && (!newest || compareNostrRecords(record, newest) < 0)) {
      newest = Object.freeze({
        id: record.id,
        pubkey: record.pubkey,
        created_at: record.created_at,
        kind: record.kind,
        tags: Object.freeze(record.tags.map((tag) => Object.freeze(tag))),
        content: record.content,
        sig: record.sig,
      });
    }
  }
  return newest;
}
