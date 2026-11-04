package com.mealgo.monolith.driver.repository;
import com.mealgo.monolith.driver.entity.DriverApplication;
import java.util.*;
import jakarta.persistence.LockModeType;
import org.springframework.data.jpa.repository.*;
public interface DriverApplicationRepository extends JpaRepository<DriverApplication,UUID> {
    Optional<DriverApplication> findByUserId(UUID userId);
    @Lock(LockModeType.PESSIMISTIC_WRITE) @Query("select a from DriverApplication a where a.id=:id")
    Optional<DriverApplication> findLockedById(UUID id);
}
