import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_providers.dart';
import '../../../core/models/address_model.dart';
import '../../../core/models/booking_model.dart';
import '../../../core/models/setting_model.dart';
import '../../../core/models/state_model.dart';
import '../../../core/models/subscription_plan_model.dart';
import '../data/customer_repository.dart';

final customerRepositoryProvider = Provider<CustomerRepository>((ref) {
  return CustomerRepository(ref.read(apiClientProvider));
});

/// Live list of Malaysian states from the backend's own seeded data — use
/// this to populate the state dropdown instead of free-text entry (see
/// CustomerRepository.states() for why that matters). Doesn't require
/// login, so this is safe to use from the sign-up screen too.
final statesProvider = FutureProvider.autoDispose<List<StateModel>>((ref) {
  return ref.read(customerRepositoryProvider).states();
});

/// Active (non-delivered, non-cancelled) bookings for the home dashboard.
/// Call `ref.invalidate(homeBookingsProvider)` after placing a new booking
/// to refresh this list.
final homeBookingsProvider = FutureProvider.autoDispose<List<BookingSummary>>((ref) {
  return ref.read(customerRepositoryProvider).home();
});

final announcementsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  return ref.read(customerRepositoryProvider).announcements();
});

final appSettingProvider = FutureProvider.autoDispose<AppSetting>((ref) {
  return ref.read(customerRepositoryProvider).setting();
});

/// Live bronze/silver/platinum pricing and quotas for the subscription
/// plan picker — always fetched fresh, never hardcoded, since the admin
/// can change prices anytime in Settings > Subscription Fees/Discounts.
final subscriptionPlansProvider = FutureProvider.autoDispose<List<SubscriptionPlan>>((ref) {
  return ref.read(customerRepositoryProvider).subscriptionPlans();
});

/// The customer's own subscription (null if they've never subscribed, or
/// present-but-not-active if cancelled/pending) — used by the home screen
/// to show either an active-plan summary or a "subscribe" banner.
final currentSubscriptionProvider = FutureProvider.autoDispose<Map<String, dynamic>?>((ref) {
  return ref.read(customerRepositoryProvider).currentSubscription();
});

/// Notification list + unread count — used by the Notifications screen
/// and the home screen's bell badge alike, so both stay in sync (marking
/// read on one refreshes the other via ref.invalidate).
final notificationsProvider = FutureProvider.autoDispose((ref) {
  return ref.read(customerRepositoryProvider).notifications();
});

/// Every order for this customer, any status — powers the "My orders"
/// list screen. Replaces the earlier home-dashboard-bookings workaround
/// now that the backend endpoint actually works.
final orderHistoryProvider = FutureProvider.autoDispose((ref) {
  return ref.read(customerRepositoryProvider).orderHistory();
});

/// Addresses aren't served by a dedicated "list my addresses" endpoint on
/// this backend — they come embedded in the customer profile response
/// (ProfileController::profile eager-loads `addresses`). We surface that
/// subset here so the address screens don't need to know about the whole
/// profile payload.
final addressListProvider =
    AsyncNotifierProvider.autoDispose<AddressListNotifier, List<Address>>(
        AddressListNotifier.new);

class AddressListNotifier extends AutoDisposeAsyncNotifier<List<Address>> {
  @override
  Future<List<Address>> build() async {
    final profile = await ref.read(customerRepositoryProvider).profile();
    final addresses = (profile['addresses'] as List<dynamic>? ?? []);
    return addresses.map((a) => Address.fromJson(a as Map<String, dynamic>)).toList();
  }

  Future<void> add(Address address) async {
    await ref.read(customerRepositoryProvider).saveAddress(address);
    ref.invalidateSelf();
    await future;
  }

  Future<void> updateAddress(Address address) async {
    await ref.read(customerRepositoryProvider).updateAddress(address);
    ref.invalidateSelf();
    await future;
  }

  Future<void> remove(int addressId) async {
    await ref.read(customerRepositoryProvider).deleteAddress(addressId);
    ref.invalidateSelf();
    await future;
  }
}

final purchasedBagsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  return ref.read(customerRepositoryProvider).bagPurchased();
});

final assignedBagsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  return ref.read(customerRepositoryProvider).bagAssigned();
});
