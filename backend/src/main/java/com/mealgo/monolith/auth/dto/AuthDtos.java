package com.mealgo.monolith.auth.dto;
import jakarta.validation.constraints.*;
import com.mealgo.monolith.auth.entity.Role;
import java.util.UUID;
public final class AuthDtos {
    private AuthDtos() {}
    public record Register(@NotBlank @Size(max=32) String phoneNumber,
                           @NotBlank @Size(min=8,max=72) String password, @NotNull Role role) {}
    public record Login(@NotBlank @Size(max=32) String phoneNumber, @NotBlank @Size(max=72) String password) {}
    public record Token(String accessToken, String tokenType, long expiresIn, UUID userId, Role role) {}
}
