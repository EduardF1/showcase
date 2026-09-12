import { type Maybe, known, unknown } from "./maybe";

/**
 * The real refusal this type was built for.
 *
 * Three recorded salaries, three different bases. One states 40 hours and no pension. One is a
 * total including pension. For the third the source is silent about pension, and the silence is
 * recorded as silence rather than resolved to the likelier option, because "excluded" is a fact
 * about a contract and nobody wrote it down.
 */

/** included / excluded / unrecorded, never a boolean: a boolean forces a guess on the silent case. */
export type PensionBasis = "included" | "excluded" | "unrecorded";

export interface Compensation {
  readonly id: string;
  readonly monthlyBase: number;
  readonly pensionPct: number | null;
  readonly pensionBasis: PensionBasis;
  /**
   * Null when the contract's week was never recorded. 37 is the standard Danish week and therefore
   * the most dangerous number to assume, because it would look right.
   */
  readonly hoursPerWeek: number | null;
}

const money = (value: number): number => Math.round(value * 100) / 100;

export function totalMonthly(comp: Compensation): Maybe<number> {
  if (comp.pensionBasis === "included") return known(comp.monthlyBase);
  if (comp.pensionBasis === "unrecorded") {
    return unknown(
      `${comp.id} does not record whether its figure includes pension, so its total is not derivable`,
    );
  }
  if (comp.pensionPct === null) {
    return unknown(`${comp.id} excludes pension but records no pension rate, so its total is not derivable`);
  }
  return known(money(comp.monthlyBase * (1 + comp.pensionPct / 100)));
}

/**
 * Percentage change between two figures.
 *
 * It refuses on two separate grounds, and they are different defects. An unknown total means the
 * money is not derivable at all. A differing hours basis means both totals ARE derivable and are
 * still not comparable, which is the more dangerous case precisely because both numbers look fine.
 */
export function change(from: Compensation, to: Compensation): Maybe<number> {
  const start = totalMonthly(from);
  const end = totalMonthly(to);
  if (start.kind === "unknown") return start;
  if (end.kind === "unknown") return end;
  if (from.hoursPerWeek !== to.hoursPerWeek) {
    return unknown(
      `${from.id} and ${to.id} are on different hours bases ` +
        `(${from.hoursPerWeek ?? "unrecorded"} vs ${to.hoursPerWeek ?? "unrecorded"}), so the two are not comparable`,
    );
  }
  if (start.value === 0) return unknown(`${from.id} is zero, so a percentage change is undefined`);
  return known(((end.value - start.value) / start.value) * 100);
}
