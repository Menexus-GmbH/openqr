# Shared OpenQR conformance fixtures

Both `dart/openqr` and `ts/` must consume these JSON files directly from the repository.
Do not copy the vectors into language-specific tests or regenerate expected values from the implementation under test.
`schemaVersion: 1` versions this test-data layout, independently of link-spec v1 and package versions.
All identities, references, addresses and records here are synthetic test data.

## Link cases

`links.json` contains named `policies`, `decodeCases` and `encodeRejectCases`.
Each decoder case supplies its policy name, exact `raw` string and complete `expected` result.
Compare the whole public result, including its status, source, reason or protocol and typed link fields.
The shared source vocabulary is `canonical`, `compatible` and `foreign`.
Absent optional link fields stay absent; unknown foreign wallet network and wallet type are explicitly `null`.
Failures and opaque legacy results expose only safe enums, without the original input.

When `canonicalUrl` is present, encode the expected typed link using the same policy and compare that exact string.
Decode the encoded string again and compare the typed link; its source is then `canonical`.
Canonical wallet queries use the order `v`, `chain`, `network`, `type`, then optional `asset`.
The corpus chooses the permitted `v=1` output for booking-session and ticket links.
Foreign inputs have no `canonicalUrl`; recognition alone is not an instruction to create a Skyzai QR.
Every `encodeRejectCases` link must fail encoding, without requiring a particular exception class or error message.

Policy objects describe test-host configuration rather than a required public constructor layout.
`wallets` declares the explicit chain/network/type/asset vocabulary accepted by that host.
The `wallet` and `trading` type values preserve the reference app's vocabulary; `checking` is intentionally unsupported.
The `reservedEnabled` policy represents a hypothetical host with qualified request/pairing resolvers, not approval to enable those features in Skyzai.

`legacyProtocols` names explicitly installed test-host adapters.
The `legacyHost` adapter recognizes the shown old wallet URL/JSON, booking JSON and event path forms, and maps the old payment scheme to a typed compatible payment.
The ordinary `skyzai` policy installs none of those adapters.
Known links with rejected versions, origins or syntax must never reach an adapter as a fallback.
WalletConnect and Connect cases test scheme-only opaque classification using secret-free synthetic strings; they do not test SDK parsing or consent.
Raw booking IDs remain unsupported in the general decoder.

The private-identifier rejection samples use a publicly known synthetic test scalar, never an operational key.
The Hedera checksum-suffix sample is only a preserved account candidate; the host still validates checksum and ledger.
Optional `nprofile` support is outside this initial corpus.
The length cases contain literal strings so both languages count the same UTF-8 bytes, including the multibyte over-limit input and the limit before trimming.

## Public signed records

`records.json` stores public NIP-01 envelopes under `records`.
Each `verifyCases` entry names a record and supplies the requested `expected` coordinate (`publicKeyHex`, `kind`, `dTag`) and exact `verified` boolean.
Each `selectionCases` entry supplies an ordered list of record names, a coordinate and a `selected` record name or `null`.
Compare the complete selected envelope, preserving its content verbatim.
Run both listed tie permutations; choose descending timestamp, then ascending event ID, independently of input order.

Empty content and malformed content JSON can both be correctly signed envelopes.
The selector must return these newest envelopes before host content validation; it must not recover old endpoints by selecting an older parseable payload.
The two forged-content cases distinguish a mismatched hash from a recomputed hash with an invalid signature.
The fractional timestamp is also correctly signed but fails the integer-seconds envelope requirement.
Extra fields in a matching `d` tag and a matching tag after another `d` preserve the reviewed verifier's exact-match behavior.

Records were generated offline with `nostr-tools` 2.25.2 using publicly known synthetic test scalars 1 and 2.
Only the public envelopes are stored; there is no signer, key-generation API or live relay input in this repository.
The fixture author checked signatures and expected coordinates with the reference TypeScript dependency's public verifier and the reviewed Dart helper using strict envelope conversion.

## Corpus integrity check

Run from the repository root:

```sh
node --test fixtures/integrity.test.mjs
```

This dependency-free check validates the data shape, public-result boundaries, coverage, event hashes and deterministic selection expectations.
It does not implement the link decoder or Schnorr verification, and does not establish package conformance.
The future Dart and TypeScript suites must execute every case through their actual codecs and verifiers.
