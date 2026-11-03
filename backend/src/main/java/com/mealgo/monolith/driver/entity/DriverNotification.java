package com.mealgo.monolith.driver.entity;
import jakarta.persistence.*;
import lombok.*;
import java.time.Instant;
import java.util.UUID;

@Entity @Table(name="driver_notifications") @Getter @Setter @NoArgsConstructor
public class DriverNotification {
    @Id @GeneratedValue(strategy=GenerationType.UUID) private UUID id;
    @Column(nullable=false) private UUID driverId;
    private UUID referenceId;
    @Column(nullable=false) private String type;
    @Column(nullable=false) private String title;
    @Column(nullable=false,length=1000) private String message;
    private Instant readAt;
    @Column(nullable=false) private Instant createdAt = Instant.now();
}
