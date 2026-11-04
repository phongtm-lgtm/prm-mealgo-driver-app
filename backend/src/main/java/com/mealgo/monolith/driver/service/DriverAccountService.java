package com.mealgo.monolith.driver.service;

import com.mealgo.monolith.driver.dto.DriverAccountDtos.*;
import com.mealgo.monolith.driver.dto.DriverAccountDtos.Period;
import com.mealgo.monolith.driver.entity.*;
import com.mealgo.monolith.driver.repository.*;
import com.mealgo.monolith.common.dto.PageResponse;
import com.mealgo.monolith.common.exception.ApiException;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.data.domain.*;
import java.math.BigDecimal;
import java.time.*;
import java.time.temporal.TemporalAdjusters;
import java.util.*;

@Service @RequiredArgsConstructor
@lombok.extern.slf4j.Slf4j
public class DriverAccountService {
    private final PendingDriverEarningRepository pendingEarnings;
    private final DriverRepository driverRepository;
    private final com.mealgo.monolith.common.security.CurrentUser current;
    private final DriverService drivers;
    private final DriverEarningRepository earnings;
    private final DriverNotificationRepository notifications;
    @Value("${app.driver.earning-per-delivery:0}") private BigDecimal rate;
    private static final ZoneId ZONE=ZoneId.of("Asia/Ho_Chi_Minh");

    public OrderSettings settingsFor(Driver d) {
        return new OrderSettings(d.isAutoAcceptEnabled(),d.getMaxDeliveryDistanceKm()==null?100d:d.getMaxDeliveryDistanceKm(),
            d.getMaxItemQuantity()==null?5000:d.getMaxItemQuantity(),
            d.getMaxRestaurantAdvanceAmount()==null?BigDecimal.ZERO:d.getMaxRestaurantAdvanceAmount());
    }
    @Transactional(readOnly=true) public OrderSettings settings() { return settingsFor(drivers.myDriver()); }
    @Transactional public OrderSettings settings(OrderSettings r) {
        var d=drivers.lockMine(); d.setAutoAcceptEnabled(r.autoAcceptEnabled()); d.setMaxDeliveryDistanceKm(r.maxDeliveryDistanceKm());
        d.setMaxItemQuantity(r.maxItemQuantity()); d.setMaxRestaurantAdvanceAmount(r.maxRestaurantAdvanceAmount()); d.setUpdatedAt(Instant.now()); return settingsFor(d);
    }
    @Transactional(readOnly=true) public AppSettings appSettings() { return new AppSettings(!Boolean.FALSE.equals(drivers.myDriver().getInAppNotificationsEnabled())); }
    @Transactional public AppSettings appSettings(AppSettings r) { var d=drivers.lockMine(); d.setInAppNotificationsEnabled(r.inAppNotificationsEnabled()); return r; }
    @Transactional(readOnly=true) public Wallet wallet() { return new Wallet(earnings.balance(drivers.myDriver().getId()),"VND",rate.signum()>0); }
    private Transaction transaction(DriverEarning e) { return new Transaction(e.getId(),"DELIVERY_EARNING",e.getAmount(),e.getBalanceAfter(),e.getDeliveryId(),e.isRateConfigured()?"Tiền công giao hàng":"Giao thành công — chưa cấu hình tiền công",e.getCreatedAt()); }
    @Transactional(readOnly=true) public PageResponse<Transaction> transactions(int page,int size) {
        PageResponse.validate(page,size); return PageResponse.from(earnings.findByDriverIdAndRateConfiguredTrue(drivers.myDriver().getId(),PageRequest.of(page,size,Sort.by("createdAt").descending().and(Sort.by("id")))).map(this::transaction));
    }
    @Transactional(readOnly=true) public Transaction transaction(UUID id) { return transaction(earnings.findByIdAndDriverId(id,drivers.myDriver().getId()).filter(DriverEarning::isRateConfigured).orElseThrow(()->ApiException.notFound("Transaction not found"))); }
    @Transactional(readOnly=true) public Earnings earnings(Period period,LocalDate date) {
        if(date==null) date=LocalDate.now(ZONE);
        LocalDate from=switch(period) { case DAY -> date; case WEEK -> date.with(TemporalAdjusters.previousOrSame(DayOfWeek.MONDAY)); case MONTH -> date.withDayOfMonth(1); };
        LocalDate end=switch(period) { case DAY -> from.plusDays(1); case WEEK -> from.plusWeeks(1); case MONTH -> from.plusMonths(1); };
        var rows=earnings.findByDriverIdAndCreatedAtGreaterThanEqualAndCreatedAtLessThan(drivers.myDriver().getId(),from.atStartOfDay(ZONE).toInstant(),end.atStartOfDay(ZONE).toInstant()).stream().filter(DriverEarning::isRateConfigured).toList();
        var chart=new ArrayList<ChartPoint>(); BigDecimal total=BigDecimal.ZERO;
        for(LocalDate day=from;day.isBefore(end);day=day.plusDays(1)) {
            final var target=day; var daily=rows.stream().filter(e->e.getCreatedAt().atZone(ZONE).toLocalDate().equals(target)).toList();
            var amount=daily.stream().map(DriverEarning::getAmount).reduce(BigDecimal.ZERO,BigDecimal::add); total=total.add(amount);
            chart.add(new ChartPoint(day,daily.size(),amount));
        }
        return new Earnings(period,from,end.minusDays(1),ZONE.getId(),rows.size(),total,"VND",rate.signum()>0,chart);
    }
    private Notification notification(DriverNotification n) {
        String message=n.getMessage();
        if(n.getReferenceId()!=null && message.contains("chưa được cấu hình")) {
            var pending=pendingEarnings.findById(n.getReferenceId());
            message=pending.isPresent() && !pending.get().isResolved()
                ? "Giao hàng thành công! Tiền công của đơn này đang được cập nhật."
                : "Giao hàng thành công! Xem thông tin tiền công trong lịch sử giao dịch.";
        }
        return new Notification(n.getId(),n.getType(),n.getTitle(),message,n.getReferenceId(),n.getReadAt()!=null,n.getCreatedAt());
    }
    @Transactional(readOnly=true) public PageResponse<Notification> notifications(int page,int size) {
        PageResponse.validate(page,size); return PageResponse.from(notifications.findByDriverId(drivers.myDriver().getId(),PageRequest.of(page,size,Sort.by("createdAt").descending().and(Sort.by("id")))).map(this::notification));
    }
    @Transactional(readOnly=true) public UnreadCount unread() { return new UnreadCount(notifications.countByDriverIdAndReadAtIsNull(drivers.myDriver().getId())); }
    @Transactional public Notification read(UUID id) {
        var d=drivers.lockMine(); var n=notifications.findByIdAndDriverId(id,d.getId()).orElseThrow(()->ApiException.notFound("Notification not found"));
        if(n.getReadAt()==null) n.setReadAt(Instant.now()); return notification(n);
    }
    @Transactional public void readAll() { var d=drivers.lockMine(); notifications.findByDriverIdAndReadAtIsNull(d.getId()).forEach(n->n.setReadAt(Instant.now())); }

    /** Caller holds driver lock. This joins delivery completion's transaction. */
    @Transactional public void completed(Driver driver,UUID deliveryId,Instant deliveredAt) {
        completed(driver, deliveryId, deliveredAt, null);
    }
    @Transactional public void completed(Driver driver,UUID deliveryId,Instant deliveredAt, BigDecimal fee) {
        if(earnings.existsByDeliveryId(deliveryId)) return;
        if(pendingEarnings.existsById(deliveryId)) return;
        var earn = rate.signum() > 0 ? rate : (fee != null && fee.signum() > 0 ? fee : rate);
        if(earn.signum()<=0) {
            var p=new PendingDriverEarning(); p.setDeliveryId(deliveryId); p.setDriverId(driver.getId()); p.setDeliveredAt(deliveredAt); pendingEarnings.save(p);
            log.error("Driver earning pending: deliveryId={}, driverId={}, app.driver.earning-per-delivery={}; explicit admin reconciliation required",deliveryId,driver.getId(),rate);
            notifyEarning(driver,deliveryId,null);
            return;
        }
        var e=new DriverEarning(); e.setDriverId(driver.getId()); e.setDeliveryId(deliveryId); e.setAmount(earn);
        e.setRateConfigured(earn.signum()>0); e.setBalanceAfter(earnings.balance(driver.getId()).add(earn)); e.setCreatedAt(deliveredAt); earnings.save(e);
        notifyEarning(driver,deliveryId,earn);
    }
    private void notifyEarning(Driver driver,UUID deliveryId,BigDecimal amount) {
        if(!Boolean.FALSE.equals(driver.getInAppNotificationsEnabled())) {
            var n=new DriverNotification(); n.setDriverId(driver.getId()); n.setReferenceId(deliveryId); n.setType("DELIVERY_COMPLETED");
            n.setTitle("Giao hàng thành công"); n.setMessage(amount!=null?"Giao hàng thành công! Bạn nhận được "+java.text.NumberFormat.getIntegerInstance(java.util.Locale.forLanguageTag("vi-VN")).format(amount)+"đ.":"Giao hàng thành công! Tiền công của đơn này đang được cập nhật."); notifications.save(n);
        }
    }

    @Transactional(readOnly=true) public PageResponse<PendingDriverEarning> pending(int page,int size) {
        PageResponse.validate(page,size); return PageResponse.from(pendingEarnings.findByResolvedFalse(PageRequest.of(page,size,Sort.by("deliveredAt"))));
    }
    @Transactional public void reconcile(UUID deliveryId,BigDecimal amount) {
        if(amount==null || amount.signum()<=0 || amount.stripTrailingZeros().scale()>0) throw ApiException.badRequest("Approved whole VND amount required");
        var found=pendingEarnings.findById(deliveryId).orElseThrow(()->ApiException.notFound("Pending earning not found"));
        var driver=driverRepository.findLockedById(found.getDriverId()).orElseThrow();
        // Refresh after acquiring the same driver lock used by delivery completion.
        entityManager.refresh(found);
        if(found.isResolved()) return;
        if(earnings.existsByDeliveryId(deliveryId)) throw ApiException.conflict("Earning already exists; review required");
        var e=new DriverEarning(); e.setDriverId(driver.getId()); e.setDeliveryId(deliveryId); e.setAmount(amount);
        e.setBalanceAfter(earnings.balance(driver.getId()).add(amount)); e.setRateConfigured(true);
        e.setCreatedAt(Instant.now()); earnings.save(e);
        found.setResolved(true); found.setResolvedAt(Instant.now()); found.setResolvedBy(current.id());
        notifyEarning(driver,deliveryId,amount);
        log.info("Driver earning reconciled: deliveryId={}, amount={}, reviewedBy={}",deliveryId,amount,current.id());
    }
    @jakarta.persistence.PersistenceContext private jakarta.persistence.EntityManager entityManager;

    /** Bounded recovery of legacy placeholders. No balance is credited by this job. */
    @org.springframework.scheduling.annotation.Scheduled(fixedDelayString="${app.driver.earning-recovery-ms:60000}")
    @Transactional public void recoverLegacyEarnings() {
        for(var e:earnings.findByRateConfiguredFalse(PageRequest.of(0,100)).getContent()) {
            var driver=driverRepository.findLockedById(e.getDriverId()).orElseThrow();
            if(pendingEarnings.existsById(e.getDeliveryId())) continue;
            if(e.getAmount().signum()!=0) { log.error("Legacy unconfigured earning has nonzero amount: {}",e.getId()); continue; }
            if(!pendingEarnings.existsById(e.getDeliveryId())) {
                var p=new PendingDriverEarning(); p.setDeliveryId(e.getDeliveryId()); p.setDriverId(e.getDriverId()); p.setDeliveredAt(e.getCreatedAt()); pendingEarnings.save(p);
                notifyEarning(driver,e.getDeliveryId(),null);
                log.warn("Recovered legacy unpaid earning: deliveryId={}",e.getDeliveryId());
            }
            earnings.delete(e);

        }
    }
}
