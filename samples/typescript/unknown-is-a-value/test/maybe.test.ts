import { test } from "node:test";
import assert from "node:assert/strict";
import { type Maybe, known, map, present, unknown } from "../maybe";

test("unknown requires a reason", () => {
  assert.throws(() => unknown(""), /requires a reason/);
  assert.throws(() => unknown("   "), /requires a reason/);
  assert.deepEqual(unknown("never measured"), { kind: "unknown", reason: "never measured" });
});

test("map transforms a known value and carries a refusal through untouched", () => {
  assert.deepEqual(map(known(2), (n) => n * 10), known(20));
  const refusal = unknown<number>("source is silent");
  assert.equal(map(refusal, (n) => n * 10), refusal);
});

test("present makes the caller say what absence looks like", () => {
  const show = (m: Maybe<number>) => present(m, (n) => n.toFixed(1), (why) => `not derivable: ${why}`);
  assert.equal(show(known(3)), "3.0");
  assert.equal(show(unknown("no pension rate")), "not derivable: no pension rate");
});

// Compile-time checks: `tsc` fails if any of these lines stops being an error.
export function typeLevel(m: Maybe<number>): void {
  // @ts-expect-error  .value cannot be read before narrowing to "known".
  void m.value;
  // @ts-expect-error  present has no default for the absent case.
  present(m, String);
  // @ts-expect-error  a Maybe cannot be collapsed with ?? the way `T | undefined` can.
  const n: number = m ?? 0;
  void n;
  if (m.kind === "known") void m.value;
}
