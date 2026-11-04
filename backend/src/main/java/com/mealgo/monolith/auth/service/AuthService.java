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
    private final com.mealgo.monolith.auth.repository.RefreshSessionRepository sessions;
    @Value("${app.jwt.refresh-ttl-seconds:2592000}") private long refreshTtl;
    @Value("${app.jwt.issuer}") private String issuer;
    @Value("${app.jwt.ttl-seconds}") private long ttl;

    @Transactional
    public Token register(Register request) {
        String phone = PhoneNumbers.normalize(request.phoneNumber());
        if (users.existsByPhoneNumber(phone)) throw ApiException.conflict("Số điện thoại đã được đăng ký");
        // Merchant accounts are provisioned by a trusted operator, not public registration.
        if (request.role() != com.mealgo.monolith.auth.entity.Role.CUSTOMER)
            throw ApiException.badRequest("Merchant accounts must be provisioned by an operator");
        var user = new UserAccount();
        user.setUsername(java.util.UUID.randomUUID().toString()); user.setPhoneNumber(phone);
        user.setPasswordHash(passwords.encode(request.password())); user.setRole(request.role());
        return token(users.save(user));
    }
    @Transactional
    public Token login(Login request) {
        var user = users.findByPhoneNumber(PhoneNumbers.normalize(request.phoneNumber())).orElseThrow(() -> new BadCredentialsException("Invalid credentials"));
        if (!passwords.matches(request.password(), user.getPasswordHash())) throw new BadCredentialsException("Invalid credentials");
        return token(user);
    }
    @Transactional
    public Token token(UserAccount user) {
        var session = new com.mealgo.monolith.auth.entity.RefreshSession();
        session.setId(java.util.UUID.randomUUID()); session.setUserId(user.getId());
        session.setExpiresAt(Instant.now().plusSeconds(refreshTtl));
        return issue(user, session);
    }
    private Token issue(UserAccount user, com.mealgo.monolith.auth.entity.RefreshSession session) {
        byte[] bytes = new byte[32]; new java.security.SecureRandom().nextBytes(bytes);
        String refresh = session.getId()+"."+java.util.Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);
        session.setTokenHash(hash(refresh)); sessions.save(session);
        var now = Instant.now();
        var claims = JwtClaimsSet.builder().issuer(issuer).subject(user.getId().toString()).issuedAt(now)
                .expiresAt(now.plusSeconds(ttl)).claim("roles", List.of(user.getRole().name())).build();
        String value = encoder.encode(JwtEncoderParameters.from(JwsHeader.with(MacAlgorithm.HS256).build(), claims)).getTokenValue();
        return new Token(value, "Bearer", ttl, user.getId(), user.getRole(), refresh);
    }
    private String hash(String value) {
        try { return java.util.HexFormat.of().formatHex(java.security.MessageDigest.getInstance("SHA-256").digest(value.getBytes(java.nio.charset.StandardCharsets.UTF_8))); }
        catch(java.security.NoSuchAlgorithmException e) { throw new IllegalStateException(e); }
    }
    private com.mealgo.monolith.auth.entity.RefreshSession session(String value) {
        try { return sessions.lockById(java.util.UUID.fromString(value.split("\\.",2)[0])).orElseThrow(() -> new BadCredentialsException("Invalid session")); }
        catch(IllegalArgumentException e) { throw new BadCredentialsException("Invalid session"); }
    }
    @Transactional(noRollbackFor=BadCredentialsException.class)
    public Token refresh(Refresh request) {
        var s = session(request.refreshToken());
        if(s.isRevoked() || !s.getExpiresAt().isAfter(Instant.now())) throw new BadCredentialsException("Session expired");
        if(!java.security.MessageDigest.isEqual(s.getTokenHash().getBytes(java.nio.charset.StandardCharsets.UTF_8), hash(request.refreshToken()).getBytes(java.nio.charset.StandardCharsets.UTF_8))) {
            s.setRevoked(true); throw new BadCredentialsException("Session reused");
        }
        return issue(users.findById(s.getUserId()).orElseThrow(() -> new BadCredentialsException("Invalid session")), s);
    }
    @Transactional
    public void logout(Refresh request) {
        var s = session(request.refreshToken());
        if(s.getTokenHash().equals(hash(request.refreshToken()))) s.setRevoked(true);
    }
}
