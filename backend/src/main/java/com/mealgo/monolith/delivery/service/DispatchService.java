package com.mealgo.monolith.delivery.service;
import com.mealgo.monolith.delivery.entity.Assignment;
import com.mealgo.monolith.delivery.enums.*;
import com.mealgo.monolith.delivery.repository.*;
import com.mealgo.monolith.driver.repository.DriverRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.time.Instant;
@Service @RequiredArgsConstructor
public class DispatchService {
    private final DriverRepository drivers;
    private final DeliveryRepository deliveries;
    private final AssignmentRepository assignments;
    private final com.mealgo.monolith.order.service.OrderService orders;
    private final com.mealgo.monolith.driver.service.DriverAccountService accounts;
    private final ProximityService proximity;
    @Value("${app.delivery.offer-seconds}") private long offerSeconds;

    @Transactional public void dispatch() {
        var now = Instant.now();
        for (var a : assignments.findByStatusAndExpiresAtBefore(AssignmentStatus.OFFERED,now)) a.setStatus(AssignmentStatus.EXPIRED);
        // MVP: deterministic first-available dispatch; no repeat offers to the same driver for a delivery.
        for (var candidate : drivers.findByOnlineTrueAndActiveTrueOrderById()) {
            var driver = drivers.findLockedById(candidate.getId()).orElseThrow();
            if (!driver.isOnline() || !driver.isActive()
                    || deliveries.existsByDriverIdAndStatusIn(driver.getId(),DeliveryService.ACTIVE)
                    || assignments.existsByDriverIdAndStatusAndExpiresAtAfter(driver.getId(),AssignmentStatus.OFFERED,now)) continue;
            for (var pending : deliveries.findByStatus(DeliveryStatus.PENDING_ASSIGNMENT)) {
                var d = deliveries.findLockedById(pending.getId()).orElseThrow();
                if (d.getStatus()!=DeliveryStatus.PENDING_ASSIGNMENT
                        || assignments.existsByDeliveryIdAndStatusAndExpiresAtAfter(d.getId(),AssignmentStatus.OFFERED,now)
                        || assignments.existsByDeliveryIdAndDriverId(d.getId(),driver.getId())) continue;
                var order=orders.get(d.getOrderId()); var settings=accounts.settingsFor(driver);
                double km=proximity.routingDistanceMeters(order.getPickupLatitude(),order.getPickupLongitude(),order.getDropoffLatitude(),order.getDropoffLongitude())/1000;
                if(km>settings.maxDeliveryDistanceKm() || order.getItems().stream().mapToInt(i->i.getQuantity()).sum()>settings.maxItemQuantity()) continue;
                // Current COD flow requires no restaurant advance, so zero satisfies every valid advance limit.
                var a = new Assignment(); a.setDriverId(driver.getId()); a.setDeliveryId(d.getId()); a.setExpiresAt(now.plusSeconds(offerSeconds));
                assignments.save(a); break;
            }
        }
    }
}
