package com.mealgo.monolith.driver.repository;
import com.mealgo.monolith.driver.entity.Driver;
import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.*;
import java.util.*;
public interface DriverRepository extends JpaRepository<Driver,UUID> {
    Optional<Driver> findByUserId(UUID userId);
    boolean existsByUserId(UUID userId);
    List<Driver> findByOnlineTrueAndActiveTrueOrderById();
    @Lock(LockModeType.PESSIMISTIC_WRITE) @Query("select d from Driver d where d.userId = :userId")
    Optional<Driver> findLockedByUserId(UUID userId);
    @Lock(LockModeType.PESSIMISTIC_WRITE) @Query("select d from Driver d where d.id = :id")
    Optional<Driver> findLockedById(UUID id);
}
