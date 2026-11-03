package com.mealgo.monolith;

import com.fasterxml.jackson.databind.*;
import com.mealgo.monolith.delivery.service.DispatchService;
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

@SpringBootTest @AutoConfigureMockMvc @ActiveProfiles("test")
class OrderDeliveryFlowTest {
    @Autowired MockMvc mvc;
    @Autowired ObjectMapper json;
    @Autowired RestaurantRepository restaurants;
    @Autowired MenuItemRepository menu;
    @Autowired DispatchService dispatch;
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
                "dropoff",Map.of("address","Delivery address","latitude",10.78,"longitude",106.70),"paymentMethod","COD");
        String key=UUID.randomUUID().toString();
        var placed=call(post("/api/v1/customers/me/orders").header("Idempotency-Key",key).content(json.writeValueAsString(body)),customer,201);
        String id=placed.get("orderId").asText(); assertEquals(105000,placed.get("total").asInt());
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
        location(driver,session,1,10.7626,106.6823);
        call(post(path+"/arrive-at-pickup"),driver,200);
        call(post(path+"/confirm-pickup"),driver,409);
        call(post(merchantPath+"/ready"),merchant,200);
        call(post(path+"/confirm-pickup"),driver,200);
        location(driver,session,2,10.78,106.70);
        call(post(path+"/arrive-at-dropoff"),driver,200);
        call(post(path+"/confirm-delivery"),driver,200);
        call(post(path+"/confirm-delivery"),driver,200);
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
        location(driver,session,3,10.7626,106.6823);
        call(post(secondPath+"/arrive-at-pickup"),driver,200);
        call(post(secondMerchant+"/ready"),merchant,200);
        call(post(secondPath+"/confirm-pickup"),driver,200);
        location(driver,session,4,10.78,106.70);
        call(post(secondPath+"/arrive-at-dropoff"),driver,200);
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
