package com.mealgo.monolith;

import com.mealgo.monolith.delivery.service.DriverEventService;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.transaction.support.TransactionSynchronizationManager;
import static org.junit.jupiter.api.Assertions.*;

class DriverEventServiceTest {
    @Test void notificationsAreDeferredUntilCommit() {
        var service = new DriverEventService();
        var driverId = UUID.randomUUID();
        TransactionSynchronizationManager.initSynchronization();
        try {
            service.changedAfterCommit(driverId);
            var callbacks = TransactionSynchronizationManager.getSynchronizations();
            assertEquals(1, callbacks.size());
            assertDoesNotThrow(() -> callbacks.getFirst().afterCommit());
        } finally {
            TransactionSynchronizationManager.clearSynchronization();
        }
    }

    @Test void subscriptionHasBoundedLifetimeAndSupportsMultipleDrivers() {
        var service = new DriverEventService();
        var first = service.subscribe(UUID.randomUUID());
        var second = service.subscribe(UUID.randomUUID());
        assertEquals(300_000L, first.getTimeout());
        assertDoesNotThrow(service::heartbeat);
        first.complete();
        second.complete();
    }
}
