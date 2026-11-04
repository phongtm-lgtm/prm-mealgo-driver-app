package com.mealgo.monolith.auth.controller;
import com.mealgo.monolith.auth.dto.AuthDtos.*;
import com.mealgo.monolith.auth.service.AuthService;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;
@RestController @RequestMapping("/api/v1/auth") @RequiredArgsConstructor
public class AuthController {
    private final AuthService auth;
    @PostMapping("/register") @ResponseStatus(HttpStatus.CREATED)
    public Token register(@Valid @RequestBody Register request) { return auth.register(request); }
    @PostMapping("/login") public Token login(@Valid @RequestBody Login request) { return auth.login(request); }
    @PostMapping("/refresh") public Token refresh(@Valid @RequestBody Refresh request) { return auth.refresh(request); }
    @PostMapping("/logout") @ResponseStatus(HttpStatus.NO_CONTENT)
    public void logout(@Valid @RequestBody Refresh request) { auth.logout(request); }
}
