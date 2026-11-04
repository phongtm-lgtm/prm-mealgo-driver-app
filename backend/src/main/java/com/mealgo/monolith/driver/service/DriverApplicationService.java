package com.mealgo.monolith.driver.service;
import com.mealgo.monolith.driver.entity.*;
import com.mealgo.monolith.driver.repository.*;
import com.mealgo.monolith.auth.repository.UserAccountRepository;
import com.mealgo.monolith.common.security.CurrentUser;
import com.mealgo.monolith.common.exception.ApiException;
import com.mealgo.monolith.common.storage.DriverDocumentStorage;
import java.time.*;
import java.util.*;
import javax.imageio.ImageIO;
import java.io.ByteArrayInputStream;
import jakarta.validation.constraints.*;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

@Service @RequiredArgsConstructor
public class DriverApplicationService {
    public record Form(@NotBlank @Size(max=150) String fullName,@NotNull @Past LocalDate birthDate,
        @NotBlank @Size(max=500) String address,@NotBlank @Pattern(regexp="[0-9]{12}") String identityNumber,
        @NotBlank @Size(max=50) String vehicleType,@NotBlank @Size(max=20) String licensePlate,
        @NotBlank @Size(max=30) String drivingLicense) {}
    public record View(UUID applicationId,String status,String fullName,LocalDate birthDate,String address,
        String identityNumber,String vehicleType,String licensePlate,String drivingLicense,Set<String> documents,
        Instant submittedAt,Instant reviewedAt,UUID reviewedBy,String reviewNote) {}
    public record Approval(@Size(max=1000) String note) {}
    private static final Set<String> REQUIRED=Set.of("IDENTITY_FRONT","IDENTITY_BACK","VEHICLE_REGISTRATION","DRIVING_LICENSE");
    private final DriverApplicationRepository applications;
    private final DriverRepository drivers;
    private final UserAccountRepository users;
    private final CurrentUser current;
    private final DriverDocumentStorage storage;
    private View view(DriverApplication a) { return new View(a.getId(),a.getStatus(),a.getFullName(),a.getBirthDate(),a.getAddress(),a.getIdentityNumber(),a.getVehicleType(),a.getLicensePlate(),a.getDrivingLicense(),Set.copyOf(a.getDocuments().keySet()),a.getSubmittedAt(),a.getReviewedAt(),a.getReviewedBy(),a.getReviewNote()); }
    private DriverApplication mine() {
        return applications.findByUserId(current.id()).orElseGet(()-> {
            var a=new DriverApplication(); a.setUserId(current.id()); return applications.saveAndFlush(a);
        });
    }
    private DriverApplication lockMine() { return applications.findLockedById(mine().getId()).orElseThrow(); }
    private void editable(DriverApplication a) {
        if(!a.getStatus().equals("DRAFT")) throw ApiException.conflict("Hồ sơ đã gửi, không thể chỉnh sửa");
    }
    @Transactional public View get() { return view(mine()); }
    @Transactional public View save(Form r) {
        var a=lockMine(); editable(a);
        a.setFullName(r.fullName()); a.setBirthDate(r.birthDate()); a.setAddress(r.address()); a.setIdentityNumber(r.identityNumber());
        a.setVehicleType(r.vehicleType()); a.setLicensePlate(r.licensePlate()); a.setDrivingLicense(r.drivingLicense()); return view(a);
    }
    @Transactional public View upload(String type,MultipartFile image) {
        if(!REQUIRED.contains(type)) throw ApiException.badRequest("Loại giấy tờ không hợp lệ");
        var a=lockMine(); editable(a);
        if(image.isEmpty() || image.getSize()>5*1024*1024) throw ApiException.badRequest("Ảnh tối đa 5 MB");
        try {
            byte[] bytes=image.getBytes();
            String contentType;
            try(var input=ImageIO.createImageInputStream(new ByteArrayInputStream(bytes))) {
                var readers=ImageIO.getImageReaders(input);
                if(!readers.hasNext()) throw ApiException.badRequest("Ảnh phải là PNG hoặc JPEG");
                var reader=readers.next();
                try {
                    reader.setInput(input); String format=reader.getFormatName();
                    if(!format.equalsIgnoreCase("png") && !format.equalsIgnoreCase("jpeg")) throw ApiException.badRequest("Ảnh phải là PNG hoặc JPEG");
                    if((long)reader.getWidth(0)*reader.getHeight(0)>25000000) throw ApiException.badRequest("Ảnh quá lớn");
                    if(reader.read(0)==null) throw ApiException.badRequest("Ảnh không hợp lệ");
                    contentType=format.equalsIgnoreCase("png")?"image/png":"image/jpeg";
                } finally { reader.dispose(); }
            }
            String key="driver-applications/"+a.getId()+"/"+type+"/"+UUID.randomUUID();
            storage.put(key,bytes,contentType); a.getDocuments().put(type,key); return view(a);
        } catch(java.io.IOException e) { throw ApiException.badRequest("Không đọc được ảnh"); }
    }
    @Transactional public View submit() {
        var a=lockMine();
        if(a.getStatus().equals("PENDING_REVIEW")) return view(a);
        editable(a);
        if(a.getFullName()==null || !a.getDocuments().keySet().containsAll(REQUIRED)) throw ApiException.badRequest("Vui lòng hoàn thiện thông tin và 4 ảnh giấy tờ");
        a.setStatus("PENDING_REVIEW"); a.setSubmittedAt(Instant.now()); return view(a);
    }
    @Transactional(readOnly=true) public View adminGet(UUID id) { return view(applications.findById(id).orElseThrow(()->ApiException.notFound("Hồ sơ không tồn tại"))); }
    @Transactional(readOnly=true) public byte[] document(UUID id,String type) {
        var a=applications.findById(id).orElseThrow(()->ApiException.notFound("Hồ sơ không tồn tại"));
        var key=a.getDocuments().get(type); if(key==null) throw ApiException.notFound("Giấy tờ không tồn tại"); return storage.get(key);
    }
    @Transactional public View approve(UUID id,Approval r) {
        var a=applications.findLockedById(id).orElseThrow(()->ApiException.notFound("Hồ sơ không tồn tại"));
        if(a.getStatus().equals("APPROVED")) return view(a);
        if(!a.getStatus().equals("PENDING_REVIEW")) throw ApiException.conflict("Hồ sơ chưa được gửi xét duyệt");
        if(!a.getDocuments().keySet().containsAll(REQUIRED) || a.getFullName()==null) throw ApiException.conflict("Hồ sơ chưa đầy đủ");
        var d=drivers.findByUserId(a.getUserId()).orElseGet(Driver::new);
        d.setUserId(a.getUserId()); d.setFullName(a.getFullName());
        d.setPhoneNumber(users.findById(a.getUserId()).orElseThrow().getPhoneNumber()); d.setActive(true); drivers.save(d);
        a.setStatus("APPROVED"); a.setReviewedAt(Instant.now()); a.setReviewedBy(current.id()); a.setReviewNote(r.note()); return view(a);
    }
}
