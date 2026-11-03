package com.mealgo.monolith.delivery.scheduler;
import com.mealgo.monolith.delivery.service.DispatchService;
import lombok.RequiredArgsConstructor;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
@Component @RequiredArgsConstructor @ConditionalOnProperty(name="app.dispatch.enabled",havingValue="true",matchIfMissing=true)
public class DispatchScheduler {
    private final DispatchService dispatcher;
    @Scheduled(fixedDelayString="${app.dispatch.delay-ms:5000}") public void run() { dispatcher.dispatch(); }
}
