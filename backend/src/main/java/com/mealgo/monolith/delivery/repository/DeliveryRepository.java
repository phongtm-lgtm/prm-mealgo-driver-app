package com.mealgo.monolith.delivery.repository;
import com.mealgo.monolith.delivery.entity.Delivery;
import com.mealgo.monolith.delivery.enums.DeliveryStatus;
import jakarta.persistence.LockModeType;
import org.springframework.data.domain.*;
import org.springframework.data.jpa.repository.*;
import java.util.*;
public interface DeliveryRepository extends JpaRepository<Delivery,UUID> {
    Optional<Delivery> findByOrderId(UUID orderId);
    Optional<Delivery> findFirstByDriverIdAndStatusIn(UUID driverId,Collection<DeliveryStatus> statuses);
    boolean existsByDriverIdAndStatusIn(UUID driverId,Collection<DeliveryStatus> statuses);
    Page<Delivery> findByDriverIdAndStatusIn(UUID driverId,Collection<DeliveryStatus> statuses,Pageable pageable);
    List<Delivery> findByStatus(DeliveryStatus status);
    @Lock(LockModeType.PESSIMISTIC_WRITE) @Query("select d from Delivery d where d.id = :id")
    Optional<Delivery> findLockedById(UUID id);
}
