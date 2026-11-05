package com.mealgo.monolith.delivery.repository;
import com.mealgo.monolith.delivery.entity.Delivery;
import com.mealgo.monolith.delivery.enums.DeliveryStatus;
import jakarta.persistence.LockModeType;
import org.springframework.data.domain.*;
import org.springframework.data.jpa.repository.*;
import java.time.Instant;
import java.util.*;
public interface DeliveryRepository extends JpaRepository<Delivery,UUID> {
    Optional<Delivery> findByOrderId(UUID orderId);
    @Lock(LockModeType.PESSIMISTIC_WRITE) @Query("select d from Delivery d where d.orderId = :orderId")
    Optional<Delivery> findLockedByOrderId(UUID orderId);
    boolean existsByOrderId(UUID orderId);
    Optional<Delivery> findFirstByDriverIdAndStatusIn(UUID driverId,Collection<DeliveryStatus> statuses);
    boolean existsByDriverIdAndStatusIn(UUID driverId,Collection<DeliveryStatus> statuses);
    Page<Delivery> findByDriverIdAndStatusIn(UUID driverId,Collection<DeliveryStatus> statuses,Pageable pageable);
    @Query("""
        select d.id from Delivery d where d.status = PENDING_ASSIGNMENT
        and not exists (select a.id from Assignment a where a.deliveryId = d.id
            and (a.driverId = :driverId or (a.status = OFFERED and a.expiresAt > :now)))
        order by d.id
        """)
    List<UUID> findOfferCandidateIds(UUID driverId, Instant now);
    @Lock(LockModeType.PESSIMISTIC_WRITE) @Query("select d from Delivery d where d.id = :id")
    Optional<Delivery> findLockedById(UUID id);
}
