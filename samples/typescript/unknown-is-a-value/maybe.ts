/**
 * A value that may be absent, carrying the reason it is absent.
 *
 * Deliberately NOT `T | undefined` and NOT `T | null`. Both of those are skippable: `value ?? 0`
 * compiles, reads as tidy, and silently turns "we never measured this" into "this is zero". A union
 * with a discriminant cannot be collapsed by accident, and TypeScript will not let a caller read
 * `.value` until they have proved which side they are on.
 *
 * The `reason` is required rather than optional. An unexplained refusal is only marginally better
 * than a wrong number: it tells the reader something is missing but not what to go and find.
 */
export type Maybe<T> =
  | { readonly kind: "known"; readonly value: T }
  | { readonly kind: "unknown"; readonly reason: string };

export const known = <T>(value: T): Maybe<T> => ({ kind: "known", value });

export const unknown = <T>(reason: string): Maybe<T> => {
  if (reason.trim().length === 0) {
    // A refusal with an empty reason is the failure mode this type exists to prevent, so it is a
    // programming error rather than a runtime state to render.
    throw new Error("unknown() requires a reason; an unexplained refusal helps nobody");
  }
  return { kind: "unknown", reason };
};

/** Apply a function to a known value, carrying a refusal through untouched. */
export const map = <T, U>(maybe: Maybe<T>, fn: (value: T) => U): Maybe<U> =>
  maybe.kind === "known" ? known(fn(maybe.value)) : maybe;

/**
 * Render for a human. There is no default parameter: the caller must say what absence looks like in
 * their context, because a shared default is how "unknown" becomes a dash that reads as a zero.
 */
export const present = <T>(
  maybe: Maybe<T>,
  format: (value: T) => string,
  absent: (reason: string) => string,
): string => (maybe.kind === "known" ? format(maybe.value) : absent(maybe.reason));
