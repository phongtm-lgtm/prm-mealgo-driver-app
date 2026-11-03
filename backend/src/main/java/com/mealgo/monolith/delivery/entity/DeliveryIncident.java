package com.mealgo.monolith.delivery.entity;
import jakarta.persistence.*;
import lombok.*;
import java.time.Instant;
import java.util.UUID;
import com.mealgo.monolith.delivery.enums.IncidentReason;
@Entity @Table(name="delivery_incidents",uniqueConstraints=@UniqueConstraint(columnNames={"assignmentId"}))
@Getter @Setter @NoArgsConstructor
public class DeliveryIncident {
    @Id @GeneratedValue(strategy=GenerationType.UUID) private UUID id;
    @Column(nullable=false) private UUID deliveryId;
    @Column(nullable=false) private UUID assignmentId;
    @Column(nullable=false) private UUID driverId;
    @Column(nullable=false) private UUID requestId;
    @Enumerated(EnumType.STRING) @Column(nullable=false) private IncidentReason reason;
    @Column(length=1000) private String note;
    private String objectKey;
    private String sha256;
    private String contentType;
    @Column(nullable=false) private Instant createdAt=Instant.now();
}
