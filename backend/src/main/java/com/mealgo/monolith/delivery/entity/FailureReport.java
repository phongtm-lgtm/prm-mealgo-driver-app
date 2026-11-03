package com.mealgo.monolith.delivery.entity;
import com.mealgo.monolith.delivery.enums.FailureReason;
import jakarta.persistence.*;
import lombok.*;
import java.time.Instant;
import java.util.UUID;
@Entity @Table(name="failure_reports") @Getter @Setter @NoArgsConstructor
public class FailureReport {
    @Id @GeneratedValue(strategy=GenerationType.UUID) private UUID id;
    @Column(nullable=false,unique=true) private UUID deliveryId;
    @Column(nullable=false,unique=true) private UUID assignmentId;
    @Column(nullable=false,unique=true) private UUID requestId;
    @Enumerated(EnumType.STRING) @Column(nullable=false) private FailureReason reason;
    @Column(length=1000) private String note;
    private String objectKey;
    private String sha256;
    private String contentType;
    private long sizeBytes;
    private Instant createdAt = Instant.now();
}
