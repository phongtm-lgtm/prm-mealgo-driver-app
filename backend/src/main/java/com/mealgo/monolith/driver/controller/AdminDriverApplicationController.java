package com.mealgo.monolith.driver.controller;
import com.mealgo.monolith.driver.service.DriverApplicationService;
import com.mealgo.monolith.driver.service.DriverApplicationService.*;
import jakarta.validation.Valid;
import java.util.UUID;
import lombok.RequiredArgsConstructor;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import org.springframework.http.*;
@RestController @RequestMapping("/api/v1/admin/driver-applications") @RequiredArgsConstructor @PreAuthorize("hasRole('ADMIN')")
public class AdminDriverApplicationController {
    private final DriverApplicationService service;
    @GetMapping("/{id}") public View get(@PathVariable UUID id) { return service.adminGet(id); }
    @GetMapping("/{id}/documents/{type}") public ResponseEntity<byte[]> document(@PathVariable UUID id,@PathVariable String type) {
        return ResponseEntity.ok().contentType(MediaType.APPLICATION_OCTET_STREAM).header("Cache-Control","no-store")
            .header("Content-Disposition","attachment; filename=\"document\"").body(service.document(id,type));
    }
    @PostMapping("/{id}/approve") public View approve(@PathVariable UUID id,@Valid @RequestBody Approval r) { return service.approve(id,r); }
}
