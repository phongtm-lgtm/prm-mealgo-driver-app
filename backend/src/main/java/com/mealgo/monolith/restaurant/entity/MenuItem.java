package com.mealgo.monolith.restaurant.entity;
import jakarta.persistence.*;
import lombok.*;
import java.math.BigDecimal;
import java.util.UUID;
@Entity @Table(name="menu_items") @Getter @Setter @NoArgsConstructor
public class MenuItem {
    @Id @GeneratedValue(strategy=GenerationType.UUID) private UUID id;
    @Column(nullable=false) private UUID restaurantId;
    @Column(nullable=false) private String name;
    @Column(nullable=false, precision=19, scale=2) private BigDecimal price;
    private boolean available = true;
}
