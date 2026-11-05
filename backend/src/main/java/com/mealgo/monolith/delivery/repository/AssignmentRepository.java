package com.mealgo.monolith.delivery.repository;
import com.mealgo.monolith.delivery.entity.Assignment;
import com.mealgo.monolith.delivery.enums.AssignmentStatus;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import jakarta.persistence.LockModeType;
import java.time.Instant;
import java.util.*;
public interface AssignmentRepository extends JpaRepository<Assignment,UUID> {
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    List<Assignment> findByDeliveryId(UUID deliveryId);
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    List<Assignment> findByDriverIdAndStatus(UUID driverId,AssignmentStatus status);
    List<Assignment> findByDriverIdAndStatusAndExpiresAtAfter(UUID driverId,AssignmentStatus status,Instant now);
    boolean existsByDeliveryIdAndStatusAndExpiresAtAfter(UUID deliveryId,AssignmentStatus status,Instant now);
}
