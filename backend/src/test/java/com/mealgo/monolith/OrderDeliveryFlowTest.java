package com.mealgo.monolith;

import com.fasterxml.jackson.databind.*;
import com.mealgo.monolith.delivery.service.DispatchService;
import com.mealgo.monolith.delivery.enums.AssignmentStatus;
import com.mealgo.monolith.delivery.repository.AssignmentRepository;
import com.mealgo.monolith.driver.entity.Driver;
import com.mealgo.monolith.driver.repository.DriverRepository;
import com.mealgo.monolith.restaurant.repository.*;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.*;
import org.springframework.http.MediaType;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import com.mealgo.monolith.common.storage.EvidenceStorage;
import org.springframework.mock.web.MockMultipartFile;
import java.awt.image.BufferedImage;
import javax.imageio.ImageIO;
import java.io.ByteArrayOutputStream;
import java.time.Instant;
import java.util.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

@SpringBootTest(properties="app.driver.earning-per-delivery=15000") @AutoConfigureMockMvc @ActiveProfiles("test")
class OrderDeliveryFlowTest {
    @Autowired MockMvc mvc;
    @Autowired ObjectMapper json;
    @Autowired RestaurantRepository restaurants;
    @Autowired MenuItemRepository menu;
    @Autowired DispatchService dispatch;
    @Autowired AssignmentRepository assignments;
    @Autowired DriverRepository drivers;
    @Autowired com.mealgo.monolith.delivery.service.DeliveryService deliveries;
    @Autowired com.mealgo.monolith.order.repository.OrderRepository orderRows;
    @Autowired org.springframework.security.oauth2.jwt.JwtEncoder jwtEncoder;
    @MockitoBean EvidenceStorage storage;

    @Test void phoneLoginNormalizationAndValidation() throws Exception {
        var local=call(post("/api/v1/auth/login").content("{\"phoneNumber\":\"0900000001\",\"password\":\"Mealgo123!\"}"),null,200);
        var international=call(post("/api/v1/auth/login").content("{\"phoneNumber\":\"+84900000001\",\"password\":\"Mealgo123!\"}"),null,200);
        assertEquals(local.get("userId"),international.get("userId"));
        assertEquals("Bearer",local.get("tokenType").asText());
        call(post("/api/v1/auth/login").content("{\"phoneNumber\":\"driver.demo\",\"password\":\"Mealgo123!\"}"),null,400);
        call(post("/api/v1/auth/login").content("{\"phoneNumber\":\"0911111111\",\"password\":\"Mealgo123!\"}"),null,401);
        call(post("/api/v1/auth/login").content("{\"username\":\"driver.demo\",\"password\":\"Mealgo123!\"}"),null,400);
        call(post("/api/v1/auth/register").content("{\"phoneNumber\":\"+84900000001\",\"password\":\"Password123!\",\"role\":\"DRIVER\"}"),null,409);
        var registered=call(post("/api/v1/auth/register").content("{\"phoneNumber\":\"0932222222\",\"password\":\"Password123!\",\"role\":\"CUSTOMER\"}"),null,201);
        var loggedIn=call(post("/api/v1/auth/login").content("{\"phoneNumber\":\"+84932222222\",\"password\":\"Password123!\"}"),null,200);
        assertEquals(registered.get("userId"),loggedIn.get("userId"));
        call(post("/api/v1/auth/register").content("{\"phoneNumber\":\"+84932222222\",\"password\":\"Password123!\",\"role\":\"CUSTOMER\"}"),null,409);
        call(get("/api/v1/drivers/me"),"invalid.jwt.token",401);
    }

    @Test void expiredJwtIsRejected() throws Exception {
        var claims=org.springframework.security.oauth2.jwt.JwtClaimsSet.builder()
                .issuer("mealgo").subject(UUID.randomUUID().toString())
                .issuedAt(Instant.now().minusSeconds(7200)).expiresAt(Instant.now().minusSeconds(3600))
                .claim("roles",List.of("DRIVER")).build();
        var header=org.springframework.security.oauth2.jwt.JwsHeader.with(org.springframework.security.oauth2.jose.jws.MacAlgorithm.HS256).build();
        String token=jwtEncoder.encode(org.springframework.security.oauth2.jwt.JwtEncoderParameters.from(header,claims)).getTokenValue();
        call(get("/api/v1/drivers/me"),token,401);
    }

    @Test void faceVerificationAlwaysSucceedsForAuthenticatedDriver() throws Exception {
        String path="/api/v1/drivers/me/face-verification";
        byte[] image="stub-image-no-biometric-analysis".getBytes(java.nio.charset.StandardCharsets.UTF_8);
        mvc.perform(multipart(path).file(new MockMultipartFile("image","face.jpg","image/jpeg",image)))
                .andExpect(status().isUnauthorized());
        mvc.perform(multipart(path).file(new MockMultipartFile("image","face.jpg","image/jpeg",image))
                .header("Authorization","Bearer "+login("customer.demo")))
                .andExpect(status().isForbidden());
        String driver=login("driver.demo");
        mvc.perform(multipart(path).file(new MockMultipartFile("image","face.jpg","image/jpeg",image))
                .header("Authorization","Bearer "+driver))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.success").value(true))
                .andExpect(jsonPath("$.mode").value("MOCK_ALWAYS_SUCCESS"))
                .andExpect(jsonPath("$.checkedAt").exists());
        mvc.perform(multipart(path).file(new MockMultipartFile("image","face.jpg","image/jpeg",new byte[0]))
                .header("Authorization","Bearer "+driver))
                .andExpect(status().isBadRequest());
    }

    @Test void authenticationAndValidation() throws Exception {
        mvc.perform(options("/api/v1/drivers/me")
                .header("Origin","http://127.0.0.1:5173")
                .header("Access-Control-Request-Method","GET")
                .header("Access-Control-Request-Headers","authorization"))
                .andExpect(status().isOk())
                .andExpect(header().string("Access-Control-Allow-Origin","http://127.0.0.1:5173"));
        call(get("/api/v1/customers/me/orders"),null,401);
        call(post("/api/v1/auth/login").content("{\"phoneNumber\":\"0900000003\",\"password\":\"incorrect\"}"),null,401);
        call(post("/api/v1/auth/register").content("{\"phoneNumber\":\"0912345678\",\"password\":\"Password123!\",\"role\":\"MERCHANT\"}"),null,400);
        String customer=login("customer.demo");
        call(get("/api/v1/customers/me/orders?size=101"),customer,400);
        call(post("/api/v1/customers/me/orders").content("{}"),customer,400);
    }

    @Test void driverAccountSettingsAndAuthorization() throws Exception {
        String driver=login("driver.demo"), customer=login("customer.demo");
        String base="/api/v1/drivers/me";
        for(String endpoint:List.of("/order-settings","/app-settings","/wallet","/earnings","/notifications","/wallet/transactions")) {
            call(get(base+endpoint),null,401); call(get(base+endpoint),customer,403); call(get(base+endpoint),driver,200);
        }
        String settings="{\"autoAcceptEnabled\":true,\"maxDeliveryDistanceKm\":20,\"maxItemQuantity\":10,\"maxRestaurantAdvanceAmount\":200000}";
        call(put(base+"/order-settings").content(settings),driver,200);
        assertEquals(20,call(get(base+"/order-settings"),driver,200).get("maxDeliveryDistanceKm").asInt());
        call(put(base+"/order-settings").content("{}"),driver,400);
        call(put(base+"/app-settings").content("{\"inAppNotificationsEnabled\":false}"),driver,200);
        assertFalse(call(get(base+"/app-settings"),driver,200).get("inAppNotificationsEnabled").asBoolean());
        call(put(base+"/app-settings").content("{\"inAppNotificationsEnabled\":true}"),driver,200);
        call(get(base+"/notifications?size=101"),driver,400);
        call(get(base+"/wallet/transactions/"+UUID.randomUUID()),driver,404);
        call(patch(base+"/notifications/"+UUID.randomUUID()+"/read"),driver,404);
        call(get(base+"/earnings?period=WEEK&date=2026-11-03"),driver,200);
        call(get(base+"/earnings?period=INVALID"),driver,400);
    }

    @Test @org.springframework.transaction.annotation.Transactional
    void twoCustomersCanUseTheSameFourDishMenuWithSeparateCarts() throws Exception {
        String a = login("customer.demo");
        var b = call(post("/api/v1/auth/login").content("{\"phoneNumber\":\"0900000005\",\"password\":\"Mealgo123!\"}"), null, 200);
        String bToken = b.get("accessToken").asText();
        String path = "/api/v1/customers/menu";
        call(get(path).param("restaurantName", "MealGo Demo Restaurant"), login("driver.demo"), 403);
        call(get(path), a, 400);
        var catalog = call(get(path).param("restaurantName", "MealGo Demo Restaurant"), a, 200);
        assertEquals(1, catalog.size());
        var items = catalog.get(0).get("items");
        assertEquals(4, items.size());
        Map<String, Integer> prices = Map.of("Com ga", 45000, "Bún bò Huế", 55000, "Bánh mì thịt", 30000, "Trà sữa trân châu", 35000);
        for (var item : items) assertEquals(prices.get(item.get("name").asText()), item.get("price").asInt());
        var body = Map.of("menuItemId", items.get(0).get("menuItemId").asText(), "quantity", 1, "note", "Ít cay");
        String cartPath = "/api/v1/customers/me/cart";
        call(delete(cartPath), a, 204);
        call(delete(cartPath), bToken, 204);
        var cart = call(post(cartPath + "/items").content(json.writeValueAsString(body)), bToken, 200);
        assertEquals("Ít cay", cart.get("items").get(0).get("note").asText());
        assertTrue(call(get(cartPath), a, 200).get("items").isEmpty());
    }

    @Test void customerCartOwnershipValidationAndPricing() throws Exception {
        String customer=login("customer.demo");
        String path="/api/v1/customers/me/cart";
        var item=menu.findAll().getFirst();
        call(get(path),null,401);
        call(get(path),login("driver.demo"),403);
        call(delete(path),customer,204);
        var empty=call(get(path),customer,200);
        assertEquals(0,empty.get("items").size());
        String body=json.writeValueAsString(Map.of("menuItemId",item.getId(),"quantity",2,"note","Không cay"));
        var cart=call(post(path+"/items").content(body),customer,200);
        assertEquals(0,item.getPrice().multiply(new java.math.BigDecimal("2")).compareTo(cart.get("subtotal").decimalValue()));
        cart=call(post(path+"/items").content(body),customer,200);
        assertEquals(4,cart.get("items").get(0).get("quantity").asInt());
        call(put(path+"/items/"+item.getId()).content("{\"quantity\":0}"),customer,400);
        cart=call(put(path+"/items/"+item.getId()).content("{\"quantity\":1}"),customer,200);
        assertEquals(1,cart.get("items").get(0).get("quantity").asInt());
        var other=call(post("/api/v1/auth/register").content("{\"phoneNumber\":\"0932222233\",\"password\":\"Password123!\",\"role\":\"CUSTOMER\"}"),null,201);
        String token=other.get("accessToken").asText();
        assertEquals(0,call(get(path),token,200).get("items").size());
        call(put(path+"/items/"+item.getId()).content("{\"quantity\":1}"),token,404);
        call(delete(path+"/items/"+item.getId()),customer,204);
        assertEquals(0,call(get(path),customer,200).get("total").decimalValue().signum());
    }

    @Test void completeFlowAndAccessControl() throws Exception {
        String customer=login("customer.demo"), merchant=login("merchant.demo"), driver=login("driver.demo");
        var restaurant=restaurants.findAll().getFirst(); var item=menu.findAll().getFirst();
        Map<String,Object> body=Map.of("restaurantId",restaurant.getId(),"items",List.of(Map.of("menuItemId",item.getId(),"quantity",2)),
                "recipient",Map.of("name","Customer","phone","0901234567"),
                "dropoff",Map.of("address","Delivery address","latitude",21.05,"longitude",105.54),"paymentMethod","COD");
        String key=UUID.randomUUID().toString();
        var placed=call(post("/api/v1/customers/me/orders").header("Idempotency-Key",key).content(json.writeValueAsString(body)),customer,201);
        String id=placed.get("orderId").asText(); assertEquals(item.getPrice().intValueExact()*2+15000,placed.get("total").asInt());
        var retry=call(post("/api/v1/customers/me/orders").header("Idempotency-Key",key).content(json.writeValueAsString(body)),customer,201);
        assertEquals(id,retry.get("orderId").asText());
        call(get("/api/v1/drivers/me"),customer,403);
        String stranger=registerCustomer();
        call(get("/api/v1/customers/me/orders/"+id),stranger,404);
        String merchantPath="/api/v1/merchant/restaurants/"+restaurant.getId()+"/orders/"+id;
        call(post(merchantPath+"/accept").content("{\"estimatedPreparationMinutes\":20}"),merchant,200);
        call(post("/api/v1/customers/me/orders/"+id+"/cancel").content("{\"reason\":\"test\"}"),customer,409);
        call(put("/api/v1/drivers/me/online-status").content("{\"online\":true}"),driver,200);
        dispatch.dispatch();
        var offers=call(get("/api/v1/drivers/me/offers"),driver,200); assertFalse(offers.isEmpty());
        String assignment=offers.get(0).get("assignmentId").asText();
        call(post("/api/v1/drivers/me/offers/"+assignment+"/accept"),driver,200);
        var current=call(get("/api/v1/drivers/me/deliveries/current"),driver,200);
        String delivery=current.get("deliveryId").asText(); assertEquals(assignment,current.get("assignmentId").asText());
        String path="/api/v1/drivers/me/deliveries/"+delivery;
        call(post(path+"/arrive-at-pickup"),driver,409);
        String session=call(post("/api/v1/drivers/me/tracking-session"),driver,201).get("trackingSessionId").asText();
        location(driver,session,1,21.038214,105.547018);
        call(post(path+"/arrive-at-pickup"),driver,200);
        call(post(path+"/confirm-pickup"),driver,409);
        call(post(merchantPath+"/ready"),merchant,200);
        call(post(path+"/confirm-pickup"),driver,200);
        location(driver,session,2,21.05,105.54);
        call(post(path+"/arrive-at-dropoff"),driver,200);
        call(post(path+"/confirm-delivery"),driver,200);
        call(post(path+"/confirm-delivery"),driver,200);
        assertEquals(15000,call(get("/api/v1/drivers/me/wallet"),driver,200).get("balance").asInt());
        var tx=call(get("/api/v1/drivers/me/wallet/transactions"),driver,200);
        assertEquals(1,tx.get("items").size());
        assertEquals(delivery,tx.get("items").get(0).get("deliveryId").asText());
        call(get("/api/v1/drivers/me/deliveries/history/"+delivery),driver,200);
        call(get("/api/v1/drivers/me/deliveries/history/"+delivery),customer,403);
        var notices=call(get("/api/v1/drivers/me/notifications"),driver,200);
        assertEquals(1,notices.get("items").size());
        String noticeId=notices.get("items").get(0).get("id").asText();
        call(patch("/api/v1/drivers/me/notifications/"+noticeId+"/read"),driver,200);
        assertEquals(0,call(get("/api/v1/drivers/me/notifications/unread-count"),driver,200).get("count").asInt());
        call(patch("/api/v1/drivers/me/notifications/read-all"),driver,204);
        assertEquals(15000,call(get("/api/v1/drivers/me/earnings?period=DAY"),driver,200).get("totalEarnings").asInt());
        call(get("/api/v1/drivers/me/deliveries/current"),driver,204);
        var tracking=call(get("/api/v1/customers/me/orders/"+id+"/tracking"),customer,200);
        assertEquals("DELIVERED",tracking.get("orderStatus").asText()); assertTrue(tracking.get("driverLocation").isNull());
        assertEquals(1,call(get("/api/v1/drivers/me/deliveries/history"),driver,200).get("items").size());

        // A second delivery exercises image upload, failure idempotency and private evidence.
        String second=call(post("/api/v1/customers/me/orders").header("Idempotency-Key",UUID.randomUUID().toString())
                .content(json.writeValueAsString(body)),customer,201).get("orderId").asText();
        String secondMerchant="/api/v1/merchant/restaurants/"+restaurant.getId()+"/orders/"+second;
        call(post(secondMerchant+"/accept").content("{\"estimatedPreparationMinutes\":10}"),merchant,200);
        dispatch.dispatch();
        String secondAssignment=call(get("/api/v1/drivers/me/offers"),driver,200).get(0).get("assignmentId").asText();
        call(post("/api/v1/drivers/me/offers/"+secondAssignment+"/accept"),driver,200);
        String secondDelivery=call(get("/api/v1/drivers/me/deliveries/current"),driver,200).get("deliveryId").asText();
        String secondPath="/api/v1/drivers/me/deliveries/"+secondDelivery;
        location(driver,session,3,21.038214,105.547018);
        call(post(secondPath+"/arrive-at-pickup"),driver,200);
        call(post(secondMerchant+"/ready"),merchant,200);
        call(post(secondPath+"/confirm-pickup"),driver,200);
        mvc.perform(multipart(secondPath+"/incident").param("assignmentId",secondAssignment)
            .param("requestId",UUID.randomUUID().toString()).param("reason","PERSONAL")
            .header("Authorization","Bearer "+driver)).andExpect(status().isConflict());
        location(driver,session,4,21.05,105.54);
        call(post(secondPath+"/arrive-at-dropoff"),driver,200);
        mvc.perform(multipart(secondPath+"/failure-report").param("assignmentId",secondAssignment)
                .param("requestId",UUID.randomUUID().toString()).param("reason","CUSTOMER_UNREACHABLE")
                .header("Authorization","Bearer "+driver)).andExpect(status().isBadRequest());
        call(get("/api/v1/drivers/me/deliveries/current"),driver,200);
        var bytes=new ByteArrayOutputStream(); ImageIO.write(new BufferedImage(2,2,BufferedImage.TYPE_INT_RGB),"png",bytes);
        String requestId=UUID.randomUUID().toString();
        for (int i=0;i<2;i++) mvc.perform(multipart(secondPath+"/failure-report")
                .file(new MockMultipartFile("image","proof.png","image/png",bytes.toByteArray()))
                .param("assignmentId",secondAssignment).param("requestId",requestId).param("reason","CUSTOMER_UNREACHABLE")
                .header("Authorization","Bearer "+driver)).andExpect(status().isOk()).andExpect(jsonPath("$.status").value("FAILED"));
        verify(storage,times(1)).put(anyString(),any(byte[].class),eq("image/png"));
        when(storage.get(anyString())).thenReturn(bytes.toByteArray());
        mvc.perform(get(secondPath+"/failure-report/evidence").header("Authorization","Bearer "+driver))
                .andExpect(status().isOk()).andExpect(content().contentType("image/png"));
        assertEquals("FAILED",call(get("/api/v1/customers/me/orders/"+second),customer,200).get("status").asText());
        call(get("/api/v1/drivers/me/deliveries/current"),driver,204);
        assertEquals("ONLINE",call(get("/api/v1/drivers/me"),driver,200).get("onlineStatus").asText());
        assertEquals(15000,call(get("/api/v1/drivers/me/wallet"),driver,200).get("balance").asInt());
    }
    @Test @org.springframework.transaction.annotation.Transactional void refreshSkipsOnlyDisplayedOffersAndImmediatelyFindsNext() throws Exception {
        String driver = login("driver.demo"), merchant = login("merchant.demo"), customer = login("customer.demo");
        var restaurant = restaurants.findAll().getFirst();
        var item = menu.findAll().getFirst();
        var body = Map.of("restaurantId", restaurant.getId(), "items", List.of(Map.of("menuItemId", item.getId(), "quantity", 1)),
                "recipient", Map.of("name", "Customer", "phone", "0901234567"),
                "dropoff", Map.of("address", "Address", "latitude", 21.05, "longitude", 105.54), "paymentMethod", "COD");
        for (int i = 0; i < 2; i++) {
            String order = call(post("/api/v1/customers/me/orders").header("Idempotency-Key", UUID.randomUUID().toString())
                    .content(json.writeValueAsString(body)), customer, 201).get("orderId").asText();
            call(post("/api/v1/merchant/restaurants/" + restaurant.getId() + "/orders/" + order + "/accept")
                    .content("{\"estimatedPreparationMinutes\":10}"), merchant, 200);
        }
        call(put("/api/v1/drivers/me/online-status").content("{\"online\":true}"), driver, 200);
        String refresh = "/api/v1/drivers/me/offers/refresh";
        String find = "{\"skippedAssignmentIds\":[]}";
        call(post(refresh).content(find), customer, 403);
        call(post(refresh).content("{}"), driver, 400);
        var first = call(post(refresh).content(find), driver, 200).get(0);
        String skipFirst = json.writeValueAsString(Map.of("skippedAssignmentIds", List.of(first.get("assignmentId").asText())));
        var nextOffers = call(post(refresh).content(skipFirst), driver, 200);
        assertEquals(1, nextOffers.size());
        var next = nextOffers.get(0);
        assertTrue(first.hasNonNull("orderId"));
        assertNotEquals(first.get("orderId"), next.get("orderId"));
        assertEquals(restaurant.getName(), next.path("restaurantName").asText());
        assertNotEquals(first.get("deliveryId"), next.get("deliveryId"));
        assertEquals("REJECTED", call(get("/api/v1/drivers/me/offers/" + first.get("assignmentId").asText()), driver, 200).get("status").asText());
        assertEquals(next.get("assignmentId"), call(post(refresh).content(skipFirst), driver, 200).get(0).get("assignmentId"));

        var other = new Driver();
        other.setUserId(UUID.randomUUID()); other.setFullName("Other driver"); other.setPhoneNumber("0901234568");
        other.setOnline(true); drivers.save(other);
        dispatch.dispatch();
        var foreign = assignments.findByDriverIdAndStatusAndExpiresAtAfter(other.getId(), AssignmentStatus.OFFERED, Instant.now()).getFirst();
        assertEquals(first.get("deliveryId").asText(), foreign.getDeliveryId().toString());
        String skipForeign = json.writeValueAsString(Map.of("skippedAssignmentIds", List.of(foreign.getId())));
        assertEquals(next.get("assignmentId"), call(post(refresh).content(skipForeign), driver, 200).get(0).get("assignmentId"));
        assertEquals(AssignmentStatus.OFFERED, foreign.getStatus());

        var expired = assignments.findById(UUID.fromString(next.get("assignmentId").asText())).orElseThrow();
        expired.setExpiresAt(Instant.now().minusSeconds(1));
        String skipExpired = json.writeValueAsString(Map.of("skippedAssignmentIds", List.of(expired.getId())));
        assertTrue(call(post(refresh).content(skipExpired), driver, 200).isEmpty());
        assertEquals(AssignmentStatus.EXPIRED, expired.getStatus());
        dispatch.dispatch();
        assertTrue(call(get("/api/v1/drivers/me/offers"), driver, 200).isEmpty());
    }

    @Test @org.springframework.transaction.annotation.Transactional void incidentReleaseAndClosure() throws Exception {
        String driver=login("driver.demo"), merchant=login("merchant.demo"), customer=login("customer.demo");
        var restaurant=restaurants.findAll().getFirst(); var item=menu.findAll().getFirst();
        var body=Map.of("restaurantId",restaurant.getId(),"items",List.of(Map.of("menuItemId",item.getId(),"quantity",1)),
            "recipient",Map.of("name","Customer","phone","0901234567"),"dropoff",Map.of("address","Address","latitude",21.05,"longitude",105.54),"paymentMethod","COD");
        call(put("/api/v1/drivers/me/online-status").content("{\"online\":true}"),driver,200);
        String session=call(post("/api/v1/drivers/me/tracking-session"),driver,201).get("trackingSessionId").asText();
        location(driver,session,1,21.038214,105.547018);
        for(String reason:List.of("PERSONAL","RESTAURANT_DELAY","RESTAURANT_CLOSED","BAD_WEATHER","VEHICLE_BREAKDOWN","CUSTOMER_UNREACHABLE")) {
            String order=call(post("/api/v1/customers/me/orders").header("Idempotency-Key",UUID.randomUUID().toString()).content(json.writeValueAsString(body)),customer,201).get("orderId").asText();
            call(post("/api/v1/merchant/restaurants/"+restaurant.getId()+"/orders/"+order+"/accept").content("{\"estimatedPreparationMinutes\":10}"),merchant,200);
            dispatch.dispatch();
            String assignment=call(get("/api/v1/drivers/me/offers"),driver,200).get(0).get("assignmentId").asText();
            call(post("/api/v1/drivers/me/offers/"+assignment+"/accept"),driver,200);
            String delivery=call(get("/api/v1/drivers/me/deliveries/current"),driver,200).get("deliveryId").asText();
            String path="/api/v1/drivers/me/deliveries/"+delivery+"/incident", key=UUID.randomUUID().toString();
            boolean needsPhoto = reason.equals("RESTAURANT_CLOSED") || reason.equals("CUSTOMER_UNREACHABLE");
            if(needsPhoto) mvc.perform(multipart(path).param("assignmentId",assignment).param("requestId",key).param("reason",reason)
                .header("Authorization","Bearer "+driver)).andExpect(status().isBadRequest());
            var image=new ByteArrayOutputStream(); ImageIO.write(new BufferedImage(2,2,BufferedImage.TYPE_INT_RGB),"png",image);
            for(int retry=0;retry<2;retry++) {
                var request=multipart(path);
                request.param("assignmentId",assignment).param("requestId",key).param("reason",reason);
                if(needsPhoto) request.file(new MockMultipartFile("image","proof.png","image/png",image.toByteArray()));
                mvc.perform(request.header("Authorization","Bearer "+driver)).andExpect(status().isOk())
                    .andExpect(jsonPath("$.outcome").value("PENDING_REASSIGNMENT"));
            }
            call(get("/api/v1/drivers/me/deliveries/current"),driver,204);
            assertEquals("PREPARING",call(get("/api/v1/customers/me/orders/"+order),customer,200).get("status").asText());
        }
        assertEquals(6,call(get("/api/v1/drivers/me/deliveries/incidents"),driver,200).size());
        call(get("/api/v1/drivers/me/deliveries/incidents"),customer,403);
        var replacement = new Driver();
        replacement.setUserId(UUID.randomUUID()); replacement.setFullName("Replacement"); replacement.setPhoneNumber("0901111012");
        replacement.setOnline(true); drivers.save(replacement);
        dispatch.dispatch();
        assertEquals(1, assignments.findByDriverIdAndStatusAndExpiresAtAfter(replacement.getId(),AssignmentStatus.OFFERED,Instant.now()).size());
        assertTrue(call(get("/api/v1/drivers/me/offers"),driver,200).isEmpty());
    }
    @Test @org.springframework.transaction.annotation.Transactional void cancellationBoundaries() throws Exception {
        String driver=login("driver.demo"), merchant=login("merchant.demo"), customer=login("customer.demo");
        var restaurant=restaurants.findAll().getFirst(); var item=menu.findAll().getFirst();
        var body=Map.of("restaurantId",restaurant.getId(),"items",List.of(Map.of("menuItemId",item.getId(),"quantity",1)),
            "recipient",Map.of("name","Customer","phone","0901234567"),"dropoff",Map.of("address","Address","latitude",21.05,"longitude",105.54),"paymentMethod","COD");
        call(put("/api/v1/drivers/me/online-status").content("{\"online\":true}"),driver,200);
        for(boolean ready:List.of(false,true)) {
            String order=call(post("/api/v1/customers/me/orders").header("Idempotency-Key",UUID.randomUUID().toString()).content(json.writeValueAsString(body)),customer,201).get("orderId").asText();
            String merchantPath="/api/v1/merchant/restaurants/"+restaurant.getId()+"/orders/"+order;
            call(post(merchantPath+"/cancel").content("{\"reason\":\"No ingredients\"}"),merchant,409);
            call(post(merchantPath+"/accept").content("{\"estimatedPreparationMinutes\":10}"),merchant,200);
            call(post("/api/v1/customers/me/orders/"+order+"/cancel").content("{\"reason\":\"Changed mind\"}"),customer,409);
            dispatch.dispatch();
            String assignment=call(get("/api/v1/drivers/me/offers"),driver,200).get(0).get("assignmentId").asText();
            call(post("/api/v1/drivers/me/offers/"+assignment+"/accept"),driver,200);
            String delivery=call(get("/api/v1/drivers/me/deliveries/current"),driver,200).get("deliveryId").asText();
            if(ready) {
                call(post(merchantPath+"/ready"),merchant,200);
                mvc.perform(multipart("/api/v1/drivers/me/deliveries/"+delivery+"/incident")
                    .param("assignmentId",assignment).param("requestId",UUID.randomUUID().toString()).param("reason","PERSONAL")
                    .header("Authorization","Bearer "+driver)).andExpect(status().isConflict());
                call(post(merchantPath+"/cancel").content("{\"reason\":\"No ingredients\"}"),merchant,409);
            } else {
                var result=call(post(merchantPath+"/cancel").content("{\"reason\":\"No ingredients\"}"),merchant,200);
                assertEquals("CANCELLED",result.get("status").asText());
                assertEquals("RESTAURANT_OUT_OF_STOCK",result.get("cancellationCode").asText());
                call(post(merchantPath+"/cancel").content("{\"reason\":\"No ingredients\"}"),merchant,200);
                var history=call(get("/api/v1/drivers/me/deliveries/history/"+delivery),driver,200);
                assertEquals("RESTAURANT_OUT_OF_STOCK",history.get("cancellationCode").asText());
                assertEquals(0,history.get("payment").get("amountToCollect").asInt());
                var notices=cancellationNotices(driver,delivery);
                assertEquals(1,notices.size());
                assertEquals("Nhà hàng đã hủy đơn do hết món",notices.getFirst().get("message").asText());
                call(get("/api/v1/drivers/me/deliveries/current"),driver,204);
                assertEquals(0,call(get("/api/v1/drivers/me/offers"),driver,200).size());
            }
        }
    }
    @Test @org.springframework.transaction.annotation.Transactional void customerCancellationInvalidatesExistingOffersAndAssignments() throws Exception {
        String customer=login("customer.demo"), driver=login("driver.demo");
        var restaurant=restaurants.findAll().getFirst();
        var body=Map.of("restaurantId",restaurant.getId(),"items",List.of(Map.of("menuItemId",menu.findAll().getFirst().getId(),"quantity",1)),
                "recipient",Map.of("name","Customer","phone","0901234567"),"dropoff",Map.of("address","Address","latitude",21.05,"longitude",105.54),"paymentMethod","COD");
        call(put("/api/v1/drivers/me/online-status").content("{\"online\":true}"),driver,200);
        for (boolean accepted : List.of(false,true)) {
            var order=call(post("/api/v1/customers/me/orders").header("Idempotency-Key",UUID.randomUUID().toString())
                    .content(json.writeValueAsString(body)),customer,201).get("orderId").asText();
            // Normal dispatch starts at PREPARING. Exercise an order with an early delivery as well.
            deliveries.create(orderRows.findById(UUID.fromString(order)).orElseThrow());
            dispatch.dispatch();
            var offer=call(get("/api/v1/drivers/me/offers"),driver,200).get(0);
            String assignment=offer.get("assignmentId").asText();
            if (accepted) call(post("/api/v1/drivers/me/offers/"+assignment+"/accept"),driver,200);
            var cancelled=call(post("/api/v1/customers/me/orders/"+order+"/cancel").content("{\"reason\":\"Changed mind\"}"),customer,200);
            assertEquals("CUSTOMER_CANCELLED",cancelled.get("cancellationCode").asText());
            assertEquals("Changed mind",cancelled.get("cancellationReason").asText());
            assertEquals("CANCELLED",call(get("/api/v1/drivers/me/offers/"+assignment),driver,200).get("status").asText());
            assertTrue(call(get("/api/v1/drivers/me/offers"),driver,200).isEmpty());
            call(get("/api/v1/drivers/me/deliveries/current"),driver,204);
            var notices=cancellationNotices(driver,offer.get("deliveryId").asText());
            assertEquals(accepted ? 1 : 0, notices.size());
            if (accepted) {
                var history=call(get("/api/v1/drivers/me/deliveries/history/"+offer.get("deliveryId").asText()),driver,200);
                assertEquals("CUSTOMER_CANCELLED",history.get("cancellationCode").asText());
                assertEquals("Khách hàng đã hủy đơn này",notices.getFirst().get("message").asText());
            }
        }
    }
    private List<JsonNode> cancellationNotices(String driver,String deliveryId) throws Exception {
        var items=call(get("/api/v1/drivers/me/notifications"),driver,200).get("items");
        return items.valueStream().filter(n -> deliveryId.equals(n.path("referenceId").asText())
                && "ORDER_CANCELLED".equals(n.path("type").asText())).toList();
    }
    private String login(String name) throws Exception {
        String phone = switch (name) {
            case "driver.demo" -> "0900000001";
            case "merchant.demo" -> "0900000002";
            case "customer.demo" -> "0900000003";
            default -> throw new IllegalArgumentException(name);
        };
        return call(post("/api/v1/auth/login").content(json.writeValueAsString(Map.of("phoneNumber",phone,"password","Mealgo123!"))),null,200).get("accessToken").asText();
    }
    private String registerCustomer() throws Exception {
        return call(post("/api/v1/auth/register").content(json.writeValueAsString(Map.of("phoneNumber","0987654321","password","Password123!","role","CUSTOMER"))),null,201).get("accessToken").asText();
    }
    private void location(String token,String session,int sequence,double lat,double lon) throws Exception {
        call(put("/api/v1/drivers/me/location").content(json.writeValueAsString(Map.of("trackingSessionId",session,"sequence",sequence,
                "latitude",lat,"longitude",lon,"accuracyMeters",10,"recordedAt",Instant.now().toString()))),token,200);
    }
    private JsonNode call(org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder request,String token,int expected) throws Exception {
        request.contentType(MediaType.APPLICATION_JSON);
        if (token!=null) request.header("Authorization","Bearer "+token);
        String response=mvc.perform(request).andExpect(status().is(expected)).andReturn().getResponse().getContentAsString();
        return response.isEmpty()?json.nullNode():json.readTree(response);
    }
}
