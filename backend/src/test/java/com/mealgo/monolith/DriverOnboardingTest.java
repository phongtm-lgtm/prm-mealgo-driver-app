package com.mealgo.monolith;
import com.fasterxml.jackson.databind.*;
import com.mealgo.monolith.common.storage.DriverDocumentStorage;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.*;
import org.springframework.mock.web.MockMultipartFile;
import java.util.*;
import java.awt.image.BufferedImage;
import java.io.ByteArrayOutputStream;
import javax.imageio.ImageIO;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;
import static org.junit.jupiter.api.Assertions.*;

@SpringBootTest(properties="app.otp.mock-enabled=true") @AutoConfigureMockMvc @ActiveProfiles("test")
class DriverOnboardingTest {
    @Autowired MockMvc mvc;
    @Autowired ObjectMapper json;
    @MockitoBean DriverDocumentStorage storage;
    @Autowired com.mealgo.monolith.driver.service.DriverAccountService accounts;
    @Autowired com.mealgo.monolith.driver.repository.DriverRepository driverRepository;
    @Autowired com.mealgo.monolith.driver.repository.DriverEarningRepository earningRepository;
    @Autowired com.mealgo.monolith.driver.repository.PendingDriverEarningRepository pendingRepository;
    @Test void missingRateQueuesAndExplicitReconciliationCreditsOnce() throws Exception {
        var driver=driverRepository.findAll().getFirst();
        var id=UUID.randomUUID();
        accounts.completed(driver,id,java.time.Instant.now());
        accounts.completed(driver,id,java.time.Instant.now());
        assertTrue(pendingRepository.existsById(id));
        assertFalse(earningRepository.existsByDeliveryId(id));
        String admin=request("POST","/api/v1/auth/login",Map.of("phoneNumber","0900000004","password","Mealgo123!"),null,200).get("accessToken").asText();
        request("POST","/api/v1/admin/driver-earnings/"+id+"/reconcile",Map.of("amount",15000),admin,200);
        request("POST","/api/v1/admin/driver-earnings/"+id+"/reconcile",Map.of("amount",15000),admin,200);
        assertEquals(0,earningRepository.findByDeliveryId(id).orElseThrow().getAmount().compareTo(new java.math.BigDecimal("15000")));
        assertTrue(pendingRepository.findById(id).orElseThrow().isResolved());
        earningRepository.delete(earningRepository.findByDeliveryId(id).orElseThrow());
        pendingRepository.deleteById(id);
    }
    private JsonNode request(String method,String path,Object body,String token,int status) throws Exception {
        var r=org.springframework.test.web.servlet.request.MockMvcRequestBuilders.request(org.springframework.http.HttpMethod.valueOf(method),path)
            .contentType("application/json");
        if(body!=null) r.content(json.writeValueAsString(body));
        if(token!=null) r.header("Authorization","Bearer "+token);
        var text=mvc.perform(r).andExpect(status().is(status)).andReturn().getResponse().getContentAsString();
        return text.isEmpty()?json.nullNode():json.readTree(text);
    }
    @Test void refreshRotationReplayAndLogout() throws Exception {
        var login=request("POST","/api/v1/auth/login",Map.of("phoneNumber","0900000004","password","Mealgo123!"),null,200);
        String first=login.get("refreshToken").asText();
        var refreshed=request("POST","/api/v1/auth/refresh",Map.of("refreshToken",first),null,200);
        String second=refreshed.get("refreshToken").asText();
        assertNotEquals(first,second);
        request("POST","/api/v1/auth/refresh",Map.of("refreshToken",first),null,401);
        request("POST","/api/v1/auth/refresh",Map.of("refreshToken",second),null,401);
        var other=request("POST","/api/v1/auth/login",Map.of("phoneNumber","0900000004","password","Mealgo123!"),null,200);
        String token=other.get("refreshToken").asText();
        request("POST","/api/v1/auth/logout",Map.of("refreshToken",token),null,204);
        request("POST","/api/v1/auth/refresh",Map.of("refreshToken",token),null,401);
        request("POST","/api/v1/auth/refresh",Map.of("refreshToken","invalid"),null,401);
    }
    @Test void otpApplicationAndAdminApproval() throws Exception {
        String phone="0934567890",password="Password123!";
        var challenge=request("POST","/api/v1/auth/register/start",Map.of("phoneNumber",phone,"password",password),null,200);
        String id=challenge.get("registrationId").asText(),otp=challenge.get("devOtp").asText();
        request("POST","/api/v1/auth/login",Map.of("phoneNumber",phone,"password",password),null,401);
        request("POST","/api/v1/auth/register/resend",Map.of("registrationId",id),null,409);
        request("POST","/api/v1/auth/register/verify",Map.of("registrationId",id,"otp","invalid"),null,400);
        String token=request("POST","/api/v1/auth/register/verify",Map.of("registrationId",id,"otp",otp),null,200).get("accessToken").asText();
        request("POST","/api/v1/auth/register/verify",Map.of("registrationId",id,"otp",otp),null,400);
        request("POST","/api/v1/auth/register",Map.of("phoneNumber","0934567891","password",password,"role","DRIVER"),null,400);
        request("POST","/api/v1/auth/register",Map.of("phoneNumber","0934567892","password",password,"role","ADMIN"),null,400);
        request("PUT","/api/v1/drivers/me/online-status",Map.of("online",true),token,404);
        var draft=request("GET","/api/v1/drivers/me/application",null,token,200);
        String application=draft.get("applicationId").asText();
        request("POST","/api/v1/drivers/me/application/submit",null,token,400);
        request("PUT","/api/v1/drivers/me/application",Map.of("fullName","New Driver","birthDate","2000-01-01","address","HCMC","identityNumber","012345678901","vehicleType","Motorbike","licensePlate","59A-12345","drivingLicense","123456789"),token,200);
        var image=new ByteArrayOutputStream(); ImageIO.write(new BufferedImage(2,2,BufferedImage.TYPE_INT_RGB),"png",image);
        for(String type:List.of("IDENTITY_FRONT","IDENTITY_BACK","VEHICLE_REGISTRATION","DRIVING_LICENSE"))
            mvc.perform(multipart("/api/v1/drivers/me/application/documents/"+type)
                .file(new MockMultipartFile("image","proof.png","image/png",image.toByteArray()))
                .header("Authorization","Bearer "+token)).andExpect(status().isOk());
        request("POST","/api/v1/drivers/me/application/submit",null,token,200);
        request("POST","/api/v1/admin/driver-applications/"+application+"/approve",Map.of("note","valid"),token,403);
        String admin=request("POST","/api/v1/auth/login",Map.of("phoneNumber","0900000004","password","Mealgo123!"),null,200).get("accessToken").asText();
        var approved=request("POST","/api/v1/admin/driver-applications/"+application+"/approve",Map.of("note","valid"),admin,200);
        assertEquals("APPROVED",approved.get("status").asText());
        request("POST","/api/v1/admin/driver-applications/"+application+"/approve",Map.of("note","valid"),admin,200);
        request("PUT","/api/v1/drivers/me/online-status",Map.of("online",true),token,200);
    }
}
