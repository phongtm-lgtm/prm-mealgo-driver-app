package com.mealgo.monolith.common.config;
import com.mealgo.monolith.auth.entity.*;
import com.mealgo.monolith.auth.repository.UserAccountRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Profile;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;
@Component @Profile({"local","docker","test"}) @RequiredArgsConstructor
@ConditionalOnProperty(name="app.seed.enabled",havingValue="true")
public class DevelopmentAdminInitializer implements ApplicationRunner {
    private final UserAccountRepository users;
    private final PasswordEncoder passwords;
    public void run(ApplicationArguments args) {
        if(users.findByPhoneNumber("+84900000004").isEmpty()) {
            var u=new UserAccount(); u.setUsername("admin.demo"); u.setPhoneNumber("+84900000004");
            u.setRole(Role.ADMIN); u.setPasswordHash(passwords.encode("Mealgo123!")); users.save(u);
        }
    }
}
