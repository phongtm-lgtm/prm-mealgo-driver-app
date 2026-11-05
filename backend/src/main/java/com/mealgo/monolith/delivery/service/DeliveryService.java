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
import com.mealgo.monolith.order.event.OrderCancelled;
import com.mealgo.monolith.order.enums.OrderStatus;
import com.mealgo.monolith.order.mapper.OrderMapper;
import com.mealgo.monolith.order.service.OrderService;
import com.mealgo.monolith.restaurant.dto.RestaurantOrderDtos.Detail;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.*;
import org.springframework.context.event.EventListener;
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
    private final DeliveryIncidentRepository incidents;
    private final DriverService drivers;
    private final OrderService orders;
    private final OrderMapper orderMapper;
    private final DeliveryMapper mapper;
    private final ProximityService proximity;
    private final EvidenceStorage storage;
    private final DriverEventService events;
    private final DispatchService dispatch;
    private final com.mealgo.monolith.driver.service.DriverAccountService accounts;

    @Transactional public void create(Order order) {
        if (deliveries.findByOrderId(order.getId()).isEmpty()) {
            var d = new Delivery(); d.setOrderId(order.getId()); deliveries.save(d);
        }
    }
    @Transactional(readOnly=true) public List<Offer> offers() {
        return offersFor(drivers.myDriver().getId());
    }
    @Transactional public List<Offer> refreshOffers(Set<UUID> skippedAssignmentIds) {
        var driver = drivers.lockMine();
        dispatch.updateOffers(driver, skippedAssignmentIds);
        return offersFor(driver.getId());
    }
    private List<Offer> offersFor(UUID driverId) {
        return assignments.findByDriverIdAndStatusAndExpiresAtAfter(driverId,AssignmentStatus.OFFERED,Instant.now())
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
        events.changedAfterCommit(driver.getId());
        return mapper.offer(a,orders.get(d.getOrderId()));
    }
    @Transactional(readOnly=true) public Optional<Current> current() {
        return deliveries.findFirstByDriverIdAndStatusIn(drivers.myDriver().getId(),ACTIVE)
                .map(d -> mapper.current(d,orders.get(d.getOrderId())));
    }
    @Transactional(readOnly=true) public PageResponse<Current> history(int page,int size) {
        PageResponse.validate(page,size);
        return PageResponse.from(deliveries.findByDriverIdAndStatusIn(drivers.myDriver().getId(),
                List.of(DeliveryStatus.DELIVERED,DeliveryStatus.FAILED,DeliveryStatus.CANCELLED),PageRequest.of(page,size,Sort.by("updatedAt").descending()))
                .map(d -> mapper.current(d,orders.get(d.getOrderId()))));
    }
    @Transactional(readOnly=true) public Current historyDetail(UUID id) {
        var d=delivery(id);
        if(!drivers.myDriver().getId().equals(d.getDriverId()) || !List.of(DeliveryStatus.DELIVERED,DeliveryStatus.FAILED,DeliveryStatus.CANCELLED).contains(d.getStatus()))
            throw ApiException.notFound("Delivery history not found");
        return mapper.current(d,orders.get(d.getOrderId()));
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
                double km = proximity.routingDistanceMeters(o.getPickupLatitude(), o.getPickupLongitude(), o.getDropoffLatitude(), o.getDropoffLongitude()) / 1000.0;
                long feeVnd = Math.round(km * 10000.0);
                accounts.completed(driver, d.getId(), d.getDeliveredAt(), java.math.BigDecimal.valueOf(feeVnd));
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
        events.changedAfterCommit(driver.getId());
        return mapper.current(d,o);
    }
    @Transactional(readOnly=true) public Report report(UUID id) { return mapper.report(ownedReport(id)); }
    public record IncidentResult(UUID id,UUID deliveryId,UUID assignmentId,IncidentReason reason,String outcome,String note,Instant createdAt) {}
    private IncidentResult incidentResult(DeliveryIncident i) {
        return new IncidentResult(i.getId(),i.getDeliveryId(),i.getAssignmentId(),i.getReason(),
            "PENDING_REASSIGNMENT",i.getNote(),i.getCreatedAt());
    }
    @Transactional(readOnly=true) public List<IncidentResult> incidents() {
        return incidents.findByDriverIdOrderByCreatedAtDesc(drivers.myDriver().getId()).stream().map(this::incidentResult).toList();
    }
    @Transactional public IncidentResult incident(UUID id,UUID assignmentId,UUID requestId,IncidentReason reason,String note,MultipartFile image) {
        if(note!=null && note.length()>1000) throw ApiException.badRequest("Note maximum 1000 characters");
        if(reason==null) throw ApiException.badRequest("Reason required");
        boolean needsImage = reason == IncidentReason.RESTAURANT_CLOSED || reason == IncidentReason.CUSTOMER_UNREACHABLE;
        if (!needsImage && image != null && !image.isEmpty()) throw ApiException.badRequest("Unexpected image for this incident reason");
        var validated = needsImage ? validateImage(image) : null;
        var driver=drivers.lockMine();
        // Check immutable receipt before delivery ownership, which changes on reassignment.
        var existing=incidents.findByAssignmentId(assignmentId);
        if(existing.isPresent()) {
            var i=existing.get();
            if(!i.getDriverId().equals(driver.getId()) || !i.getDeliveryId().equals(id)) throw ApiException.notFound("Incident not found");
            if(!i.getRequestId().equals(requestId) || i.getReason()!=reason || !Objects.equals(note,i.getNote())
                || !Objects.equals(i.getSha256(),validated==null?null:validated.hash())) throw ApiException.conflict("A different incident already exists");
            return incidentResult(i);
        }
        var d=lockOwned(id,driver);
        if(!assignmentId.equals(d.getAssignmentId())) throw ApiException.notFound("Assignment not found");
        if(!List.of(DeliveryStatus.ASSIGNED,DeliveryStatus.AT_PICKUP).contains(d.getStatus())) throw ApiException.conflict("Cannot release or cancel after pickup");
        var o=orders.lock(d.getOrderId());
        if(o.getStatus()!=OrderStatus.PREPARING) throw ApiException.conflict("Cannot release a delivery once the order is READY");
        if(reason==IncidentReason.RESTAURANT_CLOSED) proximity.requireNear(driver,o.getPickupLatitude(),o.getPickupLongitude());
        var i=new DeliveryIncident(); i.setDriverId(driver.getId()); i.setDeliveryId(id); i.setAssignmentId(assignmentId);
        i.setRequestId(requestId); i.setReason(reason); i.setNote(note);
        var a=assignments.findById(assignmentId).orElseThrow();
        if(validated!=null) {
            i.setSha256(validated.hash()); i.setContentType(validated.contentType());
            i.setObjectKey("incidents/"+id+"/"+requestId+"/"+validated.hash());
            storage.put(i.getObjectKey(),validated.bytes(),validated.contentType());
        }
        a.setStatus(AssignmentStatus.RELEASED); d.setStatus(DeliveryStatus.PENDING_ASSIGNMENT);
        d.setDriverId(null); d.setAssignmentId(null);
        d.setUpdatedAt(Instant.now()); o.setUpdatedAt(Instant.now()); incidents.save(i);
        events.changedAfterCommit(driver.getId());
        return incidentResult(i);
    }
    // Synchronous listener joins the order transaction while its delivery lock is held.
    @EventListener
    public void onOrderCancelled(OrderCancelled event) {
        if (event.deliveryId() == null) return;
        var delivery = delivery(event.deliveryId());
        delivery.setStatus(DeliveryStatus.CANCELLED);
        delivery.setUpdatedAt(Instant.now());
        var affected = new HashSet<UUID>();
        if (delivery.getDriverId() != null) {
            accounts.notifyCancellation(delivery.getDriverId(), delivery.getId(), event.code());
            affected.add(delivery.getDriverId());
        }
        for (var offer : assignments.findByDeliveryId(delivery.getId())) {
            if (offer.getStatus() == AssignmentStatus.OFFERED || offer.getStatus() == AssignmentStatus.ACCEPTED) {
                offer.setStatus(AssignmentStatus.CANCELLED);
                affected.add(offer.getDriverId());
            }
        }
        affected.forEach(events::changedAfterCommit);
    }
    public void notifyRestaurantReady(UUID orderId) {
        deliveries.findByOrderId(orderId).ifPresent(d -> events.changedAfterCommit(d.getDriverId()));
    }
    @Transactional(readOnly=true) public EvidenceContent incidentEvidence(UUID id) {
        var i=incidents.findByIdAndDriverId(id,drivers.myDriver().getId()).orElseThrow(()->ApiException.notFound("Incident not found"));
        if(i.getObjectKey()==null) throw ApiException.notFound("Evidence not found");
        return new EvidenceContent(storage.get(i.getObjectKey()),i.getContentType());
    }
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
        if (image == null) throw ApiException.badRequest("Image evidence is required");
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
