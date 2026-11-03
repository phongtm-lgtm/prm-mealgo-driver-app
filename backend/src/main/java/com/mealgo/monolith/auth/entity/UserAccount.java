package com.mealgo.monolith.auth.entity;

import jakarta.persistence.*;
import lombok.*;
import java.util.UUID;

@Entity @Table(name = "user_accounts") @Getter @Setter @NoArgsConstructor
public class UserAccount {
    @Id @GeneratedValue(strategy = GenerationType.UUID) private UUID id;
    @Column(nullable = false, unique = true, length = 150) private String username;
    // Nullable during migration: legacy accounts retain their IDs and data.
    @Column(unique = true, length = 12) private String phoneNumber;
    @Column(nullable = false) private String passwordHash;
    @Enumerated(EnumType.STRING) @Column(nullable = false) private Role role;
}
