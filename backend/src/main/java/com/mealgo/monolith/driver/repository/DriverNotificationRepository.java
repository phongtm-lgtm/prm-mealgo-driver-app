package com.mealgo.monolith.driver.repository;
import com.mealgo.monolith.driver.entity.DriverNotification;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.domain.*;
import java.util.*;
public interface DriverNotificationRepository extends JpaRepository<DriverNotification,UUID> {
    Page<DriverNotification> findByDriverId(UUID driverId,Pageable page);
    Optional<DriverNotification> findByIdAndDriverId(UUID id,UUID driverId);
    long countByDriverIdAndReadAtIsNull(UUID driverId);
    List<DriverNotification> findByDriverIdAndReadAtIsNull(UUID driverId);
}
