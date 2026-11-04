package com.mealgo.monolith.auth.entity;
import jakarta.persistence.*;
import lombok.*;
import java.time.Instant;
import java.util.UUID;
@Entity @Table(name="refresh_sessions") @Getter @Setter @NoArgsConstructor
public class RefreshSession {
    @Id private UUID id;
    @Column(nullable=false) private UUID userId;
    @Column(nullable=false,length=64) private String tokenHash;
    @Column(nullable=false) private Instant expiresAt;
    private boolean revoked;
}
