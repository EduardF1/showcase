import { test } from "node:test";
import assert from "node:assert/strict";
import { type Compensation, change, totalMonthly } from "../salary";

const comp = (overrides: Partial<Compensation> & Pick<Compensation, "id">): Compensation => ({
  monthlyBase: 40_000,
  pensionPct: null,
  pensionBasis: "included",
  hoursPerWeek: 40,
  ...overrides,
});

test("an included-pension figure is its own total", () => {
  assert.deepEqual(totalMonthly(comp({ id: "a" })), { kind: "known", value: 40_000 });
});

test("an excluded-pension figure adds the recorded rate", () => {
  const total = totalMonthly(comp({ id: "b", pensionBasis: "excluded", pensionPct: 10 }));
  assert.deepEqual(total, { kind: "known", value: 44_000 });
});

test("silence about pension is refused, not resolved to the likelier option", () => {
  const total = totalMonthly(comp({ id: "c", pensionBasis: "unrecorded" }));
  assert.equal(total.kind, "unknown");
  assert.match(total.kind === "unknown" ? total.reason : "", /c does not record whether/);
});

test("excluded pension with no rate is refused", () => {
  assert.equal(totalMonthly(comp({ id: "d", pensionBasis: "excluded" })).kind, "unknown");
});

test("change refuses two derivable figures on different hours bases", () => {
  const result = change(comp({ id: "x", hoursPerWeek: 40 }), comp({ id: "y", hoursPerWeek: 37 }));
  assert.equal(result.kind, "unknown");
  assert.match(result.kind === "unknown" ? result.reason : "", /different hours bases \(40 vs 37\)/);
});

test("change refuses when either hours basis is unrecorded, rather than assuming 37", () => {
  const result = change(comp({ id: "x", hoursPerWeek: 37 }), comp({ id: "y", hoursPerWeek: null }));
  assert.match(result.kind === "unknown" ? result.reason : "", /37 vs unrecorded/);
});

test("change carries the first refusal through", () => {
  const result = change(comp({ id: "x", pensionBasis: "unrecorded" }), comp({ id: "y" }));
  assert.match(result.kind === "unknown" ? result.reason : "", /^x does not record/);
});

test("change on a comparable pair is a percentage", () => {
  const result = change(comp({ id: "x" }), comp({ id: "y", monthlyBase: 42_000 }));
  assert.deepEqual(result, { kind: "known", value: 5 });
});

test("a zero starting figure has no percentage change", () => {
  assert.equal(change(comp({ id: "x", monthlyBase: 0 }), comp({ id: "y" })).kind, "unknown");
});
