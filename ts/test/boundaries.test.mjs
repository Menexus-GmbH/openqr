/** Host trust, bounded immutable results, and verification-cache regression checks. */
import assert from "node:assert/strict";
import test from "node:test";
import { getEventHash, verifiedSymbol } from "nostr-tools/pure";
import {
  OpenQrPolicy,
  decode,
  encode,
  isVerifiedNostrRecord,
  newestVerifiedRecord,
  maxRecordContentBytes,
  maxRecordCount,
} from "@menexus-gmbh/openqr";
import { fixture } from "./fixture-host.mjs";

test("configuration accepts exact HTTPS origins and snapshots host vocabulary", () => {
  for (const canonicalOrigin of [
    "http://skyzai.com",
    "https://*.example",
    "https://user@skyzai.com",
    "https://@skyzai.com",
    "https://skyzai.com:444",
    "https://skyzai.com/path",
    "https://skyzai.com?redirect=1",
  ]) {
    assert.throws(() => new OpenQrPolicy({ canonicalOrigin }));
  }
  const enabledKinds = ["ticket"];
  const networks = ["mainnet"];
  const policy = new OpenQrPolicy({
    enabledKinds,
    wallets: {
      hedera: { networks, walletTypes: ["wallet"], isValidAddress: () => true },
    },
  });
  enabledKinds.length = networks.length = 0;
  assert.deepEqual(policy.enabledKinds, ["ticket"]);
  assert.deepEqual(policy.wallets.hedera.networks, ["mainnet"]);
  assert.throws(() => policy.enabledKinds.push("pairing"));
  assert.throws(() => policy.wallets.hedera.networks.push("untrusted"));
});

test("rejected known links cannot fall through to a permissive legacy parser", () => {
  let calls = 0;
  const policy = new OpenQrPolicy({
    legacyAdapter() {
      calls++;
      return { status: "legacy", protocol: "ticketLegacy" };
    },
  });
  for (const raw of [
    "https://evil.example/pay/id",
    "https://@skyzai.com/pay/id",
    "https://skyzai.com/wallet/id?v=2",
    "https://skyzai.com/ignored/../pay/id?v=1",
    "https://skyzai.com/pay/id?v=1&redirect=evil",
    "https://skyzai.com/pay/id?v=1#extra",
  ]) {
    assert.notEqual(decode(raw, policy).status, "legacy");
  }
  assert.equal(calls, 0);
  assert.equal(decode("old-host-code", policy).status, "legacy");
  assert.equal(calls, 1);
});

test("malformed UTF-16 and empty fragment markers are safely refused", () => {
  const policy = new OpenQrPolicy();
  for (const raw of ["\ud800", "https://skyzai.com/pay/id?v=1#"])
    assert.deepEqual(decode(raw, policy), {
      status: "invalid",
      reason: "malformed",
    });
});

test("JavaScript callers cannot encode missing or coerced reference fields", () => {
  const policy = new OpenQrPolicy();
  for (const paymentId of [undefined, null, 123, {}])
    assert.throws(() => encode({ kind: "payment", paymentId }, policy));
});

const { records } = fixture("records");
const original = records.newer;
const expected = {
  kind: original.kind,
  publicKeyHex: original.pubkey,
  dTag: "openqr-fixture",
};
test("record bounds fail safely and selection returns immutable public fields", () => {
  assert.equal(
    isVerifiedNostrRecord(
      { ...original, content: "a".repeat(maxRecordContentBytes + 1) },
      expected,
    ),
    false,
  );
  assert.throws(
    () => newestVerifiedRecord(Array(maxRecordCount + 1).fill(null), expected),
    /batch too large/,
  );
  const selected = newestVerifiedRecord(
    [{ ...original, untrustedExtra: "ignored" }],
    expected,
  );
  assert.deepEqual(selected, original);
  assert.throws(() => selected.tags.push(["d", "other"]));
  assert.throws(() => selected.tags[0].push("other"));
});

test("caller-supplied nostr-tools verification cache cannot bypass signatures", () => {
  const forged = { ...original, content: "forged" };
  forged.id = getEventHash(forged);
  forged[verifiedSymbol] = true;
  assert.equal(isVerifiedNostrRecord(forged, expected), false);
  assert.equal(isVerifiedNostrRecord(original, expected), true);
  assert.equal(Object.hasOwn(original, verifiedSymbol), false);
  const mutated = { ...original, content: "modified after verification" };
  assert.equal(isVerifiedNostrRecord(mutated, expected), false);
});
