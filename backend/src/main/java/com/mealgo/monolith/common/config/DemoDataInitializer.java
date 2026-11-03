package com.mealgo.monolith.common.config;
import com.mealgo.monolith.auth.entity.*;
import com.mealgo.monolith.auth.repository.UserAccountRepository;
import com.mealgo.monolith.driver.entity.Driver;
import com.mealgo.monolith.driver.repository.DriverRepository;
import com.mealgo.monolith.restaurant.entity.*;
import com.mealgo.monolith.restaurant.repository.*;
import lombok.RequiredArgsConstructor;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;
import java.math.BigDecimal;
@Component @RequiredArgsConstructor @ConditionalOnProperty(name="app.seed.enabled",havingValue="true")
public class DemoDataInitializer implements ApplicationRunner {
    private final UserAccountRepository users;
    private final DriverRepository drivers;
    private final RestaurantRepository restaurants;
    private final MenuItemRepository menu;
    private final PasswordEncoder passwords;
    @Override @Transactional public void run(ApplicationArguments args) {
        account("customer.demo","+84900000003",Role.CUSTOMER);
        var merchant = account("merchant.demo","+84900000002",Role.MERCHANT);
        var user = account("driver.demo","+84900000001",Role.DRIVER);
        if (!drivers.existsByUserId(user.getId())) {
            var d = new Driver(); d.setUserId(user.getId()); d.setFullName("Demo Driver"); d.setPhoneNumber("0900000001"); drivers.save(d);
        }
        if (restaurants.count()==0) {
            var r = new Restaurant(); r.setOwnerId(merchant.getId()); r.setName("MealGo Demo Restaurant");
            r.setPhone("0900000002"); r.setAddress("123 Nguyen Trai, Ho Chi Minh City"); r.setLatitude(10.7626); r.setLongitude(106.6823);
            restaurants.save(r);
            var item = new MenuItem(); item.setRestaurantId(r.getId()); item.setName("Com ga"); item.setPrice(new BigDecimal("45000")); menu.save(item);
        }
    }
    private UserAccount account(String username,String phoneNumber,Role role) {
        var account = users.findByUsername(username).orElseGet(() -> {
            var u = new UserAccount(); u.setUsername(username); u.setRole(role); u.setPasswordHash(passwords.encode("Mealgo123!")); return users.save(u);
        });
        if (account.getPhoneNumber() == null) {
            account.setPhoneNumber(phoneNumber);
            users.save(account);
        }
        return account;
    }
}
