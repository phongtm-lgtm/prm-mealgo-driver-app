package com.mealgo.monolith.delivery.service;

import java.io.IOException;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

/** Single-instance notifications only; clients refetch authoritative state on reconnect. */
@Service
public class DriverEventService {
    private final Map<UUID, Set<SseEmitter>> clients = new ConcurrentHashMap<>();

    public SseEmitter subscribe(UUID driverId) {
        // Reconnect periodically so a fresh JWT is checked, rather than keeping an expired session open.
        var emitter = new SseEmitter(300_000L);
        clients.computeIfAbsent(driverId, ignored -> ConcurrentHashMap.newKeySet()).add(emitter);
        Runnable remove = () -> clients.computeIfPresent(driverId, (id, set) -> {
            set.remove(emitter);
            return set.isEmpty() ? null : set;
        });
        emitter.onCompletion(remove);
        emitter.onTimeout(() -> { remove.run(); emitter.complete(); });
        emitter.onError(error -> remove.run());
        send(driverId, emitter, "connected");
        return emitter;
    }

    public void changedAfterCommit(UUID driverId) {
        if (driverId == null) return;
        if (TransactionSynchronizationManager.isSynchronizationActive()) {
            TransactionSynchronizationManager.registerSynchronization(new TransactionSynchronization() {
                @Override public void afterCommit() { publish(driverId, "orders-changed"); }
            });
        } else {
            publish(driverId, "orders-changed");
        }
    }

    @Scheduled(fixedDelay = 15000)
    public void heartbeat() {
        clients.keySet().forEach(id -> publish(id, "heartbeat"));
    }

    private void publish(UUID driverId, String event) {
        var emitters = clients.get(driverId);
        if (emitters != null) emitters.forEach(emitter -> send(driverId, emitter, event));
    }

    private void send(UUID driverId, SseEmitter emitter, String event) {
        try {
            emitter.send(SseEmitter.event().name(event).data("{}"));
        } catch (IOException | IllegalStateException error) {
            clients.computeIfPresent(driverId, (id, set) -> {
                set.remove(emitter);
                return set.isEmpty() ? null : set;
            });
            emitter.complete();
        }
    }
}
