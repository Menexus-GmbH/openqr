/** Runs every shared vector directly; expected values never come from the implementation. */
import assert from "node:assert/strict";
import test from "node:test";
import {
  decode,
  encode,
  isVerifiedNostrRecord,
  newestVerifiedRecord,
} from "@menexus-gmbh/openqr";
import { fixture, policyFromJson } from "./fixture-host.mjs";

const links = fixture("links");
const policies = Object.fromEntries(
  Object.entries(links.policies).map(([name, json]) => [
    name,
    policyFromJson(json),
  ]),
);
for (const c of links.decodeCases) {
  test(`shared decode: ${c.id}`, () => {
    const policy = policies[c.policy];
    const result = decode(c.raw, policy);
    assert.deepEqual(result, c.expected);
    if (c.canonicalUrl) {
      const encoded = encode(result.link, policy);
      assert.equal(encoded, c.canonicalUrl);
      assert.deepEqual(decode(encoded, policy), {
        status: "recognized",
        source: "canonical",
        link: result.link,
      });
    }
  });
}
for (const c of links.encodeRejectCases) {
  test(`shared encode refusal: ${c.id}`, () =>
    assert.throws(() => encode(c.link, policies[c.policy])));
}
const records = fixture("records");
for (const c of records.verifyCases) {
  test(`shared verification: ${c.id}`, () =>
    assert.equal(
      isVerifiedNostrRecord(records.records[c.record], c.expected),
      c.verified,
    ));
}
for (const c of records.selectionCases) {
  test(`shared selection: ${c.id}`, () => {
    const selected = newestVerifiedRecord(
      c.records.map((name) => records.records[name]),
      c.expected,
    );
    assert.deepEqual(
      selected,
      c.selected === null ? null : records.records[c.selected],
    );
  });
}
