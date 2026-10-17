package dev.eduardfischer.showcase.write;

/** Test double: the sample uses this type without defining it. Holds the overdraft invariant. */
public class Account {

    private final long id;
    private final String currency;
    private long balanceMinor;

    public Account(long id, String currency, long balanceMinor) {
        this.id = id;
        this.currency = currency;
        this.balanceMinor = balanceMinor;
    }

    public long id() {
        return id;
    }

    public String currency() {
        return currency;
    }

    public long balanceMinor() {
        return balanceMinor;
    }

    public void withdraw(long minorUnits) {
        if (minorUnits > balanceMinor) {
            throw new IllegalStateException("Insufficient funds in account " + id + ".");
        }
        balanceMinor -= minorUnits;
    }

    public void deposit(long minorUnits) {
        balanceMinor += minorUnits;
    }
}
