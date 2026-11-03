package com.mealgo.monolith.delivery.service;

import com.mealgo.monolith.common.dto.PageResponse;
import com.mealgo.monolith.common.exception.ApiException;
import com.mealgo.monolith.common.storage.EvidenceStorage;
import com.mealgo.monolith.delivery.dto.DeliveryDtos.*;
import com.mealgo.monolith.delivery.entity.*;
import com.mealgo.monolith.delivery.enums.*;
import com.mealgo.monolith.delivery.mapper.DeliveryMapper;
import com.mealgo.monolith.delivery.repository.*;
import com.mealgo.monolith.driver.entity.Driver;
import com.mealgo.monolith.driver.service.DriverService;
import com.mealgo.monolith.order.entity.Order;
import com.mealgo.monolith.order.enums.OrderStatus;
import com.mealgo.monolith.order.mapper.OrderMapper;
import com.mealgo.monolith.order.service.OrderService;
import com.mealgo.monolith.restaurant.dto.RestaurantOrderDtos.Detail;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.*;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;
import javax.imageio.ImageIO;
import java.io.*;
import java.security.*;
import java.time.Instant;
import java.util.*;

@Service @RequiredArgsConstructor
public class DeliveryService {
    public static final List<DeliveryStatus> ACTIVE = List.of(DeliveryStatus.ASSIGNED,DeliveryStatus.AT_PICKUP,
            DeliveryStatus.PICKED_UP,DeliveryStatus.AT_DROPOFF);
    private final DeliveryRepository deliveries;
    private final AssignmentRepository assignments;
    private final FailureReportRepository reports;
    private final DriverService drivers;
    private final OrderService orders;
    private final OrderMapper orderMapper;
    private final DeliveryMapper mapper;
    private final ProximityService proximity;
    private final EvidenceStorage storage;

    @Transactional public void create(Order order) {
        if (deliveries.findByOrderId(order.getId()).isEmpty()) {
            var d = new Delivery(); d.setOrderId(order.getId()); deliveries.save(d);
        }
    }
    @Transactional(readOnly=true) public List<Offer> offers() {
        return assignments.findByDriverIdAndStatusAndExpiresAtAfter(drivers.myDriver().getId(),AssignmentStatus.OFFERED,Instant.now())
                .stream().map(a -> mapper.offer(a,orders.get(delivery(a.getDeliveryId()).getOrderId()))).toList();
    }
    @Transactional(readOnly=true) public Offer offer(UUID id) {
        var a = ownedOffer(id,drivers.myDriver().getId());
        return mapper.offer(a,orders.get(delivery(a.getDeliveryId()).getOrderId()));
    }
    @Transactional public Offer respond(UUID id,boolean accept) {
        // Lock driver before delivery consistently with the dispatcher.
        var driver = drivers.lockMine(); var a = ownedOffer(id,driver.getId());
        var d = lock(a.getDeliveryId());
        var target = accept?AssignmentStatus.ACCEPTED:AssignmentStatus.REJECTED;
        if (a.getStatus()==target) return mapper.offer(a,orders.get(d.getOrderId()));
        if (a.getStatus()!=AssignmentStatus.OFFERED || !a.getExpiresAt().isAfter(Instant.now()))
            throw ApiException.conflict("Offer is no longer available");
        if (accept) {
            if (!driver.isOnline() || !driver.isActive()) throw ApiException.conflict("Driver must be active and online");
            if (d.getStatus()!=DeliveryStatus.PENDING_ASSIGNMENT || deliveries.existsByDriverIdAndStatusIn(driver.getId(),ACTIVE))
                throw ApiException.conflict("Delivery or driver already assigned");
            d.setDriverId(driver.getId()); d.setAssignmentId(a.getId()); d.setStatus(DeliveryStatus.ASSIGNED); d.setUpdatedAt(Instant.now());
        }
        a.setStatus(target); a.setRespondedAt(Instant.now());
        return mapper.offer(a,orders.get(d.getOrderId()));
    }
    @Transactional(readOnly=true) public Optional<Current> current() {
        return deliveries.findFirstByDriverIdAndStatusIn(drivers.myDriver().getId(),ACTIVE)
                .map(d -> mapper.current(d,orders.get(d.getOrderId())));
    }
    @Transactional(readOnly=true) public PageResponse<Current> history(int page,int size) {
        PageResponse.validate(page,size);
        return PageResponse.from(deliveries.findByDriverIdAndStatusIn(drivers.myDriver().getId(),
                List.of(DeliveryStatus.DELIVERED,DeliveryStatus.FAILED),PageRequest.of(page,size,Sort.by("updatedAt").descending()))
                .map(d -> mapper.current(d,orders.get(d.getOrderId()))));
    }
    @Transactional public Current action(UUID id,String action) {
        var driver = drivers.lockMine(); var d = lockOwned(id,driver);
        var o = orders.lock(d.getOrderId());
        switch (action) {
            case "arrive-at-pickup" -> {
                if (d.getStatus()==DeliveryStatus.AT_PICKUP) return mapper.current(d,o);
                require(d,DeliveryStatus.ASSIGNED); proximity.requireNear(driver,o.getPickupLatitude(),o.getPickupLongitude());
                d.setStatus(DeliveryStatus.AT_PICKUP);
            }
            case "confirm-pickup" -> {
                if (d.getStatus()==DeliveryStatus.PICKED_UP) return mapper.current(d,o);
                require(d,DeliveryStatus.AT_PICKUP); orders.require(o,OrderStatus.READY);
                proximity.requireNear(driver,o.getPickupLatitude(),o.getPickupLongitude());
                d.setStatus(DeliveryStatus.PICKED_UP); d.setPickedUpAt(Instant.now()); o.setStatus(OrderStatus.PICKED_UP);
            }
            case "arrive-at-dropoff" -> {
                if (d.getStatus()==DeliveryStatus.AT_DROPOFF) return mapper.current(d,o);
                require(d,DeliveryStatus.PICKED_UP); proximity.requireNear(driver,o.getDropoffLatitude(),o.getDropoffLongitude());
                d.setStatus(DeliveryStatus.AT_DROPOFF);
            }
            case "confirm-delivery" -> {
                if (d.getStatus()==DeliveryStatus.DELIVERED) return mapper.current(d,o);
                require(d,DeliveryStatus.AT_DROPOFF); proximity.requireNear(driver,o.getDropoffLatitude(),o.getDropoffLongitude());
                d.setStatus(DeliveryStatus.DELIVERED); d.setDeliveredAt(Instant.now()); o.setStatus(OrderStatus.DELIVERED);
                var a = assignments.findById(d.getAssignmentId()).orElseThrow();
                a.setStatus(AssignmentStatus.COMPLETED);
            }
            default -> throw ApiException.notFound("Unknown delivery action");
        }
        d.setUpdatedAt(Instant.now()); o.setUpdatedAt(Instant.now()); return mapper.current(d,o);
    }
    @Transactional public Current fail(UUID id,UUID assignmentId,UUID requestId,FailureReason reason,String note,MultipartFile image) {
        if (note!=null && note.length()>1000) throw ApiException.badRequest("Note maximum 1000 characters");
        var validated = validateImage(image);
        var driver = drivers.lockMine(); var d = lockOwned(id,driver);
        if (!assignmentId.equals(d.getAssignmentId())) throw ApiException.notFound("Assignment not found");
        var existing = reports.findByDeliveryId(id);
        if (existing.isPresent()) {
            var r = existing.get();
            if (!r.getRequestId().equals(requestId) || r.getReason()!=reason || !Objects.equals(r.getNote(),note)
                    || !r.getSha256().equals(validated.hash())) throw ApiException.conflict("A different failure report already exists");
            return mapper.current(d,orders.get(d.getOrderId()));
        }
        require(d,DeliveryStatus.AT_DROPOFF);
        var o = orders.lock(d.getOrderId());
        var report = new FailureReport(); report.setDeliveryId(id); report.setAssignmentId(assignmentId); report.setRequestId(requestId);
        report.setReason(reason); report.setNote(note); report.setSha256(validated.hash()); report.setContentType(validated.contentType());
        report.setSizeBytes(validated.bytes().length);
        // Deterministic key makes a same-content retry safe if DB commit fails after upload.
        report.setObjectKey(id+"/"+requestId+"/"+validated.hash());
        storage.put(report.getObjectKey(),validated.bytes(),validated.contentType()); reports.save(report);
        d.setStatus(DeliveryStatus.FAILED); d.setFailedAt(Instant.now()); d.setUpdatedAt(Instant.now());
        o.setStatus(OrderStatus.FAILED); o.setUpdatedAt(Instant.now());
        assignments.findById(assignmentId).orElseThrow().setStatus(AssignmentStatus.FAILED);
        return mapper.current(d,o);
    }
    @Transactional(readOnly=true) public Report report(UUID id) { return mapper.report(ownedReport(id)); }
    @Transactional(readOnly=true) public EvidenceContent evidence(UUID id) {
        var r = ownedReport(id); return new EvidenceContent(storage.get(r.getObjectKey()),r.getContentType());
    }
    @Transactional(readOnly=true) public Tracking track(UUID orderId) {
        var o = orders.myOrder(orderId); var dto = orderMapper.toResponse(o); var d = deliveries.findByOrderId(orderId).orElse(null);
        DriverInfo info = null; Location location = null;
        if (d!=null && d.getDriverId()!=null && ACTIVE.contains(d.getStatus())) {
            var driver = drivers.get(d.getDriverId()); info = driverInfo(driver);
            if (driver.getRecordedAt()!=null && driver.getLatitude()!=null)
                location = new Location(driver.getLatitude(),driver.getLongitude(),driver.getRecordedAt());
        }
        return new Tracking(orderId,o.getStatus().name(),d==null?null:d.getId(),d==null?null:d.getStatus(),info,location,dto.pickup(),dto.dropoff());
    }
    @Transactional(readOnly=true) public Detail restaurantDetail(Order o) {
        var d = deliveries.findByOrderId(o.getId()).orElse(null);
        return new Detail(orderMapper.toResponse(o),d==null || d.getDriverId()==null?null:driverInfo(drivers.get(d.getDriverId())),
                d==null?null:d.getStatus().name(),d==null?null:d.getPickedUpAt());
    }
    private DriverInfo driverInfo(Driver d) { return new DriverInfo(d.getId(),d.getFullName(),d.getPhoneNumber()); }
    private Assignment ownedOffer(UUID id,UUID driverId) {
        var a = assignments.findById(id).orElseThrow(() -> ApiException.notFound("Offer not found"));
        if (!a.getDriverId().equals(driverId)) throw ApiException.notFound("Offer not found"); return a;
    }
    private Delivery delivery(UUID id) { return deliveries.findById(id).orElseThrow(() -> ApiException.notFound("Delivery not found")); }
    private Delivery lock(UUID id) { return deliveries.findLockedById(id).orElseThrow(() -> ApiException.notFound("Delivery not found")); }
    private Delivery lockOwned(UUID id,Driver driver) {
        var d = lock(id); if (!driver.getId().equals(d.getDriverId())) throw ApiException.notFound("Delivery not found"); return d;
    }
    private FailureReport ownedReport(UUID id) {
        var d = delivery(id);
        if (!drivers.myDriver().getId().equals(d.getDriverId())) throw ApiException.notFound("Delivery not found");
        return reports.findByDeliveryId(id).orElseThrow(() -> ApiException.notFound("Failure report not found"));
    }
    private void require(Delivery d,DeliveryStatus expected) {
        if (d.getStatus()!=expected) throw ApiException.conflict("Expected delivery status "+expected+", actual "+d.getStatus());
    }
    private record ValidatedImage(byte[] bytes,String contentType,String hash) {}
    private ValidatedImage validateImage(MultipartFile image) {
        if (image.isEmpty() || image.getSize()>5*1024*1024) throw ApiException.badRequest("Image must be 1 byte to 5 MB");
        try {
            byte[] bytes = image.getBytes();
            try (var stream = ImageIO.createImageInputStream(new ByteArrayInputStream(bytes))) {
                var readers = ImageIO.getImageReaders(stream);
                if (!readers.hasNext()) throw ApiException.badRequest("Invalid image");
                var reader = readers.next();
                try {
                    reader.setInput(stream); String format = reader.getFormatName().toLowerCase(Locale.ROOT);
                    if (!Set.of("png","jpeg","jpg").contains(format)) throw ApiException.badRequest("Only PNG and JPEG are accepted");
                    if ((long)reader.getWidth(0)*reader.getHeight(0)>25_000_000) throw ApiException.badRequest("Image exceeds 25 megapixels");
                    if (reader.read(0)==null) throw ApiException.badRequest("Invalid image");
                    return new ValidatedImage(bytes,format.equals("png")?"image/png":"image/jpeg",
                            HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(bytes)));
                } finally { reader.dispose(); }
            }
        } catch (IOException e) { throw ApiException.badRequest("Cannot read image"); }
        catch (NoSuchAlgorithmException e) { throw new IllegalStateException(e); }
    }
}
