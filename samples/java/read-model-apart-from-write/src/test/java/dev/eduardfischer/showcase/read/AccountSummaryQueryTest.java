package dev.eduardfischer.showcase.read;

import dev.eduardfischer.showcase.read.AccountSummaryQuery.AccountSummary;
import org.junit.jupiter.api.AfterAll;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.Test;
import org.springframework.jdbc.core.simple.JdbcClient;
import org.springframework.jdbc.datasource.DriverManagerDataSource;

import java.math.BigDecimal;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertNull;

/**
 * Runs the read query against a real PostgreSQL schema, as the sample's README recommends: the
 * compiler cannot catch a renamed column in a SQL string, so this test is what does.
 *
 * Connection comes from the usual PG* environment variables, defaulting to postgres@localhost:5432.
 */
class AccountSummaryQueryTest {

    private static final String SCHEMA = "read_model_test";
    private static JdbcClient jdbc;

    private static String env(String name, String fallback) {
        String value = System.getenv(name);
        return value == null || value.isBlank() ? fallback : value;
    }

    @BeforeAll
    static void createSchema() {
        String url = "jdbc:postgresql://" + env("PGHOST", "localhost") + ":" + env("PGPORT", "5432")
                + "/" + env("PGDATABASE", "postgres");
        String user = env("PGUSER", "postgres");
        String password = env("PGPASSWORD", "postgres");

        JdbcClient admin = JdbcClient.create(new DriverManagerDataSource(url, user, password));
        admin.sql("DROP SCHEMA IF EXISTS " + SCHEMA + " CASCADE").update();
        admin.sql("CREATE SCHEMA " + SCHEMA).update();
        jdbc = JdbcClient.create(new DriverManagerDataSource(url + "?currentSchema=" + SCHEMA, user, password));

        jdbc.sql("CREATE TABLE holders (id bigint PRIMARY KEY, display_name text NOT NULL)").update();
        jdbc.sql("""
                CREATE TABLE accounts (
                    id bigint PRIMARY KEY,
                    account_number text NOT NULL,
                    holder_id bigint NOT NULL REFERENCES holders (id),
                    balance_minor bigint NOT NULL,
                    currency char(3) NOT NULL)""").update();
        jdbc.sql("""
                CREATE TABLE transfers (
                    id bigint PRIMARY KEY,
                    source_account_id bigint NOT NULL REFERENCES accounts (id),
                    created_at timestamptz NOT NULL)""").update();

        jdbc.sql("INSERT INTO holders VALUES (1, 'Ada'), (2, 'Grace')").update();
        jdbc.sql("""
                INSERT INTO accounts VALUES
                    (10, 'DK-0002', 1, 123456, 'DKK'),
                    (11, 'DK-0001', 1, 500, 'DKK'),
                    (20, 'DK-9999', 2, 1, 'EUR')""").update();
        jdbc.sql("""
                INSERT INTO transfers VALUES
                    (1, 10, now()),
                    (2, 10, now() - interval '1 second'),
                    (3, 10, date_trunc('month', now()) - interval '1 day'),
                    (4, 20, now())""").update();
    }

    @AfterAll
    static void dropSchema() {
        jdbc.sql("DROP SCHEMA IF EXISTS " + SCHEMA + " CASCADE").update();
    }

    @Test
    void returnsOneFlatRowPerAccountOfTheHolderOrderedByNumber() {
        List<AccountSummary> rows = new AccountSummaryQuery(jdbc).forHolder(1);

        assertEquals(List.of("DK-0001", "DK-0002"), rows.stream().map(AccountSummary::accountNumber).toList());
        assertEquals("Ada", rows.get(0).holderName());
        assertEquals(0, new BigDecimal("1234.56").compareTo(rows.get(1).balance()));
        assertEquals("DKK", rows.get(1).currency());
    }

    @Test
    void countsOnlyThisMonthsTransfersButDatesFromAllOfThem() {
        AccountSummary busy = new AccountSummaryQuery(jdbc).forHolder(1).get(1);

        assertEquals(2, busy.transfersThisMonth());
        assertNotNull(busy.lastTransferAt());
    }

    @Test
    void keepsAnAccountWithNoTransfersBecauseTheJoinIsLeft() {
        AccountSummary quiet = new AccountSummaryQuery(jdbc).forHolder(1).get(0);

        assertEquals("DK-0001", quiet.accountNumber());
        assertNull(quiet.lastTransferAt());
        assertEquals(0, quiet.transfersThisMonth());
    }
}
