package com.mealgo.monolith.delivery.service;
import com.mealgo.monolith.delivery.entity.Assignment;
import com.mealgo.monolith.delivery.enums.*;
import com.mealgo.monolith.delivery.repository.*;
import com.mealgo.monolith.driver.entity.Driver;
import com.mealgo.monolith.driver.repository.DriverRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.support.TransactionTemplate;
import java.time.Instant;
import java.util.Set;
import java.util.UUID;
@Service @RequiredArgsConstructor
public class DispatchService {
    private final DriverRepository drivers;
    private final DeliveryRepository deliveries;
    private final AssignmentRepository assignments;
    private final DriverEventService events;
    private final com.mealgo.monolith.order.service.OrderService orders;
    private final com.mealgo.monolith.driver.service.DriverAccountService accounts;
    private final ProximityService proximity;
    private final TransactionTemplate transactions;
    @Value("${app.delivery.offer-seconds}") private long offerSeconds;

    public void dispatch() {
        // Release each driver's locks before processing the next driver. Manual refresh can run concurrently.
        for (var driverId : drivers.findDispatchDriverIds(Instant.now())) {
            transactions.executeWithoutResult(tx -> drivers.findLockedById(driverId)
                    .ifPresent(driver -> updateOffers(driver, Set.of())));
        }
    }

    // Both entry points hold this driver's write lock until all offer changes commit.
    void updateOffers(Driver driver, Set<UUID> skippedAssignmentIds) {
        var now = Instant.now();
        boolean hasLiveOffer = false;
        for (var offer : assignments.findByDriverIdAndStatus(driver.getId(), AssignmentStatus.OFFERED)) {
            if (!offer.getExpiresAt().isAfter(now)) {
                offer.setStatus(AssignmentStatus.EXPIRED);
            } else if (skippedAssignmentIds.contains(offer.getId())) {
                offer.setStatus(AssignmentStatus.REJECTED);
                offer.setRespondedAt(now);
            } else {
                hasLiveOffer = true;
                continue;
            }
            events.changedAfterCommit(driver.getId());
        }
        if (hasLiveOffer || !driver.isOnline() || !driver.isActive()
                || deliveries.existsByDriverIdAndStatusIn(driver.getId(), DeliveryService.ACTIVE)) return;

        var settings = accounts.settingsFor(driver);
        for (var deliveryId : deliveries.findOfferCandidateIds(driver.getId(), now)) {
            var delivery = deliveries.findLockedById(deliveryId).orElseThrow();
            // Another driver may have received the offer while we were waiting for this delivery.
            if (delivery.getStatus() != DeliveryStatus.PENDING_ASSIGNMENT || assignments
                    .existsByDeliveryIdAndStatusAndExpiresAtAfter(deliveryId, AssignmentStatus.OFFERED, Instant.now())) continue;
            var order = orders.get(delivery.getOrderId());
            int quantity = order.getItems().stream().mapToInt(item -> item.getQuantity()).sum();
            if (quantity > settings.maxItemQuantity()) continue;
            double km = proximity.routingDistanceMeters(order.getPickupLatitude(), order.getPickupLongitude(),
                    order.getDropoffLatitude(), order.getDropoffLongitude()) / 1000;
            if (km > settings.maxDeliveryDistanceKm()) continue;

            var offer = new Assignment();
            offer.setDriverId(driver.getId());
            offer.setDeliveryId(deliveryId);
            offer.setExpiresAt(Instant.now().plusSeconds(offerSeconds));
            assignments.save(offer);
            events.changedAfterCommit(driver.getId());
            return;
        }
    }
}
