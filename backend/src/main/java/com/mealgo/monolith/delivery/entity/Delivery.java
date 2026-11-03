package com.mealgo.monolith.delivery.entity;
import com.mealgo.monolith.delivery.enums.DeliveryStatus;
import jakarta.persistence.*;
import lombok.*;
import java.time.Instant;
import java.util.UUID;
@Entity @Table(name="deliveries") @Getter @Setter @NoArgsConstructor
public class Delivery {
    @Id @GeneratedValue(strategy=GenerationType.UUID) private UUID id;
    @Version private long version;
    @Column(nullable=false,unique=true) private UUID orderId;
    private UUID driverId;
    private UUID assignmentId;
    @Enumerated(EnumType.STRING) @Column(nullable=false) private DeliveryStatus status = DeliveryStatus.PENDING_ASSIGNMENT;
    private Instant updatedAt = Instant.now();
    private Instant pickedUpAt;
    private Instant deliveredAt;
    private Instant failedAt;
}
