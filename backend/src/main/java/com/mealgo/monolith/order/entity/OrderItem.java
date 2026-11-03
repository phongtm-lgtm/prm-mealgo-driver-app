package com.mealgo.monolith.order.entity;
import jakarta.persistence.*;
import lombok.*;
import java.math.BigDecimal;
import java.util.UUID;
@Entity @Table(name="order_items") @Getter @Setter @NoArgsConstructor
public class OrderItem {
    @Id @GeneratedValue(strategy=GenerationType.UUID) private UUID id;
    @ManyToOne(fetch=FetchType.LAZY,optional=false) @JoinColumn(name="order_id") private Order order;
    private UUID menuItemId;
    private String name;
    private int quantity;
    @Column(precision=19,scale=2) private BigDecimal unitPrice;
    @Column(length=500) private String note;
}
