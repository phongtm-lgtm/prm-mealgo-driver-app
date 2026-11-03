package com.mealgo.monolith.customer.entity;

import jakarta.persistence.*;
import lombok.*;
import java.util.UUID;

@Entity @Table(name="customer_cart_items", uniqueConstraints=@UniqueConstraint(columnNames={"customer_id","menu_item_id"}))
@Getter @Setter @NoArgsConstructor
public class CartItem {
    @Id @GeneratedValue(strategy=GenerationType.UUID) private UUID id;
    @Column(name="customer_id",nullable=false) private UUID customerId;
    @Column(name="menu_item_id",nullable=false) private UUID menuItemId;
    @Column(nullable=false) private int quantity;
    @Column(length=500) private String note;
}
