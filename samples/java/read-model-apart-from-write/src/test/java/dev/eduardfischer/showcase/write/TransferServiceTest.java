package dev.eduardfischer.showcase.write;

import org.junit.jupiter.api.Test;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

class TransferServiceTest {

    /** Records the order rows are locked in, which is the decision the deadlock comment describes. */
    static final class RecordingRepository implements AccountRepository {
        final Map<Long, Account> rows = new HashMap<>();
        final List<Long> lockOrder = new ArrayList<>();
        final List<Long> saved = new ArrayList<>();

        RecordingRepository with(Account account) {
            rows.put(account.id(), account);
            return this;
        }

        @Override
        public Account lockById(long id) {
            lockOrder.add(id);
            return rows.get(id);
        }

        @Override
        public void save(Account account) {
            saved.add(account.id());
        }
    }

    private static RecordingRepository twoAccounts() {
        return new RecordingRepository()
                .with(new Account(1, "DKK", 10_000))
                .with(new Account(2, "DKK", 10_000));
    }

    @Test
    void locksInIdOrderWhicheverDirectionTheMoneyMoves() {
        RecordingRepository forward = twoAccounts();
        new TransferService(forward).transfer(1, 2, 500);
        RecordingRepository backward = twoAccounts();
        new TransferService(backward).transfer(2, 1, 500);

        assertEquals(List.of(1L, 2L), forward.lockOrder);
        assertEquals(List.of(1L, 2L), backward.lockOrder);
    }

    @Test
    void movesTheAmountFromSourceToTargetEvenWhenSourceHasTheHigherId() {
        RecordingRepository repo = twoAccounts();
        new TransferService(repo).transfer(2, 1, 2_500);

        assertEquals(12_500, repo.rows.get(1L).balanceMinor());
        assertEquals(7_500, repo.rows.get(2L).balanceMinor());
        assertTrue(repo.saved.containsAll(List.of(1L, 2L)));
    }

    @Test
    void rejectsTransferToSelfAndNonPositiveAmountsBeforeLocking() {
        RecordingRepository repo = twoAccounts();
        TransferService service = new TransferService(repo);

        assertThrows(IllegalArgumentException.class, () -> service.transfer(1, 1, 100));
        assertThrows(IllegalArgumentException.class, () -> service.transfer(1, 2, 0));
        assertThrows(IllegalArgumentException.class, () -> service.transfer(1, 2, -5));
        assertTrue(repo.lockOrder.isEmpty());
    }

    @Test
    void refusesToMixCurrencies() {
        RecordingRepository repo = new RecordingRepository()
                .with(new Account(1, "DKK", 10_000))
                .with(new Account(2, "EUR", 10_000));

        assertThrows(IllegalArgumentException.class, () -> new TransferService(repo).transfer(1, 2, 100));
        assertTrue(repo.saved.isEmpty());
    }
}
