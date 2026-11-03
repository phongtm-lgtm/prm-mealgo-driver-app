package com.mealgo.monolith.restaurant.entity;
import jakarta.persistence.*;
import lombok.*;
import java.util.UUID;
@Entity @Table(name="restaurants") @Getter @Setter @NoArgsConstructor
public class Restaurant {
    @Id @GeneratedValue(strategy=GenerationType.UUID) private UUID id;
    @Column(nullable=false) private UUID ownerId;
    @Column(nullable=false) private String name;
    @Column(nullable=false) private String phone;
    @Column(nullable=false, length=500) private String address;
    private double latitude;
    private double longitude;
    private boolean acceptingOrders = true;
}
