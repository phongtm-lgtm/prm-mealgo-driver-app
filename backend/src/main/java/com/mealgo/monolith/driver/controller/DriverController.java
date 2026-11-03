package com.mealgo.monolith.driver.controller;
import com.mealgo.monolith.driver.dto.DriverDtos.*;
import com.mealgo.monolith.driver.service.DriverService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.web.multipart.MultipartFile;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import java.util.*;
@RestController @RequestMapping("/api/v1/drivers") @RequiredArgsConstructor @PreAuthorize("hasRole('DRIVER')")
public class DriverController {
    private final DriverService drivers;
    @PostMapping @ResponseStatus(HttpStatus.CREATED)
    public Map<String,UUID> register(@Valid @RequestBody ProfileRequest r) { return Map.of("driverId",drivers.register(r)); }
    @GetMapping("/me") public Profile profile() { return drivers.profile(); }
    @PostMapping(value="/me/face-verification", consumes=MediaType.MULTIPART_FORM_DATA_VALUE)
    public FaceVerificationResult verifyFace(@RequestPart("image") MultipartFile image) { return drivers.verifyFace(image); }
    @PutMapping("/me/profile") public Profile update(@Valid @RequestBody ProfileRequest r) { return drivers.update(r); }
    @PutMapping("/me/online-status") public Profile online(@Valid @RequestBody OnlineRequest r) { return drivers.online(r); }
    @PostMapping("/me/tracking-session") @ResponseStatus(HttpStatus.CREATED) public Session session() { return drivers.startSession(); }
    @PutMapping("/me/location") public LocationResult location(@Valid @RequestBody LocationRequest r) { return drivers.updateLocation(r); }
}
