package com.mealgo.monolith.delivery.controller;
import com.mealgo.monolith.delivery.dto.DeliveryDtos.*;
import com.mealgo.monolith.delivery.enums.FailureReason;
import com.mealgo.monolith.delivery.service.DeliveryService;
import com.mealgo.monolith.common.dto.PageResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.http.*;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;
import java.util.UUID;
@RestController @RequestMapping("/api/v1/drivers/me/deliveries") @RequiredArgsConstructor @PreAuthorize("hasRole('DRIVER')")
public class DriverDeliveryController {
    private final DeliveryService service;
    @GetMapping("/current") public ResponseEntity<Current> current() { return service.current().map(ResponseEntity::ok).orElseGet(() -> ResponseEntity.noContent().build()); }
    @GetMapping("/history") public PageResponse<Current> history(@RequestParam(defaultValue="0") int page,@RequestParam(defaultValue="20") int size) { return service.history(page,size); }
    @PostMapping("/{id}/arrive-at-pickup") public Current arrivePickup(@PathVariable UUID id) { return service.action(id,"arrive-at-pickup"); }
    @PostMapping("/{id}/confirm-pickup") public Current pickup(@PathVariable UUID id) { return service.action(id,"confirm-pickup"); }
    @PostMapping("/{id}/arrive-at-dropoff") public Current arriveDropoff(@PathVariable UUID id) { return service.action(id,"arrive-at-dropoff"); }
    @PostMapping("/{id}/confirm-delivery") public Current deliver(@PathVariable UUID id) { return service.action(id,"confirm-delivery"); }
    @PostMapping(value="/{id}/failure-report",consumes=MediaType.MULTIPART_FORM_DATA_VALUE)
    public Current fail(@PathVariable UUID id,@RequestParam UUID assignmentId,@RequestParam UUID requestId,
            @RequestParam FailureReason reason,@RequestParam(required=false) String note,@RequestParam MultipartFile image) {
        return service.fail(id,assignmentId,requestId,reason,note,image);
    }
    @GetMapping("/{id}/failure-report") public ResponseEntity<Report> report(@PathVariable UUID id) {
        return ResponseEntity.ok().cacheControl(CacheControl.noStore()).body(service.report(id));
    }
    @GetMapping("/{id}/failure-report/evidence") public ResponseEntity<byte[]> evidence(@PathVariable UUID id) {
        var result = service.evidence(id);
        return ResponseEntity.ok().contentType(MediaType.parseMediaType(result.contentType())).cacheControl(CacheControl.noStore())
                .header("X-Content-Type-Options","nosniff").body(result.bytes());
    }
}
