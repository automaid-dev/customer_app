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

Set to "LB AutoMaid" (matching the app icon's launcher label) in:
- `lib/main.dart` — `MaterialApp.router(title: 'LB AutoMaid', ...)`
- Also set the launcher label in
  `android/app/src/main/AndroidManifest.xml` (`android:label="LB AutoMaid"`) and
  `ios/Runner/Info.plist` (`CFBundleDisplayName` → `LB AutoMaid`) — `flutter create`
  fills these with the project name by default, so update them if you haven't already
  (your screenshot shows this already showing correctly on the home screen, so this
  may already be done — just confirming where it lives if you ever re-scaffold).

## Backend URL

Set in `lib/core/auth/auth_providers.dart`:

```dart
const String kApiBaseUrl = 'https://app.automaid.asia/api';
```

Now that this is HTTPS on a real domain, the Android cleartext-traffic
exception set up earlier for the bare IP (`network_security_config.xml`
+ `android:networkSecurityConfig` in `AndroidManifest.xml`) is no longer
needed for reaching the API — safe to remove for a slightly tighter
security posture, though leaving it in place is harmless too since
nothing points at the old IP anymore.

## Branding (new)

Rebranded around the LaundryBar mark — colors and type pulled from the
actual logo rather than a generic Material default:

- **Palette**: blue `#1565C0` (primary, from the mascot body), yellow
  `#FFC72C` (accent — CTAs, highlights), red `#E53935` (rare accent only,
  matching the logo outline — not used as a UI color so it doesn't
  compete with yellow). Defined in `lib/core/theme/app_theme.dart`.
- **Type**: Baloo 2 (via `google_fonts`) for headings — a rounded,
  friendly face matching the cartoon mascot's personality — paired with
  the system face for body text, so dense screens (forms, receipts,
  addresses) stay easy to scan rather than getting slowed down by a
  playful display face everywhere.
- **App icon**: source image at `assets/icon/app_icon.jpeg`
  (`flutter_launcher_icons` config already in `pubspec.yaml`) — after
  `flutter pub get`, run:
  ```bash
  dart run flutter_launcher_icons
  ```
  This generates the actual Android/iOS icon files; I can't run this
  from here since it needs the Flutter SDK. The source image has a busy
  angular background — if it looks cropped oddly on Android's adaptive
  icon masks (circle/squircle/rounded-square), swap in a version of just
  the mascot on a transparent/plain background and re-run.
- **Login screen**: LaundryBar wordmark above, Automaid mark below,
  matching the layout you specified.
- **Getting Started screen** (new) — now the app's actual first screen
  (`lib/features/onboarding/getting_started_screen.dart`), a hero banner
  in brand blue/yellow with the Automaid mark, a short tagline, and a
  single "Get started" button into login. The router's initial route is
  now `/welcome` instead of `/login`.
- **Quick-action tiles** on the home dashboard now use colored icon
  squares (one brand color per action) instead of plain icons, in the
  same spirit as the reference screenshot's colorful category icons.

`google_fonts` downloads the font file at runtime on first use rather
than bundling it — needs internet the first time that screen loads. If
you want it fully offline-capable, let me know and I can switch to
bundling the font file directly as an asset instead.

## Terms & Conditions acceptance (new)

Before a booking proceeds to payment, the app now fetches the admin-
uploaded T&C PDF (Settings > Legal Documents in the admin panel — see
the accompanying backend patch) and shows it full-screen
(`lib/features/customer/legal/terms_conditions_screen.dart`) with a
required "I have read and accept" checkbox before the "Accept &
continue" button enables. Declining (backing out) cancels the confirm
action — booking does not proceed to payment.

If the admin hasn't uploaded a document yet, this step is skipped
entirely rather than blocking every booking on a document that doesn't
exist — so this is safe to deploy before the admin has actually uploaded
a PDF.

## What's included

Same customer feature set as before the split — home dashboard, addresses,
bags/QR scanning, the new-booking flow, orders + ratings, subscriptions.
See the code comments in `lib/features/customer/data/customer_repository.dart`
for the full endpoint mapping and known backend gaps (e.g.
`orderActive`/`orderUpcoming` not yet returning data server-side).

## Sign-up / registration (new)

Reachable from the login screen ("Don't have an account? Sign up"), a
3-step flow: personal info → address (typed fields + map pin) → OTP.

- **Step 1** calls `POST /auth/register` (name, email, mobile, password,
  DOB) — this creates the account (status PENDING) and triggers an OTP SMS.
  Mobile number is collected as a local number and normalized to the
  `60XXXXXXXXX` shape the backend's validation regex requires.
- **Step 2** collects address line 1/2, postcode, city, state as typed
  fields, plus a **map pin** (Grab/Foodpanda-style fixed-center-pin picker,
  `lib/features/auth/widgets/map_picker_screen.dart`) for the lat/long the
  backend's Address model requires. This step doesn't call the backend yet
  — there's no registration-time address endpoint — the address is held
  locally until step 3 succeeds.
- **Step 3** submits the OTP to `POST /auth/register/verify`. On success
  this activates the account and signs the user in (note: this endpoint's
  token comes back nested as `user.api_token`, not a top-level `token`
  field like login — see the comment in `auth_repository.dart`). Right
  after that, the app saves the address collected in step 2 via the normal
  authenticated `POST /customer/profile/address/store` endpoint. The
  router then sends the now-authenticated customer straight to the
  dashboard automatically.

### ⚠️ Worth confirming: OTP delivery channel

You asked for the OTP to be sent via OneSignal. Tracing the backend
(`AuthController::register` / `resendOtp`), **OTP is currently sent via a
separate SMS gateway (`OneWaySmsService`), not OneSignal** — OneSignal is
only used elsewhere in the backend to send the post-verification welcome
*email*, not the OTP itself. This app is wired to the OTP flow that
actually exists and works today. If you specifically want the OTP
delivered through OneSignal instead (it supports transactional SMS on
some plans, separate from its push-notification feature), that's a
backend change to `AuthController` — let me know and I'll make it.

### Required native setup for the map picker

`google_maps_flutter` needs an API key wired into each platform, and this
can't be done from inside `lib/` — do this after scaffolding:

**Android** — in `android/app/src/main/AndroidManifest.xml`, inside the
`<application>` tag:
```xml
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="YOUR_GOOGLE_MAPS_API_KEY"/>
```
Also add the location permission (needed for the "use current location"
button):
```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
```

**iOS** — in `ios/Runner/AppDelegate.swift`, add before `return super...`:
```swift
GMSServices.provideAPIKey("YOUR_GOOGLE_MAPS_API_KEY")
```
And in `ios/Runner/Info.plist`, add a location-usage description:
```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>Automaid uses your location to help pin your address accurately.</string>
```

Get an API key from the [Google Cloud Console](https://console.cloud.google.com/google/maps-apis) with the "Maps SDK for Android" and "Maps SDK for iOS" enabled — this is separate from any other API key you may already have.

## Payment gateway (Fiuu) — now a real in-app flow

Booking, bag purchase, and subscription all previously just showed a
dialog with the raw payment link as text — not actually usable as a real
checkout. Now they open the Fiuu-hosted payment page in an in-app WebView
(`lib/features/customer/payment/payment_webview_screen.dart`), and after
the person completes it, verify the *real* outcome by polling the order's
own status via the API (`CustomerRepository.waitForPaymentConfirmation`)
rather than trusting anything read out of the gateway's page — that page
is server-rendered HTML meant for a browser, not something to parse for a
verdict.

This required one small backend change: `order_id` wasn't being returned
alongside the payment `url` for booking, bag purchase, or subscription,
so the app had no way to check "did this specific order succeed"
afterward. Added it to all three (see the accompanying backend patch).

**Bag purchase** gets a real receipt screen after a confirmed payment
(same one used for the free-bag-claim path), with a **download/share**
button in the app bar that generates a PDF (`lib/features/customer/payment/receipt_pdf.dart`)
and hands it to the OS share sheet (`printing` package) — the person can
save it to Files, print it, or share it, whichever their device offers.

**Subscription** shows a confirmation dialog naming the plan once
payment is confirmed.

**Booking** shows a confirmation snackbar once payment is confirmed.

If the WebView flow finishes but the order still isn't showing as paid
after a few polling attempts (~10 seconds total), the app doesn't block
on it further — it tells the person to check back shortly, since the
webhook that flips the order to paid can occasionally take a moment
longer than that.

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
