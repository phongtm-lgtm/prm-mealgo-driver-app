package com.mealgo.monolith.driver.entity;
import jakarta.persistence.*;
import lombok.*;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.UUID;

@Entity @Table(name="driver_earnings") @Getter @Setter @NoArgsConstructor
public class DriverEarning {
    @Id @GeneratedValue(strategy=GenerationType.UUID) private UUID id;
    @Column(nullable=false) private UUID driverId;
    @Column(nullable=false,unique=true) private UUID deliveryId;
    @Column(nullable=false,precision=19,scale=2) private BigDecimal amount;
    @Column(nullable=false,precision=19,scale=2) private BigDecimal balanceAfter;
    private boolean rateConfigured;
    @Column(nullable=false) private Instant createdAt;
}
