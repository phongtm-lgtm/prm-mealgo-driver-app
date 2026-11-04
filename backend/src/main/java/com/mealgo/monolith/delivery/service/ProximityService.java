package com.mealgo.monolith.delivery.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.mealgo.monolith.common.exception.ApiException;
import com.mealgo.monolith.driver.entity.Driver;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.time.Instant;
import java.util.Locale;

@Slf4j
@Service
@RequiredArgsConstructor
public class ProximityService {
    @Value("${app.delivery.radius-meters}") private double radius;
    @Value("${app.delivery.max-accuracy-meters}") private double maxAccuracy;
    @Value("${app.delivery.location-max-age-seconds}") private long maxAge;
    @Value("${app.delivery.vietmap-route-key:}") private String vietmapRouteKey;
    @Value("${app.delivery.vietmap-routing-url:https://maps.vietmap.vn/api/route}") private String vietmapRoutingUrl;

    private final ObjectMapper objectMapper;
    private final HttpClient httpClient = HttpClient.newBuilder()
            .connectTimeout(Duration.ofSeconds(3))
            .build();

    public void requireNear(Driver d, double latitude, double longitude) {
        if (d.getRecordedAt() == null || d.getRecordedAt().isBefore(Instant.now().minusSeconds(maxAge))
                || d.getAccuracyMeters() == null || d.getAccuracyMeters() > maxAccuracy
                || d.getLatitude() == null || d.getLongitude() == null) {
            throw ApiException.conflict("A fresh, accurate GPS location is required");
        }
        if (routingDistanceMeters(d.getLatitude(), d.getLongitude(), latitude, longitude) > radius) {
            throw ApiException.conflict("Driver is outside the permitted radius");
        }
    }

    public double routingDistanceMeters(double lat1, double lon1, double lat2, double lon2) {
        if (vietmapRouteKey != null && !vietmapRouteKey.isBlank()) {
            try {
                var uri = URI.create(String.format(Locale.ROOT,
                        "%s?api-version=1.1&apikey=%s&point=%f,%f&point=%f,%f&vehicle=motorcycle",
                        vietmapRoutingUrl, vietmapRouteKey, lat1, lon1, lat2, lon2));
                var request = HttpRequest.newBuilder(uri)
                        .timeout(Duration.ofSeconds(4))
                        .GET()
                        .build();
                var response = httpClient.send(request, HttpResponse.BodyHandlers.ofString());
                if (response.statusCode() == 200) {
                    var root = objectMapper.readTree(response.body());
                    var paths = root.path("paths");
                    if (paths.isArray() && !paths.isEmpty()) {
                        double distance = paths.get(0).path("distance").asDouble(-1);
                        if (distance >= 0) {
                            return distance;
                        }
                    }
                } else {
                    log.warn("Vietmap route request returned status {}", response.statusCode());
                }
            } catch (Exception e) {
                log.warn("Failed to get Vietmap route distance: {}", e.getMessage());
            }
        }
        return distance(lat1, lon1, lat2, lon2);
    }

    public static double distance(double lat1, double lon1, double lat2, double lon2) {
        double a = Math.pow(Math.sin(Math.toRadians(lat2 - lat1) / 2), 2)
                + Math.cos(Math.toRadians(lat1)) * Math.cos(Math.toRadians(lat2)) * Math.pow(Math.sin(Math.toRadians(lon2 - lon1) / 2), 2);
        return 6371000 * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(Math.max(0, 1 - a)));
    }
}
