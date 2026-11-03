package com.mealgo.monolith.common.storage;
import com.mealgo.monolith.common.exception.ApiException;
import io.minio.*;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import java.io.ByteArrayInputStream;
@Service
public class EvidenceStorage {
    private final MinioClient client;
    private final String bucket;
    public EvidenceStorage(@Value("${app.storage.endpoint}") String endpoint,@Value("${app.storage.access-key}") String key,
            @Value("${app.storage.secret-key}") String secret,@Value("${app.storage.bucket}") String bucket) {
        this.client = MinioClient.builder().endpoint(endpoint).credentials(key,secret).build(); this.bucket=bucket;
    }
    public void put(String key,byte[] data,String contentType) {
        try {
            client.putObject(PutObjectArgs.builder().bucket(bucket).object(key).contentType(contentType)
                    .stream(new ByteArrayInputStream(data),data.length,-1).build());
        } catch (Exception e) { throw new ApiException(HttpStatus.SERVICE_UNAVAILABLE,"Evidence storage unavailable"); }
    }
    public byte[] get(String key) {
        try (var stream = client.getObject(GetObjectArgs.builder().bucket(bucket).object(key).build())) { return stream.readAllBytes(); }
        catch (Exception e) { throw new ApiException(HttpStatus.SERVICE_UNAVAILABLE,"Evidence storage unavailable"); }
    }
}
