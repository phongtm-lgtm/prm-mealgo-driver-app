package com.mealgo.monolith.auth.service;

import com.mealgo.monolith.auth.dto.AuthDtos.*;
import com.mealgo.monolith.auth.entity.UserAccount;
import com.mealgo.monolith.auth.repository.UserAccountRepository;
import com.mealgo.monolith.common.exception.ApiException;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.authentication.BadCredentialsException;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.oauth2.jose.jws.MacAlgorithm;
import org.springframework.security.oauth2.jwt.*;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.time.Instant;
import java.util.List;

@Service @RequiredArgsConstructor
public class AuthService {
    private final UserAccountRepository users;
    private final PasswordEncoder passwords;
    private final JwtEncoder encoder;
    @Value("${app.jwt.issuer}") private String issuer;
    @Value("${app.jwt.ttl-seconds}") private long ttl;

    @Transactional
    public Token register(Register request) {
        String phone = PhoneNumbers.normalize(request.phoneNumber());
        if (users.existsByPhoneNumber(phone)) throw ApiException.conflict("Số điện thoại đã được đăng ký");
        // Merchant accounts are provisioned by a trusted operator, not public registration.
        if (request.role() == com.mealgo.monolith.auth.entity.Role.MERCHANT)
            throw ApiException.badRequest("Merchant accounts must be provisioned by an operator");
        var user = new UserAccount();
        user.setUsername(java.util.UUID.randomUUID().toString()); user.setPhoneNumber(phone);
        user.setPasswordHash(passwords.encode(request.password())); user.setRole(request.role());
        return token(users.save(user));
    }
    @Transactional(readOnly=true)
    public Token login(Login request) {
        var user = users.findByPhoneNumber(PhoneNumbers.normalize(request.phoneNumber())).orElseThrow(() -> new BadCredentialsException("Invalid credentials"));
        if (!passwords.matches(request.password(), user.getPasswordHash())) throw new BadCredentialsException("Invalid credentials");
        return token(user);
    }
    private Token token(UserAccount user) {
        var now = Instant.now();
        var claims = JwtClaimsSet.builder().issuer(issuer).subject(user.getId().toString()).issuedAt(now)
                .expiresAt(now.plusSeconds(ttl)).claim("roles", List.of(user.getRole().name())).build();
        String value = encoder.encode(JwtEncoderParameters.from(JwsHeader.with(MacAlgorithm.HS256).build(), claims)).getTokenValue();
        return new Token(value, "Bearer", ttl, user.getId(), user.getRole());
    }
}
