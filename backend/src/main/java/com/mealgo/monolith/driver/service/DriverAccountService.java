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
public class DriverAccountService {
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
        PageResponse.validate(page,size); return PageResponse.from(earnings.findByDriverId(drivers.myDriver().getId(),PageRequest.of(page,size,Sort.by("createdAt").descending().and(Sort.by("id")))).map(this::transaction));
    }
    @Transactional(readOnly=true) public Transaction transaction(UUID id) { return transaction(earnings.findByIdAndDriverId(id,drivers.myDriver().getId()).orElseThrow(()->ApiException.notFound("Transaction not found"))); }
    @Transactional(readOnly=true) public Earnings earnings(Period period,LocalDate date) {
        if(date==null) date=LocalDate.now(ZONE);
        LocalDate from=switch(period) { case DAY -> date; case WEEK -> date.with(TemporalAdjusters.previousOrSame(DayOfWeek.MONDAY)); case MONTH -> date.withDayOfMonth(1); };
        LocalDate end=switch(period) { case DAY -> from.plusDays(1); case WEEK -> from.plusWeeks(1); case MONTH -> from.plusMonths(1); };
        var rows=earnings.findByDriverIdAndCreatedAtGreaterThanEqualAndCreatedAtLessThan(drivers.myDriver().getId(),from.atStartOfDay(ZONE).toInstant(),end.atStartOfDay(ZONE).toInstant());
        var chart=new ArrayList<ChartPoint>(); BigDecimal total=BigDecimal.ZERO;
        for(LocalDate day=from;day.isBefore(end);day=day.plusDays(1)) {
            final var target=day; var daily=rows.stream().filter(e->e.getCreatedAt().atZone(ZONE).toLocalDate().equals(target)).toList();
            var amount=daily.stream().map(DriverEarning::getAmount).reduce(BigDecimal.ZERO,BigDecimal::add); total=total.add(amount);
            chart.add(new ChartPoint(day,daily.size(),amount));
        }
        return new Earnings(period,from,end.minusDays(1),ZONE.getId(),rows.size(),total,"VND",rate.signum()>0,chart);
    }
    private Notification notification(DriverNotification n) { return new Notification(n.getId(),n.getType(),n.getTitle(),n.getMessage(),n.getReferenceId(),n.getReadAt()!=null,n.getCreatedAt()); }
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
        if(earnings.existsByDeliveryId(deliveryId)) return;
        if(rate.signum()<0) throw new IllegalStateException("Driver earning rate must not be negative");
        var e=new DriverEarning(); e.setDriverId(driver.getId()); e.setDeliveryId(deliveryId); e.setAmount(rate);
        e.setRateConfigured(rate.signum()>0); e.setBalanceAfter(earnings.balance(driver.getId()).add(rate)); e.setCreatedAt(deliveredAt); earnings.save(e);
        if(!Boolean.FALSE.equals(driver.getInAppNotificationsEnabled())) {
            var n=new DriverNotification(); n.setDriverId(driver.getId()); n.setReferenceId(deliveryId); n.setType("DELIVERY_COMPLETED");
            n.setTitle("Giao hàng thành công"); n.setMessage(rate.signum()>0?"Tiền công đã được ghi nhận: "+rate.toPlainString()+" VND":"Đã hoàn tất giao hàng. Tiền công chưa được cấu hình."); notifications.save(n);
        }
    }
}
