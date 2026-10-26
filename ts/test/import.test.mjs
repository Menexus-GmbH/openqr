/** Import the actual ESM exports without DOM, Node globals or usable network APIs. */
import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import test from "node:test";
import { fixture } from "./fixture-host.mjs";

test("browser-condition and Node imports need no host initialization", () => {
  const { records, verifyCases } = fixture("records");
  const expected = verifyCases.find((c) => c.record === "newer").expected;
  const script = `
    import assert from 'node:assert/strict';
    for (const key of ['window', 'document', 'navigator']) {
      Object.defineProperty(globalThis, key, { configurable: true, get() { throw new Error('DOM required'); } });
    }
    globalThis.fetch = () => { throw new Error('Unexpected network request'); };
    globalThis.WebSocket = class { constructor() { throw new Error('Unexpected socket'); } };
    globalThis.process = undefined;
    globalThis.Buffer = undefined;
    const api = await import('@menexus-gmbh/openqr');
    const policy = new api.OpenQrPolicy();
    const link = { kind: 'ticket', ticketRef: 'ticket_01' };
    const encoded = api.encode(link, policy);
    assert.deepEqual(api.decode(encoded, policy).link, link);
    assert.equal(api.isVerifiedNostrRecord(${JSON.stringify(records.newer)}, ${JSON.stringify(expected)}), true);
    for (const forbidden of ['finalizeEvent', 'generateSecretKey', 'nsecEncode', 'Relay', 'SimplePool']) {
      assert.equal(forbidden in api, false);
    }
  `;
  for (const conditions of [[], ["--conditions=browser"]]) {
    assert.equal(
      execFileSync(
        process.execPath,
        [...conditions, "--input-type=module", "-e", script],
        {
          cwd: new URL("..", import.meta.url),
          encoding: "utf8",
          timeout: 10000,
        },
      ),
      "",
    );
  }
});
