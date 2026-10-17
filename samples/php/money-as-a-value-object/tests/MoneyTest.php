<?php

declare(strict_types=1);

namespace Showcase\Money\Tests;

use InvalidArgumentException;
use PHPUnit\Framework\Attributes\DataProvider;
use PHPUnit\Framework\TestCase;
use Showcase\Money\Money;

final class MoneyTest extends TestCase
{
    public function testAdditionIsIntegerAdditionInMinorUnits(): void
    {
        // The 0.1 + 0.2 case, in øre: exact, because no float is involved.
        $sum = Money::of(10, 'DKK')->plus(Money::of(20, 'DKK'));

        self::assertSame(30, $sum->minorUnits);
        self::assertTrue($sum->equals(Money::of(30, 'DKK')));
    }

    public function testRefusesToCombineCurrencies(): void
    {
        $this->expectException(InvalidArgumentException::class);
        $this->expectExceptionMessage('Cannot combine DKK with EUR');

        Money::of(100, 'DKK')->plus(Money::of(100, 'EUR'));
    }

    public function testMinusAlsoRefusesToCombineCurrencies(): void
    {
        $this->expectException(InvalidArgumentException::class);

        Money::of(100, 'DKK')->minus(Money::of(100, 'EUR'));
    }

    public function testOperationsReturnNewInstancesAndLeaveTheOriginalAlone(): void
    {
        $price = Money::of(1499, 'DKK');
        $price->plus(Money::of(1, 'DKK'));
        $price->minus(Money::of(1, 'DKK'));

        self::assertSame(1499, $price->minorUnits);
    }

    public function testPropertiesCannotBeWritten(): void
    {
        $this->expectException(\Error::class);

        $price = Money::of(1499, 'DKK');
        $price->minorUnits = 1;
    }

    /** @return iterable<string, array{string}> */
    public static function badCurrencies(): iterable
    {
        yield 'lowercase' => ['dkk'];
        yield 'too short' => ['DK'];
        yield 'too long' => ['DKKK'];
    }

    #[DataProvider('badCurrencies')]
    public function testRejectsACurrencyThatIsNotAThreeLetterUppercaseCode(string $currency): void
    {
        $this->expectException(InvalidArgumentException::class);

        Money::of(100, $currency);
    }

    /** @return iterable<string, array{int, int, list<int>}> */
    public static function allocations(): iterable
    {
        yield '100 across 3' => [100, 3, [34, 33, 33]];
        yield '101 across 3' => [101, 3, [34, 34, 33]];
        yield 'even split' => [99, 3, [33, 33, 33]];
        yield 'fewer units than parts' => [2, 4, [1, 1, 0, 0]];
        yield 'negative' => [-100, 3, [-34, -33, -33]];
        yield 'one part' => [7, 1, [7]];
    }

    /** @param list<int> $expected */
    #[DataProvider('allocations')]
    public function testAllocationHandsOutTheRemainderFromTheStartAndAlwaysSumsToTheWhole(
        int $amount,
        int $parts,
        array $expected,
    ): void {
        $allocated = Money::of($amount, 'DKK')->allocate($parts);

        self::assertSame($expected, array_map(static fn (Money $m) => $m->minorUnits, $allocated));
        self::assertSame($amount, array_sum(array_map(static fn (Money $m) => $m->minorUnits, $allocated)));
        foreach ($allocated as $part) {
            self::assertSame('DKK', $part->currency);
        }
    }

    public function testAllocationIntoFewerThanOnePartIsRefused(): void
    {
        $this->expectException(InvalidArgumentException::class);

        Money::of(100, 'DKK')->allocate(0);
    }

    public function testFormatIsForDisplay(): void
    {
        self::assertSame('14.99 DKK', Money::of(1499, 'DKK')->format());
        self::assertSame('-0.05 EUR', Money::of(-5, 'EUR')->format());
    }
}
