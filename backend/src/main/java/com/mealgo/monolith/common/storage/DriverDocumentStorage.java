package com.mealgo.monolith.common.storage;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
/** Separate private bucket; never expose object keys or public URLs. */
@Component
public class DriverDocumentStorage {
    private final EvidenceStorage storage;
    public DriverDocumentStorage(@Value("${app.storage.endpoint}") String endpoint,
        @Value("${app.storage.access-key}") String key,@Value("${app.storage.secret-key}") String secret,
        @Value("${app.storage.driver-bucket:driver-documents}") String bucket) {
        storage=new EvidenceStorage(endpoint,key,secret,bucket);
    }
    public void put(String key,byte[] bytes,String type) { storage.put(key,bytes,type); }
    public byte[] get(String key) { return storage.get(key); }
}
