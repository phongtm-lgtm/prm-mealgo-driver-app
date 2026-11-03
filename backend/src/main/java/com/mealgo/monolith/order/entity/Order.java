package com.mealgo.monolith.order.entity;
import com.mealgo.monolith.order.enums.OrderStatus;
import jakarta.persistence.*;
import lombok.*;
import java.math.BigDecimal;
import java.time.Instant;
import java.util.*;
@Entity @Table(name="customer_orders", uniqueConstraints=@UniqueConstraint(columnNames={"customerId","idempotencyKey"}))
@Getter @Setter @NoArgsConstructor
public class Order {
    @Id @GeneratedValue(strategy=GenerationType.UUID) private UUID id;
    @Version private long version;
    @Column(nullable=false) private UUID customerId;
    @Column(nullable=false) private UUID restaurantId;
    @Column(nullable=false, length=100) private String idempotencyKey;
    @Column(nullable=false, length=64) private String requestHash;
    @Enumerated(EnumType.STRING) @Column(nullable=false) private OrderStatus status = OrderStatus.PENDING;
    @Column(nullable=false) private String recipientName;
    @Column(nullable=false) private String recipientPhone;
    @Column(nullable=false, length=500) private String dropoffAddress;
    private double dropoffLatitude;
    private double dropoffLongitude;
    @Column(nullable=false, length=500) private String pickupAddress;
    private double pickupLatitude;
    private double pickupLongitude;
    private String restaurantName;
    private String restaurantPhone;
    @Column(length=1000) private String deliveryNote;
    private String paymentMethod;
    @Column(precision=19,scale=2) private BigDecimal subtotal;
    @Column(precision=19,scale=2) private BigDecimal deliveryFee;
    @Column(precision=19,scale=2) private BigDecimal total;
    private String currency = "VND";
    @Column(length=500) private String cancellationReason;
    private Instant createdAt = Instant.now();
    private Instant updatedAt = Instant.now();
    private Instant estimatedReadyAt;
    private Instant readyAt;
    @OneToMany(mappedBy="order",cascade=CascadeType.ALL,orphanRemoval=true)
    private List<OrderItem> items = new ArrayList<>();
}
