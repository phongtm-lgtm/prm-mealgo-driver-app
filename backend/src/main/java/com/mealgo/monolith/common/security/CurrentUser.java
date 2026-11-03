package com.mealgo.monolith.common.security;
import java.util.UUID;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;
@Component
public class CurrentUser {
    public UUID id() { return UUID.fromString(SecurityContextHolder.getContext().getAuthentication().getName()); }
}
