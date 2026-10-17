package dev.eduardfischer.showcase.write;

/** Test double: the sample uses this type without defining it. */
public interface AccountRepository {

    /** Loads the account and holds a row lock on it for the rest of the transaction. */
    Account lockById(long id);

    void save(Account account);
}
