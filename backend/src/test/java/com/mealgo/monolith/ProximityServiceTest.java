package com.mealgo.monolith;

import com.mealgo.monolith.delivery.service.ProximityService;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

class ProximityServiceTest {
    @Test void samePointHasZeroDistance() {
        assertEquals(0,ProximityService.distance(10.7626,106.6823,10.7626,106.6823),0.001);
    }
    @Test void distanceIsSymmetricAndMeasuredInMeters() {
        double forward=ProximityService.distance(0,0,0,1);
        double backward=ProximityService.distance(0,1,0,0);
        assertEquals(111195,forward,10);
        assertEquals(forward,backward,0.001);
    }
}
