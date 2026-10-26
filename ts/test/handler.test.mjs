/** Delayed account/caller changes discard completion without changing a target's meaning. */
import assert from "node:assert/strict";
import test from "node:test";
import { OpenQrInvocation } from "@menexus-gmbh/openqr";

const link = { kind: "ticket", ticketRef: "ticket_01" };
for (const outcome of ["handled", "cancelled", "obsolete", "unsupported"]) {
  test(`preserves ${outcome}, the exact ticket and pay context`, async () => {
    const invocation = new OpenQrInvocation({
      context: "pay",
      isCurrent: () => true,
      isCancelled: () => false,
    });
    let calls = 0;
    assert.equal(
      await invocation.run(link, async (target, scope) => {
        calls++;
        assert.equal(target, link);
        assert.equal(scope, invocation);
        assert.equal(scope.context, "pay");
        return outcome;
      }),
      outcome,
    );
    assert.equal(calls, 1);
  });
}
for (const obsolete of [false, true]) {
  const outcome = obsolete ? "obsolete" : "cancelled";
  test(`blocks ${outcome} before invoking the host`, async () => {
    const invocation = new OpenQrInvocation({
      context: "general",
      isCurrent: () => !obsolete,
      isCancelled: () => !obsolete,
    });
    assert.equal(
      await invocation.run(link, async () => assert.fail("Must not dispatch")),
      outcome,
    );
  });
  test(`discards delayed ${outcome} completion and host effects`, async () => {
    let current = true,
      cancelled = false,
      effects = 0,
      resolve;
    const pending = new Promise((done) => {
      resolve = done;
    });
    const invocation = new OpenQrInvocation({
      context: "network",
      isCurrent: () => current,
      isCancelled: () => cancelled,
    });
    const result = invocation.run(link, async (_, scope) => {
      await pending;
      if (scope.interruption) return scope.interruption;
      effects++;
      return "handled";
    });
    current = !obsolete;
    cancelled = !obsolete;
    resolve();
    assert.equal(await result, outcome);
    assert.equal(effects, 0);
  });
}
test("rechecks guards even when the callback returns stale handled", async () => {
  let current = true;
  const invocation = new OpenQrInvocation({
    context: "general",
    isCurrent: () => current,
    isCancelled: () => false,
  });
  assert.equal(
    await invocation.run(link, async () => {
      current = false;
      return "handled";
    }),
    "obsolete",
  );
});
test("callback errors reach the host UI boundary", async () => {
  const invocation = new OpenQrInvocation({
    context: "general",
    isCurrent: () => true,
    isCancelled: () => false,
  });
  await assert.rejects(
    invocation.run(link, async () => {
      throw new Error("host error");
    }),
    /host error/,
  );
});
