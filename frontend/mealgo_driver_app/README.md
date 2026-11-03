# MealGo Driver

Flutter/Dart driver app prototype based on the local Stitch design exports in
`stitch_mealgo_driver_app_ui/`. No backend or real transactions are connected.

## Run

```powershell
flutter pub get
flutter run
```

## Architecture

```text
lib/
  app.dart                        App lifecycle and controller ownership
  app/app_dependencies.dart       Dependency injection / composition root
  core/                           Shared theme and formatting
  shared/widgets/                 Reusable UI components
  features/
    driver/
      domain/                     Profile, settings, repository contract
      data/                       In-memory driver repository
      presentation/               Settings UI
    delivery/
      domain/                     Order, stage, report, repository contract
      data/                       Mock delivery state transitions
      presentation/               Order panel, failure report form
    account/
      domain/                     Wallet, earnings, repository contract
      data/                       Mock account snapshot
      presentation/               Profile, income, wallet, history, notices
    home/presentation/
      driver_controller.dart      Session-level orchestration and state
      home_page.dart              Dashboard, navigation, shift prompts
      widgets/demo_map.dart       SDK-independent offline map illustration
```

Dependency direction: presentation -> domain contracts; data implements domain.
The composition root is the only place that selects mock implementations.
`DriverController` uses constructor injection and exposes asynchronous commands,
loading/error states and `ChangeNotifier` updates. No third-party state package
is needed for this prototype. Models are immutable; returned collections are
unmodifiable. Controllers and timers are disposed by the owning app.

## Demo flows

- Drag the start-shift slider; confirm the explicitly mocked face verification.
- Tap an order on the illustrated map or request list, then slide to accept.
- Open **ĐANG LÀM** and progress: accepted -> pickup -> picked up -> customer
  -> completed. Confirm cash collection before completing.
- Before pickup, reject with a reason; restaurant closure uses an explicitly
  mocked evidence confirmation. After pickup use the failure report flow instead.
- At the customer, open failure reporting, simulate eligibility, add a note and
  sample evidence, then submit. Reported orders receive no income pending review.
- Open settings, enable automatic offers, save, and use the explicit simulation
  button on the dashboard. Offers expire in 15 seconds. More than 3 rejections
  temporarily block auto offers for 24 hours in the current session.
- Profile, income day/week/month, wallet, transactions, order history and notices
  are available from the drawer. Completed demo orders update session totals.

## Mock boundaries and limitations

- All state is in memory; restarting resets the session. Account figures include
  clearly labeled seed data; dashboard totals count this session only.
- Map is a custom vector illustration, not geographic navigation or live GPS.
- No real camera, biometric verification, phone call, chat, push notification,
  photo upload, banking or payment is performed.
- Notification setting is stored but does not register an OS notification service.
- Settings filter by distance. Sample orders each have one item and zero advance.
- Earnings chart is illustrative, not calculated time-series analytics.
- Failure eligibility is an explicit demo checkbox, not validated call history.
- Rejection threshold is based on the supplied UI. Production policies, daily
  reset, penalties, automatic checkout and compensation require backend rules.
- Screens consolidate related Stitch variants into stateful flows rather than
  implement all 46 reference images as separate pixel-identical routes.
- Offline header is intentionally consistent with actual shift state, even though
  the supplied offline screenshot displays an ONLINE badge.

## Integrate an API later

1. Implement `DriverRepository`, `DeliveryRepository`, `AccountRepository` in the
   corresponding `data/` folders. Keep DTO parsing/mapping and network exceptions
   there; domain entities must not depend on JSON or a networking package.
2. Inject the real implementations through `AppDependencies`. The UI should not
   import mock classes or call HTTP directly.
3. Let the server own transition validation, acceptance atomicity, eligibility,
   cash reconciliation, earnings, lock expiry and idempotency. Current mock checks
   demonstrate boundaries and are not a security mechanism.
4. Replace the manual offer trigger with an injected event stream (WebSocket or
   push), use server expiry timestamps, and refresh authoritative wallet/history
   after each mutation instead of adding optimistic local credits.
5. Introduce platform service interfaces for location, evidence capture/upload,
   identity verification, call logs, chat and payments. Never treat demo evidence
   URIs or checkbox eligibility as valid production proof.
6. Add authentication, secure token storage, environment config, cancellation,
   typed API failures, pagination and persistence when backend contracts exist.

## Checks

```powershell
dart format lib test
flutter analyze
flutter test
```
