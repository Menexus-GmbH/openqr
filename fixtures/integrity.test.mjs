// Checks the shared test data without implementing a codec or signature verifier.
// Package suites consume the same JSON and establish actual conformance.
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { readFileSync } from 'node:fs';
import test from 'node:test';

const read = (name) =>
  JSON.parse(readFileSync(new URL(name, import.meta.url), 'utf8'));
const links = read('links.json');
const records = read('records.json');
const linkFields = {
  identity: ['npub', 'publicKeyHex', 'intent'],
  payment: ['paymentId'],
  walletRequest: ['requestId'],
  bookingSession: ['sessionId'],
  booking: ['bookingId'],
  ticket: ['ticketRef'],
  pairing: ['pairingId'],
  walletAddress: ['address', 'chain', 'network', 'walletType'],
};
const reasons = new Set([
  'malformed', 'untrustedOrigin', 'secretMaterial', 'unsupportedVersion',
  'unknownKind', 'inputTooLong', 'disabledKind', 'unsupportedWallet',
]);

function uniqueIds(cases) {
  assert.ok(cases.length > 0);
  assert.equal(new Set(cases.map((c) => c.id)).size, cases.length);
  for (const c of cases) assert.match(c.id, /^[a-zA-Z0-9-]+$/);
}

function eventHash(event) {
  const serialized = JSON.stringify([
    0, event.pubkey, event.created_at, event.kind, event.tags, event.content,
  ]);
  return createHash('sha256').update(serialized, 'utf8').digest('hex');
}

test('fixture versions, case IDs and policy references are valid', () => {
  assert.equal(links.schemaVersion, 1);
  assert.equal(records.schemaVersion, 1);
  for (const cases of [
    links.decodeCases, links.encodeRejectCases,
    records.verifyCases, records.selectionCases,
  ]) uniqueIds(cases);
  for (const c of [...links.decodeCases, ...links.encodeRejectCases]) {
    assert.ok(Object.hasOwn(links.policies, c.policy), c.id);
  }
});

test('public decode expectations contain only safe, typed result fields', () => {
  const kinds = new Set();
  for (const c of links.decodeCases) {
    assert.equal(typeof c.raw, 'string', c.id);
    const result = c.expected;
    switch (result.status) {
      case 'recognized': {
        assert.deepEqual(Object.keys(result).sort(), ['link', 'source', 'status']);
        assert.ok(['canonical', 'compatible', 'foreign'].includes(result.source));
        const { kind } = result.link;
        kinds.add(kind);
        assert.ok(Object.hasOwn(linkFields, kind), c.id);
        const fields = ['kind', ...linkFields[kind]];
        if (kind === 'walletAddress' && Object.hasOwn(result.link, 'asset')) {
          fields.push('asset');
        }
        assert.deepEqual(Object.keys(result.link).sort(), fields.sort(), c.id);
        if (kind === 'identity') {
          assert.match(result.link.publicKeyHex, /^[a-f0-9]{64}$/);
          assert.ok(['profile', 'pay'].includes(result.link.intent));
        }
        if (c.canonicalUrl) {
          assert.notEqual(result.source, 'foreign', c.id);
          const policy = links.policies[c.policy];
          const url = new URL(c.canonicalUrl);
          assert.equal(url.origin, policy.canonicalOrigin, c.id);
          assert.equal(url.hash, '', c.id);
          assert.equal(url.username, '', c.id);
          assert.equal(url.password, '', c.id);
          assert.ok(policy.enabledKinds.includes(kind), c.id);
        }
        break;
      }
      case 'legacy':
        assert.deepEqual(Object.keys(result).sort(), ['protocol', 'status']);
        assert.ok([
          ...links.policies[c.policy].legacyProtocols, 'connect', 'walletConnect',
        ].includes(result.protocol), c.id);
        break;
      case 'invalid':
      case 'unsupported':
        assert.deepEqual(Object.keys(result).sort(), ['reason', 'status']);
        assert.ok(reasons.has(result.reason), c.id);
        break;
      default:
        assert.fail(`Unknown fixture status: ${c.id}`);
    }
    if (result.status !== 'recognized') assert.equal(c.canonicalUrl, undefined);
  }
  assert.deepEqual([...kinds].sort(), Object.keys(linkFields).sort());
});

test('input limits use actual UTF-8 bytes before trimming', () => {
  const byId = Object.fromEntries(links.decodeCases.map((c) => [c.id, c]));
  assert.equal(Buffer.byteLength(byId['exact-byte-limit'].raw, 'utf8'), 4096);
  const multibyte = byId['over-byte-limit'].raw;
  assert.ok(multibyte.length < 4096);
  assert.ok(Buffer.byteLength(multibyte, 'utf8') > 4096);
  const padded = byId['raw-limit-before-trimming'].raw;
  assert.ok(Buffer.byteLength(padded, 'utf8') > 4096);
  assert.ok(Buffer.byteLength(padded.trim(), 'utf8') < 4096);
});

test('positive record expectations have complete public envelopes and exact hashes', () => {
  for (const c of records.verifyCases) {
    assert.ok(Object.hasOwn(records.records, c.record), c.id);
    assert.match(c.expected.publicKeyHex, /^[a-f0-9]{64}$/);
    assert.ok(Number.isInteger(c.expected.kind), c.id);
    assert.equal(typeof c.expected.dTag, 'string');
    assert.equal(typeof c.verified, 'boolean');
    if (!c.verified) continue;
    const event = records.records[c.record];
    assert.deepEqual(Object.keys(event).sort(), [
      'content', 'created_at', 'id', 'kind', 'pubkey', 'sig', 'tags',
    ]);
    assert.ok(Number.isInteger(event.created_at), c.id);
    assert.equal(event.pubkey, c.expected.publicKeyHex, c.id);
    assert.equal(event.kind, c.expected.kind, c.id);
    assert.ok(event.tags.every((tag) =>
      Array.isArray(tag) && tag.every((value) => typeof value === 'string')));
    assert.ok(event.tags.some((tag) =>
      tag[0] === 'd' && tag[1] === c.expected.dTag), c.id);
    assert.match(event.sig, /^[a-f0-9]{128}$/);
    assert.equal(eventHash(event), event.id, c.id);
  }
  const data = records.records;
  assert.notEqual(eventHash(data.tamperedContent), data.tamperedContent.id);
  assert.notEqual(eventHash(data.tamperedId), data.tamperedId.id);
  assert.equal(eventHash(data.forgedRehashedContent), data.forgedRehashedContent.id);
  assert.equal(eventHash(data.fractionalTimestamp), data.fractionalTimestamp.id);
});

test('selection expectations agree with verification cases and deterministic ordering', () => {
  for (const c of records.selectionCases) {
    const candidates = c.records.filter((name) => {
      assert.ok(Object.hasOwn(records.records, name), c.id);
      const verification = records.verifyCases.find((v) =>
        v.record === name &&
        v.expected.publicKeyHex === c.expected.publicKeyHex &&
        v.expected.kind === c.expected.kind &&
        v.expected.dTag === c.expected.dTag);
      assert.ok(verification, `Missing verification expectation: ${c.id}/${name}`);
      return verification.verified;
    });
    candidates.sort((a, b) => {
      const left = records.records[a];
      const right = records.records[b];
      return right.created_at - left.created_at ||
        (left.id < right.id ? -1 : left.id > right.id ? 1 : 0);
    });
    assert.equal(candidates[0] ?? null, c.selected, c.id);
  }
  assert.equal(records.records.emptyNewest.content, '');
  assert.throws(() => JSON.parse(records.records.malformedNewest.content));
});
