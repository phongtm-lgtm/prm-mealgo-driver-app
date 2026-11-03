package com.mealgo.monolith.common.dto;

import java.util.List;
import org.springframework.data.domain.Page;
import com.mealgo.monolith.common.exception.ApiException;

public record PageResponse<T>(List<T> items, int page, int size, boolean hasNext) {
    public static <T> PageResponse<T> from(Page<T> page) {
        return new PageResponse<>(page.getContent(), page.getNumber(), page.getSize(), page.hasNext());
    }
    public static void validate(int page, int size) {
        if (page < 0 || size < 1 || size > 100) throw ApiException.badRequest("page >= 0; size must be 1..100");
    }
}
