package dev.eduardfischer.showcase.read;

import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.stereotype.Component;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.List;

/**
 * The read side. It owns one shape and one query, and it knows nothing about the aggregates that
 * produced the rows.
 *
 * No entity, no repository, no mapper. The screen wants a flat row joined across accounts, holders
 * and the latest transfer; the aggregates that enforce the write rules are not that shape and
 * should not be bent into it. Assembling this in Java from three repositories would mean a query
 * per row per page, which is the usual cost of making one object model serve both jobs.
 */
@Component
public class AccountSummaryQuery {

    /**
     * A record, not an entity. Nothing here is managed, nothing is lazy, and nothing can be
     * accidentally saved: this is a value the screen reads and then forgets.
     */
    public record AccountSummary(
            String accountNumber,
            String holderName,
            BigDecimal balance,
            String currency,
            Instant lastTransferAt,
            int transfersThisMonth
    ) {}

    private static final String SQL = """
            SELECT a.account_number,
                   h.display_name                          AS holder_name,
                   a.balance_minor / 100.0                 AS balance,
                   a.currency,
                   MAX(t.created_at)                       AS last_transfer_at,
                   COUNT(t.id) FILTER (
                       WHERE t.created_at >= date_trunc('month', now())
                   )                                       AS transfers_this_month
            FROM accounts a
                     JOIN holders h ON h.id = a.holder_id
                     LEFT JOIN transfers t ON t.source_account_id = a.id
            WHERE h.id = :holderId
            GROUP BY a.account_number, h.display_name, a.balance_minor, a.currency
            ORDER BY a.account_number
            """;

    private final JdbcClient jdbc;

    public AccountSummaryQuery(JdbcClient jdbc) {
        this.jdbc = jdbc;
    }

    /**
     * A LEFT JOIN, so an account with no transfers still appears with a null date and a zero count.
     * An INNER JOIN here would silently hide every new account from its owner's own summary, which
     * is the kind of bug that gets reported as "the page is missing something" months later.
     */
    public List<AccountSummary> forHolder(long holderId) {
        return jdbc.sql(SQL)
                .param("holderId", holderId)
                .query(AccountSummary.class)
                .list();
    }
}
