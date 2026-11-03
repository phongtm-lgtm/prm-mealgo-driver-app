package com.mealgo.monolith.delivery.repository;
import com.mealgo.monolith.delivery.entity.FailureReport;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.*;
public interface FailureReportRepository extends JpaRepository<FailureReport,UUID> {
    Optional<FailureReport> findByDeliveryId(UUID deliveryId);
}
