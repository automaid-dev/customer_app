import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_providers.dart';
import '../../../core/models/address_model.dart';
import '../../../core/models/booking_model.dart';
import '../../../core/models/setting_model.dart';
import '../../../core/models/subscription_plan_model.dart';
import 'customer_repository.dart';

final customerRepositoryProvider = Provider<CustomerRepository>((ref) {
  return CustomerRepository(ref.read(apiClientProvider));
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

  Future<void> update(Address address) async {
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
