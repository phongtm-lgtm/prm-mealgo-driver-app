package com.mealgo.monolith.driver.entity;
import jakarta.persistence.*;
import lombok.*;
import java.time.Instant;
import java.util.UUID;
@Entity @Table(name="pending_driver_earnings") @Getter @Setter @NoArgsConstructor
public class PendingDriverEarning {
    @Id private UUID deliveryId;
    @Column(nullable=false) private UUID driverId;
    @Column(nullable=false) private Instant deliveredAt;
    private boolean resolved;
    private Instant resolvedAt;
    private UUID resolvedBy;
}
