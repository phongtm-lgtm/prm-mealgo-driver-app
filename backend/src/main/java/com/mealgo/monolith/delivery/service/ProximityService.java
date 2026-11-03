package com.mealgo.monolith.delivery.service;
import com.mealgo.monolith.common.exception.ApiException;
import com.mealgo.monolith.driver.entity.Driver;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import java.time.Instant;
@Service
public class ProximityService {
    @Value("${app.delivery.radius-meters}") private double radius;
    @Value("${app.delivery.max-accuracy-meters}") private double maxAccuracy;
    @Value("${app.delivery.location-max-age-seconds}") private long maxAge;
    public void requireNear(Driver d,double latitude,double longitude) {
        if (d.getRecordedAt()==null || d.getRecordedAt().isBefore(Instant.now().minusSeconds(maxAge))
                || d.getAccuracyMeters()==null || d.getAccuracyMeters()>maxAccuracy
                || d.getLatitude()==null || d.getLongitude()==null)
            throw ApiException.conflict("A fresh, accurate GPS location is required");
        if (distance(d.getLatitude(),d.getLongitude(),latitude,longitude)>radius)
            throw ApiException.conflict("Driver is outside the permitted radius");
    }
    public static double distance(double lat1,double lon1,double lat2,double lon2) {
        double a = Math.pow(Math.sin(Math.toRadians(lat2-lat1)/2),2)
                +Math.cos(Math.toRadians(lat1))*Math.cos(Math.toRadians(lat2))*Math.pow(Math.sin(Math.toRadians(lon2-lon1)/2),2);
        return 6371000*2*Math.atan2(Math.sqrt(a),Math.sqrt(Math.max(0,1-a)));
    }
}
