package com.mealgo.monolith.driver.mapper;
import com.mealgo.monolith.driver.entity.Driver;
import com.mealgo.monolith.driver.dto.DriverDtos.Profile;
import org.springframework.stereotype.Component;
@Component
public class DriverMapper {
    public Profile toResponse(Driver d) { return new Profile(d.getId(),d.getFullName(),d.getPhoneNumber(),
            d.isActive()?"ACTIVE":"SUSPENDED",d.isOnline()?"ONLINE":"OFFLINE",d.getCreatedAt(),d.getUpdatedAt()); }
}
