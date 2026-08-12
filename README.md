# Automaid — Customer App

Flutter rebuild of the customer-facing app, talking to the existing
Laravel 11 backend. This is the customer-only half of what was previously
one combined project — see `automaid_merchantrider/` for the rider +
merchant app.

## Getting the exact package name you asked for

You want `com.paynwash.automaid.customer` as the Android applicationId /
iOS bundle ID. Flutter's `flutter create` builds the ID as
`{org}.{project-name}` — so to land on exactly that four-segment ID,
use `automaid` as part of the **org**, and `customer` as the **project name**:

```bash
flutter create --org com.paynwash.automaid --project-name customer automaid_customer_scaffold
```

This generates `android/`, `ios/`, etc. with applicationId /
bundle ID = `com.paynwash.automaid.customer` — exactly what you want, no
manual editing of `build.gradle` or `Info.plist` needed.

Then bring in this project's code:

```bash
# Copy this project's pubspec.yaml and lib/ over the scaffold
cp -r automaid_customer/pubspec.yaml automaid_customer/lib automaid_customer_scaffold/
cd automaid_customer_scaffold
flutter pub get
flutter run
```

(Optional: rename the folder to `automaid_customer` once copied over, and
update `pubspec.yaml`'s `name:` field to `automaid_customer` for clarity —
purely cosmetic, since this codebase uses relative imports throughout, not
`package:automaid_customer/...` imports, so the pubspec name doesn't affect
whether it compiles.)

## App display name

Currently set to "Automaid" in:
- `lib/main.dart` — `MaterialApp.router(title: 'Automaid', ...)`
- After scaffolding, also set the launcher label in
  `android/app/src/main/AndroidManifest.xml` (`android:label`) and
  `ios/Runner/Info.plist` (`CFBundleDisplayName`) — `flutter create` fills
  these with the project name by default, so update them to "Automaid".

## Backend URL

Set in `lib/core/auth/auth_providers.dart`:

```dart
const String kApiBaseUrl = 'http://56.69.76.60/api';
```

## What's included

Same customer feature set as before the split — home dashboard, addresses,
bags/QR scanning, the new-booking flow, orders + ratings, subscriptions.
See the code comments in `lib/features/customer/data/customer_repository.dart`
for the full endpoint mapping and known backend gaps (e.g.
`orderActive`/`orderUpcoming` not yet returning data server-side).

## Subscription plans (updated)

The subscription screen now fetches live Bronze/Silver/Platinum pricing
and order quotas from `POST /subscription/plans` (see
`lib/core/models/subscription_plan_model.dart` and
`subscriptionPlansProvider` in `customer_providers.dart`) instead of a
single flat price — pick a plan, then subscribe. Prices/quotas are never
hardcoded client-side, so this screen always matches whatever the admin
has set in Settings > Subscription Fees/Discounts on the backend.

This app only ever serves customer accounts — if a rider/merchant account
somehow logs in here, `lib/core/router/app_router.dart` logs them straight
back out rather than showing a broken screen.
