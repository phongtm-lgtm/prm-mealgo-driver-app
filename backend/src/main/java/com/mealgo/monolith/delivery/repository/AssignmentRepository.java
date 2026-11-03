package com.mealgo.monolith.delivery.repository;
import com.mealgo.monolith.delivery.entity.Assignment;
import com.mealgo.monolith.delivery.enums.AssignmentStatus;
import org.springframework.data.jpa.repository.JpaRepository;
import java.time.Instant;
import java.util.*;
public interface AssignmentRepository extends JpaRepository<Assignment,UUID> {
    List<Assignment> findByDriverIdAndStatusAndExpiresAtAfter(UUID driverId,AssignmentStatus status,Instant now);
    boolean existsByDriverIdAndStatusAndExpiresAtAfter(UUID driverId,AssignmentStatus status,Instant now);
    boolean existsByDeliveryIdAndStatusAndExpiresAtAfter(UUID deliveryId,AssignmentStatus status,Instant now);
    boolean existsByDeliveryIdAndDriverId(UUID deliveryId,UUID driverId);
    List<Assignment> findByStatusAndExpiresAtBefore(AssignmentStatus status,Instant now);
}
