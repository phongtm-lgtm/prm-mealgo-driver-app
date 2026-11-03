package com.mealgo.monolith.driver.entity;
import jakarta.persistence.*;
import lombok.*;
import java.time.Instant;
import java.util.UUID;
@Entity @Table(name="drivers") @Getter @Setter @NoArgsConstructor
public class Driver {
    @Id @GeneratedValue(strategy=GenerationType.UUID) private UUID id;
    @Version private long version;
    @Column(nullable=false,unique=true) private UUID userId;
    @Column(nullable=false,length=150) private String fullName;
    @Column(nullable=false,length=20) private String phoneNumber;
    private boolean online;
    private boolean active = true;
    private Instant createdAt = Instant.now();
    private Instant updatedAt = Instant.now();
    private UUID trackingSessionId;
    private Instant trackingStartedAt;
    private long locationSequence;
    private Double latitude;
    private Double longitude;
    private Double accuracyMeters;
    private Instant recordedAt;
    @Column(nullable=false,columnDefinition="boolean default false")
    private boolean autoAcceptEnabled;
    private Double maxDeliveryDistanceKm;
    private Integer maxItemQuantity;
    private java.math.BigDecimal maxRestaurantAdvanceAmount;
    private Boolean inAppNotificationsEnabled;
}
