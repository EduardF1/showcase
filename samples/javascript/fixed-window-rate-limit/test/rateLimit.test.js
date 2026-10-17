import { test, mock } from "node:test";
import assert from "node:assert/strict";
import { rateLimit } from "../rateLimit.js";

/** An in-memory store that records every key it is given. */
function memoryStore() {
  const counts = new Map();
  return {
    keys: [],
    async increment(key) {
      this.keys.push(key);
      counts.set(key, (counts.get(key) ?? 0) + 1);
      return counts.get(key);
    },
  };
}

const base = { endpoint: "contact", identifier: "203.0.113.7", limit: 2, windowSeconds: 60 };

test("allows up to the limit and denies past it, and says the check ran", async () => {
  const store = memoryStore();
  const results = [];
  for (let i = 0; i < 3; i++) results.push(await rateLimit({ ...base, store }));

  assert.deepEqual(results.map((r) => r.allowed), [true, true, false]);
  assert.ok(results.every((r) => r.checked));
  assert.equal(results[2].count, 3);
});

test("fails open when the store is down, with checked: false so it does not look like quiet traffic", async (t) => {
  const warn = t.mock.method(console, "warn", () => {});
  const store = { increment: async () => { throw new Error("ECONNREFUSED"); } };

  const result = await rateLimit({ ...base, store });

  assert.deepEqual(result, { allowed: true, count: 0, limit: 2, checked: false });
  assert.equal(warn.mock.callCount(), 1);
});

test("never puts the raw identifier in the key, and salts the hash with the endpoint", async () => {
  const store = memoryStore();
  await rateLimit({ ...base, store, endpoint: "contact" });
  await rateLimit({ ...base, store, endpoint: "signup" });

  const [contactKey, signupKey] = store.keys;
  assert.ok(!contactKey.includes(base.identifier));
  const subject = (key) => key.split(":")[2];
  assert.match(subject(contactKey), /^[0-9a-f]{16}$/);
  assert.notEqual(subject(contactKey), subject(signupKey));
});

test("the window is fixed: a new window starts a fresh budget", async () => {
  const store = memoryStore();
  const now = mock.method(Date, "now", () => 59_000);
  try {
    assert.equal((await rateLimit({ ...base, store, limit: 1 })).allowed, true);
    assert.equal((await rateLimit({ ...base, store, limit: 1 })).allowed, false);
    now.mock.mockImplementation(() => 60_000);
    assert.equal((await rateLimit({ ...base, store, limit: 1 })).allowed, true);
  } finally {
    now.mock.restore();
  }
});

test("rejects a limit that would deny everything or silently disable the throttle", async () => {
  for (const limit of [0, -1, NaN, 1.5]) {
    await assert.rejects(rateLimit({ ...base, store: memoryStore(), limit }), TypeError);
  }
});
