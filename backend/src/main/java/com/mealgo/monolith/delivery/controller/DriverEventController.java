package com.mealgo.monolith.delivery.controller;

import com.mealgo.monolith.delivery.service.DriverEventService;
import com.mealgo.monolith.driver.service.DriverService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.MediaType;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.servlet.mvc.method.annotation.SseEmitter;

@RestController
@RequestMapping("/api/v1/drivers/me/events")
@RequiredArgsConstructor
@PreAuthorize("hasRole('DRIVER')")
public class DriverEventController {
    private final DriverService drivers;
    private final DriverEventService events;

    @GetMapping(produces = MediaType.TEXT_EVENT_STREAM_VALUE)
    public SseEmitter subscribe() {
        return events.subscribe(drivers.myDriver().getId());
    }
}
