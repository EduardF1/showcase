package dev.eduardfischer.showcase.write;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * The write side. It enforces one invariant inside one transaction and has never heard of the
 * screen that displays the result.
 *
 * That ignorance is the point. When the summary page gains a column, nothing in this file changes.
 * When the overdraft rule changes, nothing in the query changes. The two sides meet at the tables
 * and nowhere else.
 */
@Service
public class TransferService {

    private final AccountRepository accounts;

    public TransferService(AccountRepository accounts) {
        this.accounts = accounts;
    }

    /**
     * Both accounts are locked in a fixed order.
     *
     * Ordering by id rather than by "source first" is what stops a deadlock: two simultaneous
     * transfers in opposite directions between the same pair would otherwise each hold the lock the
     * other is waiting for. It costs one comparison and removes a fault that only appears under
     * concurrency, which is to say in production and never in a test anybody wrote.
     */
    @Transactional
    public void transfer(long fromAccountId, long toAccountId, long minorUnits) {
        if (fromAccountId == toAccountId) {
            throw new IllegalArgumentException("An account cannot transfer to itself.");
        }
        if (minorUnits <= 0) {
            throw new IllegalArgumentException("A transfer must be a positive amount.");
        }

        long firstId = Math.min(fromAccountId, toAccountId);
        long secondId = Math.max(fromAccountId, toAccountId);
        Account first = accounts.lockById(firstId);
        Account second = accounts.lockById(secondId);

        Account source = firstId == fromAccountId ? first : second;
        Account target = firstId == fromAccountId ? second : first;

        if (!source.currency().equals(target.currency())) {
            throw new IllegalArgumentException(
                    "Cannot transfer between " + source.currency() + " and " + target.currency() + " directly.");
        }

        // The invariant, checked against the locked row rather than against a value read earlier.
        source.withdraw(minorUnits);
        target.deposit(minorUnits);

        accounts.save(source);
        accounts.save(target);
    }
}
