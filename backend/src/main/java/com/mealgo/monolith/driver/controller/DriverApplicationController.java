package com.mealgo.monolith.driver.controller;
import com.mealgo.monolith.driver.service.DriverApplicationService;
import com.mealgo.monolith.driver.service.DriverApplicationService.*;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;
@RestController @RequestMapping("/api/v1/drivers/me/application") @RequiredArgsConstructor @PreAuthorize("hasRole('DRIVER')")
public class DriverApplicationController {
    private final DriverApplicationService service;
    @GetMapping public View get() { return service.get(); }
    @PutMapping public View save(@Valid @RequestBody Form r) { return service.save(r); }
    @PostMapping("/documents/{type}") public View upload(@PathVariable String type,@RequestParam MultipartFile image) { return service.upload(type,image); }
    @PostMapping("/submit") public View submit() { return service.submit(); }
}
