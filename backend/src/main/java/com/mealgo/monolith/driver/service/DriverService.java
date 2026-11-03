package com.mealgo.monolith.driver.service;
import com.mealgo.monolith.driver.dto.DriverDtos.*;
import com.mealgo.monolith.driver.entity.Driver;
import com.mealgo.monolith.driver.repository.DriverRepository;
import com.mealgo.monolith.driver.mapper.DriverMapper;
import com.mealgo.monolith.common.security.CurrentUser;
import com.mealgo.monolith.common.exception.ApiException;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;
import java.time.Instant;
import java.util.UUID;

@Service @RequiredArgsConstructor
public class DriverService {
    private final DriverRepository drivers;
    private final CurrentUser current;
    private final DriverMapper mapper;
    @Value("${app.delivery.location-max-age-seconds}") private long maxAge;
    @Transactional public UUID register(ProfileRequest r) {
        if (drivers.existsByUserId(current.id())) throw ApiException.conflict("Driver already registered");
        var d = new Driver(); d.setUserId(current.id()); d.setFullName(r.fullName()); d.setPhoneNumber(r.phoneNumber());
        return drivers.save(d).getId();
    }
    @Transactional(readOnly=true) public Profile profile() { return mapper.toResponse(myDriver()); }
    // Stub only: never use this result as biometric proof or an authorization gate.
    @Transactional(readOnly=true) public FaceVerificationResult verifyFace(MultipartFile image) {
        myDriver();
        if (image.isEmpty()) throw ApiException.badRequest("Face image is required");
        return new FaceVerificationResult(true, "MOCK_ALWAYS_SUCCESS", Instant.now());
    }
    @Transactional public Profile update(ProfileRequest r) {
        var d = lockMine(); d.setFullName(r.fullName()); d.setPhoneNumber(r.phoneNumber()); d.setUpdatedAt(Instant.now());
        return mapper.toResponse(d);
    }
    @Transactional public Profile online(OnlineRequest r) {
        var d = lockMine();
        if (r.online() && !d.isActive()) throw ApiException.conflict("Driver account is not active");
        d.setOnline(r.online()); d.setUpdatedAt(Instant.now()); return mapper.toResponse(d);
    }
    @Transactional public Session startSession() {
        var d = lockMine(); var now = Instant.now();
        d.setTrackingSessionId(UUID.randomUUID()); d.setTrackingStartedAt(now); d.setLocationSequence(0);
        d.setRecordedAt(null); d.setLatitude(null); d.setLongitude(null); d.setAccuracyMeters(null);
        return new Session(d.getTrackingSessionId(),now);
    }
    @Transactional public LocationResult updateLocation(LocationRequest r) {
        var d = lockMine();
        if (!r.trackingSessionId().equals(d.getTrackingSessionId())) throw ApiException.conflict("Tracking session is no longer active");
        if (r.sequence() <= d.getLocationSequence()) return new LocationResult(false,d.getLocationSequence());
        var now = Instant.now();
        if (r.recordedAt().isBefore(now.minusSeconds(maxAge)) || r.recordedAt().isAfter(now.plusSeconds(10)))
            throw ApiException.badRequest("Location timestamp is stale or in the future");
        if (d.getRecordedAt()!=null && r.recordedAt().isBefore(d.getRecordedAt()))
            throw ApiException.badRequest("Location timestamp must not move backwards");
        d.setLocationSequence(r.sequence()); d.setLatitude(r.latitude()); d.setLongitude(r.longitude());
        d.setAccuracyMeters(r.accuracyMeters()); d.setRecordedAt(r.recordedAt());
        return new LocationResult(true,d.getLocationSequence());
    }
    @Transactional(readOnly=true) public Driver myDriver() {
        return drivers.findByUserId(current.id()).orElseThrow(() -> ApiException.notFound("Driver profile not found"));
    }
    @Transactional public Driver lockMine() {
        return drivers.findLockedByUserId(current.id()).orElseThrow(() -> ApiException.notFound("Driver profile not found"));
    }
    @Transactional(readOnly=true) public Driver get(UUID id) {
        return drivers.findById(id).orElseThrow(() -> ApiException.notFound("Driver not found"));
    }
}
