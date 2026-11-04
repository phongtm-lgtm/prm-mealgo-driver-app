package com.mealgo.monolith.auth.controller;
import com.mealgo.monolith.auth.service.MockRegistrationService;
import com.mealgo.monolith.auth.service.MockRegistrationService.*;
import com.mealgo.monolith.auth.dto.AuthDtos.Token;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;
@RestController @RequestMapping("/api/v1/auth/register") @RequiredArgsConstructor
public class RegistrationController {
    private final MockRegistrationService service;
    @PostMapping("/start") public Challenge start(@Valid @RequestBody Start r) { return service.start(r); }
    @PostMapping("/verify") public Token verify(@Valid @RequestBody Verify r) { return service.verify(r); }
    @PostMapping("/resend") public Challenge resend(@Valid @RequestBody Resend r) { return service.resend(r); }
}
