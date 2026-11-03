package com.mealgo.monolith.driver.dto;
import jakarta.validation.constraints.*;
import java.time.Instant;
import java.util.UUID;
public final class DriverDtos {
    private DriverDtos() {}
    public record ProfileRequest(@NotBlank @Size(max=150) String fullName, @NotBlank @Size(max=20) String phoneNumber) {}
    public record OnlineRequest(@NotNull Boolean online) {}
    public record FaceVerificationResult(boolean success, String mode, Instant checkedAt) {}
    public record Profile(UUID driverId,String fullName,String phoneNumber,String accountStatus,String onlineStatus,Instant createdAt,Instant updatedAt) {}
    public record Session(UUID trackingSessionId,Instant startedAt) {}
    public record LocationRequest(@NotNull UUID trackingSessionId, @NotNull @Positive Long sequence,
            @NotNull @DecimalMin("-90") @DecimalMax("90") Double latitude,
            @NotNull @DecimalMin("-180") @DecimalMax("180") Double longitude,
            @NotNull @DecimalMin("0") Double accuracyMeters, @NotNull Instant recordedAt) {}
    public record LocationResult(boolean applied,long currentSequence) {}
}
