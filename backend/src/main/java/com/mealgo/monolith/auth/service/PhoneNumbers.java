package com.mealgo.monolith.auth.service;

import com.mealgo.monolith.common.exception.ApiException;

public final class PhoneNumbers {
    private PhoneNumbers() {}

    public static String normalize(String value) {
        String phone = value == null ? "" : value.strip();
        if (!phone.matches("(?:0|\\+84)[35789][0-9]{8}")) {
            throw ApiException.badRequest("Số điện thoại di động Việt Nam không hợp lệ");
        }
        return phone.startsWith("0") ? "+84" + phone.substring(1) : phone;
    }
}
