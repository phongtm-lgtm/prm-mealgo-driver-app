package com.mealgo.monolith.driver.repository;
import com.mealgo.monolith.driver.entity.DriverEarning;
import org.springframework.data.jpa.repository.*;
import org.springframework.data.repository.query.Param;
import org.springframework.data.domain.*;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.*;
public interface DriverEarningRepository extends JpaRepository<DriverEarning,UUID> {
    boolean existsByDeliveryId(UUID deliveryId);
    Optional<DriverEarning> findByDeliveryId(UUID deliveryId);
    Page<DriverEarning> findByRateConfiguredFalse(Pageable page);
    Page<DriverEarning> findByDriverIdAndRateConfiguredTrue(UUID driverId,Pageable page);
    Optional<DriverEarning> findByIdAndDriverId(UUID id,UUID driverId);
    Page<DriverEarning> findByDriverId(UUID driverId,Pageable page);
    List<DriverEarning> findByDriverIdAndCreatedAtGreaterThanEqualAndCreatedAtLessThan(UUID driverId,Instant start,Instant end);
    @Query("select coalesce(sum(e.amount),0) from DriverEarning e where e.driverId=:driverId and e.rateConfigured=true")
    BigDecimal balance(@Param("driverId") UUID driverId);
}
