package com.mealgo.monolith;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.util.HashSet;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import static org.junit.jupiter.api.Assertions.*;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

@SpringBootTest
@AutoConfigureMockMvc
@ActiveProfiles("test")
class OpenApiDocumentationTest {
    @Autowired MockMvc mvc;
    @Autowired ObjectMapper json;

    @Test void documentationIsPublicAndEveryOperationHasVietnameseDetails() throws Exception {
        var result = mvc.perform(get("/v3/api-docs")).andExpect(status().isOk()).andReturn();
        JsonNode api = json.readTree(result.getResponse().getContentAsByteArray());
        assertTrue(api.path("openapi").asText().startsWith("3.1."));
        assertTrue(api.path("info").path("title").asText().contains("Tài liệu"));
        assertEquals("bearer", api.at("/components/securitySchemes/bearerAuth/scheme").asText());
        var ids = new HashSet<String>();
        int count = 0;
        var paths = api.path("paths").fields();
        while (paths.hasNext()) {
            var path = paths.next();
            var methods = path.getValue().fields();
            while (methods.hasNext()) {
                var method = methods.next();
                var op = method.getValue();
                assertFalse(op.path("summary").asText().isBlank(), path.getKey());
                assertTrue(op.path("description").asText().length() > 80, path.getKey());
                assertTrue(ids.add(op.path("operationId").asText()), "operationId trùng: " + path.getKey());
                assertEquals(1, op.path("tags").size(), path.getKey());
                var responses = op.path("responses").fields();
                while (responses.hasNext()) {
                    var response = responses.next();
                    String description = response.getValue().path("description").asText();
                    assertFalse(description.isBlank(), path.getKey() + " " + response.getKey());
                    assertFalse(description.contains("Xem schema") || description.contains("xem schema"), path.getKey());
                    assertFalse(description.contains("chưa đủ điều kiện thực hiện"), path.getKey());
                    if (response.getKey().equals("204")) assertFalse(response.getValue().has("content"), path.getKey());
                }
                if (op.has("requestBody")) assertFalse(op.path("requestBody").path("description").asText().isBlank(), path.getKey());
                if (!path.getKey().startsWith("/api/v1/auth/")) {
                    assertEquals("bearerAuth", op.path("security").get(0).fieldNames().next());
                    assertTrue(op.path("responses").has("401"));
                    assertTrue(op.path("responses").has("403"));
                }
                count++;
            }
        }
        assertEquals(69, count, "Phải mô tả tất cả API của 13 controller; cập nhật khi thêm endpoint.");
        assertTrue(api.path("paths").path("/api/v1/drivers/me/deliveries/current").path("get").path("responses").has("204"));
        assertTrue(api.path("paths").path("/api/v1/drivers/me/events").path("get").path("responses").path("200")
            .path("content").has("text/event-stream"));
        assertTrue(api.path("paths").path("/api/v1/drivers/me/application/documents/{type}").path("post")
            .path("requestBody").path("content").has("multipart/form-data"));
        var schemas = api.path("components").path("schemas");
        boolean foundDriverProfile = false, foundApplicationView = false;
        var entries = schemas.fields();
        while (entries.hasNext()) {
            var entry = entries.next();
            if (entry.getValue().path("properties").has("accountStatus")) foundDriverProfile = true;
            if (entry.getValue().path("properties").has("identityNumber")) foundApplicationView = true;
            var properties = entry.getValue().path("properties").fields();
            while (properties.hasNext()) {
                var property = properties.next();
                assertFalse(property.getValue().path("description").asText().isBlank(), entry.getKey() + "." + property.getKey());
            }
        }
        assertTrue(foundDriverProfile);
        assertTrue(foundApplicationView);
    }

    @Test void responseContractsMatchSpecialCasesAndSettingsHttpMethods() throws Exception {
        var result = mvc.perform(get("/v3/api-docs")).andExpect(status().isOk()).andReturn();
        var paths = json.readTree(result.getResponse().getContentAsByteArray()).path("paths");
        var reconcile = paths.path("/api/v1/admin/driver-earnings/{deliveryId}/reconcile").path("post");
        assertFalse(reconcile.path("responses").path("200").has("content"));
        assertTrue(reconcile.path("responses").path("200").path("description").asText().contains("không có response body"));
        for (String setting : new String[]{"order-settings", "app-settings"}) {
            var endpoint = paths.path("/api/v1/drivers/me/" + setting);
            assertTrue(endpoint.path("get").path("summary").asText().startsWith("Xem"));
            assertTrue(endpoint.path("put").path("summary").asText().startsWith("Cập nhật"));
            assertFalse(endpoint.path("get").path("responses").has("400"));
            assertTrue(endpoint.path("put").path("responses").has("400"));
        }
        var upload = paths.path("/api/v1/drivers/me/application/documents/{type}").path("post");
        assertTrue(upload.path("responses").has("503"));
        assertTrue(upload.path("responses").path("503").path("content").has("application/problem+json"));
        var document = paths.path("/api/v1/admin/driver-applications/{id}/documents/{type}").path("get");
        assertTrue(document.path("responses").path("404").path("description").asText().contains("type"));
    }

    @Test void swaggerUiIsAccessibleButBusinessApisStillRequireJwt() throws Exception {
        mvc.perform(get("/swagger-ui/index.html")).andExpect(status().isOk());
        mvc.perform(get("/v3/api-docs.yaml")).andExpect(status().isOk());
        mvc.perform(get("/v3/api-docs/swagger-config")).andExpect(status().isOk());
        mvc.perform(get("/api/v1/drivers/me/wallet")).andExpect(status().isUnauthorized());
        mvc.perform(get("/api/v1/admin/driver-earnings/pending")).andExpect(status().isUnauthorized());
    }
}
