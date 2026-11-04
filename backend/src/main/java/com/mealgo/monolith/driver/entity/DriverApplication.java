package com.mealgo.monolith.driver.entity;
import jakarta.persistence.*;
import lombok.*;
import java.time.*;
import java.util.*;
@Entity @Table(name="driver_applications") @Getter @Setter @NoArgsConstructor
public class DriverApplication {
    @Id @GeneratedValue(strategy=GenerationType.UUID) private UUID id;
    @Version private long version;
    @Column(nullable=false,unique=true) private UUID userId;
    private String status="DRAFT";
    private String fullName;
    private LocalDate birthDate;
    private String address;
    private String identityNumber;
    private String vehicleType;
    private String licensePlate;
    private String drivingLicense;
    private Instant submittedAt;
    private Instant reviewedAt;
    private UUID reviewedBy;
    private String reviewNote;
    @ElementCollection(fetch=FetchType.EAGER)
    @CollectionTable(name="driver_application_documents",joinColumns=@JoinColumn(name="application_id"))
    @MapKeyColumn(name="document_type") @Column(name="object_key")
    private Map<String,String> documents=new HashMap<>();
}
