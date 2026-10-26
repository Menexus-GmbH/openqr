/** Compile the emitted public declarations as a consumer and check union discrimination. */
import {
  OpenQrInvocation,
  OpenQrPolicy,
  decode,
  encode,
  isVerifiedNostrRecord,
  newestVerifiedRecord,
} from "@menexus-gmbh/openqr";
import type {
  OpenQrLink,
  OpenQrHandler,
  OpenQrHandling,
  OpenQrExpectedRecord,
  NostrRecord,
} from "@menexus-gmbh/openqr";

const policy = new OpenQrPolicy();
const ticket: OpenQrLink = { kind: "ticket", ticketRef: "ticket_01" };
const url: string = encode(ticket, policy);
const result = decode(url, policy);
if (result.status === "recognized" && result.link.kind === "ticket") {
  const ref: string = result.link.ticketRef;
  void ref;
  // @ts-expect-error A ticket cannot become a payment by scan context.
  result.link.paymentId;
}
// @ts-expect-error The required field must match the discriminant.
const invalid: OpenQrLink = { kind: "ticket", paymentId: "payment_01" };
void invalid;
const invocation = new OpenQrInvocation({
  context: "pay",
  isCurrent: () => true,
  isCancelled: () => false,
});
const handler: OpenQrHandler = async (link, scope) =>
  scope.interruption ?? (link.kind === "ticket" ? "handled" : "unsupported");
const outcome: Promise<OpenQrHandling> = invocation.run(ticket, handler);
void outcome;
const record: unknown = null;
const expected: OpenQrExpectedRecord = {
  kind: 30302,
  publicKeyHex: "0".repeat(64),
  dTag: "payments",
};
if (isVerifiedNostrRecord(record, expected)) {
  const verified: NostrRecord = record;
  // @ts-expect-error Public tags are read-only.
  verified.tags.push(["d", "other"]);
}
const newest: NostrRecord | null = newestVerifiedRecord([record], expected);
void newest;
