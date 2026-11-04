package com.mealgo.monolith.driver.repository;
import com.mealgo.monolith.driver.entity.PendingDriverEarning;
import java.util.*;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.domain.*;
public interface PendingDriverEarningRepository extends JpaRepository<PendingDriverEarning,UUID> {
    Page<PendingDriverEarning> findByResolvedFalse(Pageable page);
}
