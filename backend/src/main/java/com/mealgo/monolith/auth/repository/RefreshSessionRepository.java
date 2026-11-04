package com.mealgo.monolith.auth.repository;
import com.mealgo.monolith.auth.entity.RefreshSession;
import jakarta.persistence.LockModeType;
import java.util.*;
import org.springframework.data.jpa.repository.*;
public interface RefreshSessionRepository extends JpaRepository<RefreshSession,UUID> {
    @Lock(LockModeType.PESSIMISTIC_WRITE) @Query("select s from RefreshSession s where s.id=:id")
    Optional<RefreshSession> lockById(UUID id);
}
