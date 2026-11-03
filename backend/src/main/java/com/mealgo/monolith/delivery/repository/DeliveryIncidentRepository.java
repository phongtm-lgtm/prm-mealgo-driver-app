package com.mealgo.monolith.delivery.repository;
import com.mealgo.monolith.delivery.entity.DeliveryIncident;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.*;
public interface DeliveryIncidentRepository extends JpaRepository<DeliveryIncident,UUID> {
    Optional<DeliveryIncident> findByAssignmentId(UUID assignmentId);
    Optional<DeliveryIncident> findByIdAndDriverId(UUID id,UUID driverId);
    List<DeliveryIncident> findByDriverIdOrderByCreatedAtDesc(UUID driverId);
}
