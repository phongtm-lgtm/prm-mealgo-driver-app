package com.mealgo.monolith.delivery.entity;
import com.mealgo.monolith.delivery.enums.AssignmentStatus;
import jakarta.persistence.*;
import lombok.*;
import java.time.Instant;
import java.util.UUID;
@Entity @Table(name="delivery_assignments") @Getter @Setter @NoArgsConstructor
public class Assignment {
    @Id @GeneratedValue(strategy=GenerationType.UUID) private UUID id;
    @Version private long version;
    @Column(nullable=false) private UUID deliveryId;
    @Column(nullable=false) private UUID driverId;
    @Enumerated(EnumType.STRING) @Column(nullable=false) private AssignmentStatus status = AssignmentStatus.OFFERED;
    private Instant offeredAt = Instant.now();
    @Column(nullable=false) private Instant expiresAt;
    private Instant respondedAt;
}
