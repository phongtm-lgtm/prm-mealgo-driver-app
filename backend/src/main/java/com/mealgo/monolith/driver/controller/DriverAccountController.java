package com.mealgo.monolith.driver.controller;
import com.mealgo.monolith.driver.dto.DriverAccountDtos.*;
import com.mealgo.monolith.driver.service.DriverAccountService;
import com.mealgo.monolith.common.dto.PageResponse;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.*;
import org.springframework.http.HttpStatus;
import org.springframework.format.annotation.DateTimeFormat;
import java.time.LocalDate;
import java.util.UUID;

@RestController @RequestMapping("/api/v1/drivers/me") @RequiredArgsConstructor @PreAuthorize("hasRole('DRIVER')")
public class DriverAccountController {
    private final DriverAccountService service;
    @GetMapping("/order-settings") public OrderSettings settings() { return service.settings(); }
    @PutMapping("/order-settings") public OrderSettings settings(@Valid @RequestBody OrderSettings r) { return service.settings(r); }
    @GetMapping("/app-settings") public AppSettings appSettings() { return service.appSettings(); }
    @PutMapping("/app-settings") public AppSettings appSettings(@Valid @RequestBody AppSettings r) { return service.appSettings(r); }
    @GetMapping("/wallet") public Wallet wallet() { return service.wallet(); }
    @GetMapping("/wallet/transactions") public PageResponse<Transaction> transactions(@RequestParam(defaultValue="0") int page,@RequestParam(defaultValue="20") int size) { return service.transactions(page,size); }
    @GetMapping("/wallet/transactions/{id}") public Transaction transaction(@PathVariable UUID id) { return service.transaction(id); }
    @GetMapping("/earnings") public Earnings earnings(@RequestParam(defaultValue="DAY") Period period,@RequestParam(required=false) @DateTimeFormat(iso=DateTimeFormat.ISO.DATE) LocalDate date) { return service.earnings(period,date); }
    @GetMapping("/notifications") public PageResponse<Notification> notifications(@RequestParam(defaultValue="0") int page,@RequestParam(defaultValue="20") int size) { return service.notifications(page,size); }
    @GetMapping("/notifications/unread-count") public UnreadCount unread() { return service.unread(); }
    @PatchMapping("/notifications/{id}/read") public Notification read(@PathVariable UUID id) { return service.read(id); }
    @PatchMapping("/notifications/read-all") @ResponseStatus(HttpStatus.NO_CONTENT) public void readAll() { service.readAll(); }
}
