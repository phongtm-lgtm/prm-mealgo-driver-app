package com.mealgo.monolith.auth.service;

import com.mealgo.monolith.auth.dto.AuthDtos.Token;
import com.mealgo.monolith.auth.entity.*;
import com.mealgo.monolith.auth.repository.UserAccountRepository;
import com.mealgo.monolith.common.exception.ApiException;
import jakarta.validation.constraints.*;
import java.security.SecureRandom;
import java.time.Instant;
import java.util.*;
import java.util.concurrent.ConcurrentHashMap;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.env.Environment;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;

@Service
public class MockRegistrationService {
    public record Start(@NotBlank String phoneNumber,@NotBlank @Size(min=8,max=72) String password) {}
    public record Verify(@NotNull UUID registrationId,@NotBlank String otp) {}
    public record Resend(@NotNull UUID registrationId) {}
    public record Challenge(UUID registrationId,String mode,String devOtp,Instant expiresAt,Instant resendAt) {}
    private static class Pending {
        String phone,hash,otp; Instant expires,sent; int attempts;
    }
    private final Map<UUID,Pending> pending=new ConcurrentHashMap<>();
    private final Map<String,Instant> lastSent=new ConcurrentHashMap<>();
    private final SecureRandom random=new SecureRandom();
    private final UserAccountRepository users;
    private final PasswordEncoder passwords;
    private final AuthService auth;
    private final boolean enabled;
    public MockRegistrationService(UserAccountRepository users,PasswordEncoder passwords,AuthService auth,
            @Value("${app.otp.mock-enabled:false}") boolean enabled,Environment environment) {
        this.users=users; this.passwords=passwords; this.auth=auth; this.enabled=enabled;
        if(enabled && (environment.matchesProfiles("prod", "production") || !environment.matchesProfiles("local", "docker", "test")))
            throw new IllegalStateException("Mock OTP is only allowed in local/docker/test profiles");
    }
    public synchronized Challenge start(Start r) {
        if(!enabled) throw ApiException.badRequest("Mock OTP is disabled");
        var now=Instant.now();
        pending.entrySet().removeIf(e->e.getValue().expires.isBefore(now));
        lastSent.entrySet().removeIf(e->e.getValue().isBefore(now.minusSeconds(3600)));
        if(pending.size()>=1000 || lastSent.size()>=10000) throw ApiException.conflict("Please try again later");
        var phone=PhoneNumbers.normalize(r.phoneNumber());
        if(users.existsByPhoneNumber(phone)) throw ApiException.conflict("Số điện thoại đã được đăng ký");
        if(lastSent.getOrDefault(phone,Instant.EPOCH).isAfter(now.minusSeconds(60)))
            throw ApiException.conflict("Vui lòng chờ 60 giây trước khi gửi lại");
        pending.entrySet().removeIf(e->e.getValue().phone.equals(phone));
        var p=new Pending(); p.phone=phone; p.hash=passwords.encode(r.password());
        var id=UUID.randomUUID(); pending.put(id,p); return issue(id,p);
    }
    private Challenge issue(UUID id,Pending p) {
        String otp=String.format("%06d",random.nextInt(1000000)); p.otp=passwords.encode(otp); p.sent=Instant.now(); p.expires=p.sent.plusSeconds(300); p.attempts=0;
        lastSent.put(p.phone,p.sent);
        return new Challenge(id,"MOCK_DEVELOPMENT_ONLY",otp,p.expires,p.sent.plusSeconds(60));
    }
    public synchronized Challenge resend(Resend r) {
        var p=get(r.registrationId());
        if(p.sent.plusSeconds(60).isAfter(Instant.now())) throw ApiException.conflict("Vui lòng chờ trước khi gửi lại");
        return issue(r.registrationId(),p);
    }
    private Pending get(UUID id) {
        var p=pending.get(id);
        if(p==null || p.expires.isBefore(Instant.now())) throw ApiException.badRequest("Phiên OTP đã hết hạn. Vui lòng đăng ký lại");
        return p;
    }
    public synchronized Token verify(Verify r) {
        var p=get(r.registrationId());
        if(p.attempts>=5) throw ApiException.conflict("Đã nhập sai quá 5 lần. Vui lòng gửi lại mã");
        p.attempts++;
        if(!passwords.matches(r.otp(),p.otp)) throw ApiException.badRequest("Mã OTP không đúng");
        if(users.existsByPhoneNumber(p.phone)) throw ApiException.conflict("Số điện thoại đã được đăng ký");
        var u=new UserAccount(); u.setUsername(UUID.randomUUID().toString()); u.setPhoneNumber(p.phone);
        u.setPasswordHash(p.hash); u.setRole(Role.DRIVER);
        var result=auth.token(users.saveAndFlush(u)); pending.remove(r.registrationId()); return result;
    }
}
