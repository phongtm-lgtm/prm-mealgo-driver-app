package com.mealgo.monolith.driver.repository;
import com.mealgo.monolith.driver.entity.Driver;
import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.*;
import java.time.Instant;
import java.util.*;
public interface DriverRepository extends JpaRepository<Driver,UUID> {
    Optional<Driver> findByUserId(UUID userId);
    boolean existsByUserId(UUID userId);
    @Query("""
        select d.id from Driver d where (d.online = true and d.active = true)
        or exists (select a.id from Assignment a where a.driverId = d.id and a.status = OFFERED and a.expiresAt <= :now)
        order by d.id
        """)
    List<UUID> findDispatchDriverIds(Instant now);
    @Lock(LockModeType.PESSIMISTIC_WRITE) @Query("select d from Driver d where d.userId = :userId")
    Optional<Driver> findLockedByUserId(UUID userId);
    @Lock(LockModeType.PESSIMISTIC_WRITE) @Query("select d from Driver d where d.id = :id")
    Optional<Driver> findLockedById(UUID id);
}
