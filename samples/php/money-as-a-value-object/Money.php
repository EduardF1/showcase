<?php

declare(strict_types=1);

namespace Showcase\Money;

use InvalidArgumentException;

/**
 * An amount of money, in minor units, with its currency.
 *
 * Integer minor units because 0.1 + 0.2 is not 0.3 and a price out by a hundredth passes every test
 * that checks it "looks right". Currency inside the type because adding kroner to euros is a
 * mistake somebody makes under deadline, and the only place to catch it reliably is the operation
 * itself, which is the only code that knows both sides.
 *
 * Immutable: every operation returns a new instance. An amount that can be mutated in place is an
 * amount that can be changed by a function you passed it to.
 */
final class Money
{
    private function __construct(
        public readonly int $minorUnits,
        public readonly string $currency,
    ) {
    }

    public static function of(int $minorUnits, string $currency): self
    {
        if (strlen($currency) !== 3 || strtoupper($currency) !== $currency) {
            throw new InvalidArgumentException("Currency must be a 3 letter uppercase code, got '{$currency}'.");
        }

        return new self($minorUnits, $currency);
    }

    public function plus(self $other): self
    {
        $this->assertSameCurrency($other);

        return new self($this->minorUnits + $other->minorUnits, $this->currency);
    }

    public function minus(self $other): self
    {
        $this->assertSameCurrency($other);

        return new self($this->minorUnits - $other->minorUnits, $this->currency);
    }

    /**
     * Split into $parts whose sum is exactly this amount.
     *
     * The remainder is the reason this method exists. 100 across 3 is 33, 33, 33 and a lost unit;
     * here the leftover units are handed out one each from the start, so the parts always add back
     * up. Who gets the extra unit is arbitrary, and stating the rule is the difference between an
     * arbitrary choice and an accident.
     *
     * @return list<self>
     */
    public function allocate(int $parts): array
    {
        if ($parts < 1) {
            throw new InvalidArgumentException("Cannot allocate into {$parts} parts.");
        }

        $base = intdiv($this->minorUnits, $parts);
        $remainder = $this->minorUnits - ($base * $parts);
        $direction = $remainder <=> 0;

        $out = [];
        for ($i = 0; $i < $parts; $i++) {
            $extra = $i < abs($remainder) ? $direction : 0;
            $out[] = new self($base + $extra, $this->currency);
        }

        return $out;
    }

    public function equals(self $other): bool
    {
        return $this->minorUnits === $other->minorUnits && $this->currency === $other->currency;
    }

    /** For display only. Never parse this back: the string is for a human, the integer is the value. */
    public function format(): string
    {
        $sign = $this->minorUnits < 0 ? '-' : '';
        $abs = abs($this->minorUnits);

        return sprintf('%s%d.%02d %s', $sign, intdiv($abs, 100), $abs % 100, $this->currency);
    }

    private function assertSameCurrency(self $other): void
    {
        if ($this->currency !== $other->currency) {
            throw new InvalidArgumentException(
                "Cannot combine {$this->currency} with {$other->currency}; convert one of them first."
            );
        }
    }
}
