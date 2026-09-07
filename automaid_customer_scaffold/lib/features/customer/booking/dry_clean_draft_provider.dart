import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/service_category_model.dart';
import '../providers/customer_providers.dart';

/// Accumulates state across the dry-cleaning booking flow: item catalog
/// browsing -> cart (item -> quantity) -> address + schedule + pickup
/// handoff -> submit. Pricing (subtotal, subscriber discount, delivery,
/// SST, grand total) mirrors what BookingController::schedule actually
/// computes server-side — this is a preview only, the server never
/// trusts client-sent prices.
class DryCleanDraft {
  final int? serviceCategoryId;
  final Map<ServiceItem, int> cart;
  final double subscriberDiscountPercent;
  final int maxItemsPerBag;
  final double deliveryCharge;
  final double sstPercent;
  final int? pickupLocationId;
  final DateTime? pickupDate;
  final String? pickupStartTime;
  final String? pickupEndTime;
  final String? pickupPhotoPath;
  final String? pickupNote;

  const DryCleanDraft({
    this.serviceCategoryId,
    this.cart = const {},
    this.subscriberDiscountPercent = 0,
    this.maxItemsPerBag = 20,
    this.deliveryCharge = 0,
    this.sstPercent = 0,
    this.pickupLocationId,
    this.pickupDate,
    this.pickupStartTime,
    this.pickupEndTime,
    this.pickupPhotoPath,
    this.pickupNote,
  });

  int get totalQuantity => cart.values.fold(0, (sum, qty) => sum + qty);

  double get subtotal =>
      cart.entries.fold(0.0, (sum, e) => sum + (e.key.pricePerPiece * e.value));

  double get discountAmount => subtotal * (subscriberDiscountPercent / 100);

  double get itemsTotal => subtotal - discountAmount;

  double get taxCharge => (itemsTotal + deliveryCharge) * (sstPercent / 100);

  double get grandTotal => itemsTotal + deliveryCharge + taxCharge;

  bool get isOverLimit => totalQuantity > maxItemsPerBag;

  bool get isEmpty => cart.isEmpty;

  DryCleanDraft copyWith({
    int? serviceCategoryId,
    Map<ServiceItem, int>? cart,
    double? subscriberDiscountPercent,
    int? maxItemsPerBag,
    double? deliveryCharge,
    double? sstPercent,
    int? pickupLocationId,
    DateTime? pickupDate,
    String? pickupStartTime,
    String? pickupEndTime,
    String? pickupPhotoPath,
    String? pickupNote,
  }) {
    return DryCleanDraft(
      serviceCategoryId: serviceCategoryId ?? this.serviceCategoryId,
      cart: cart ?? this.cart,
      subscriberDiscountPercent: subscriberDiscountPercent ?? this.subscriberDiscountPercent,
      maxItemsPerBag: maxItemsPerBag ?? this.maxItemsPerBag,
      deliveryCharge: deliveryCharge ?? this.deliveryCharge,
      sstPercent: sstPercent ?? this.sstPercent,
      pickupLocationId: pickupLocationId ?? this.pickupLocationId,
      pickupDate: pickupDate ?? this.pickupDate,
      pickupStartTime: pickupStartTime ?? this.pickupStartTime,
      pickupEndTime: pickupEndTime ?? this.pickupEndTime,
      pickupPhotoPath: pickupPhotoPath ?? this.pickupPhotoPath,
      pickupNote: pickupNote ?? this.pickupNote,
    );
  }
}

class DryCleanDraftNotifier extends Notifier<DryCleanDraft> {
  @override
  DryCleanDraft build() => const DryCleanDraft();

  /// Loads the catalog's discount %/max-per-bag into the draft — call
  /// once when the item-selection screen opens.
  void applyCatalogInfo({
    required int serviceCategoryId,
    required double subscriberDiscountPercent,
    required int maxItemsPerBag,
  }) {
    state = state.copyWith(
      serviceCategoryId: serviceCategoryId,
      subscriberDiscountPercent: subscriberDiscountPercent,
      maxItemsPerBag: maxItemsPerBag,
    );
  }

  void setQuantity(ServiceItem item, int quantity) {
    final newCart = {...state.cart};
    if (quantity <= 0) {
      newCart.remove(item);
    } else {
      newCart[item] = quantity;
    }
    state = state.copyWith(cart: newCart);
  }

  void increment(ServiceItem item) => setQuantity(item, (state.cart[item] ?? 0) + 1);

  void decrement(ServiceItem item) => setQuantity(item, (state.cart[item] ?? 0) - 1);

  Future<void> loadDeliveryEstimate() async {
    final repo = ref.read(customerRepositoryProvider);
    final rate = await repo.calculateRate(1); // dry-clean orders are always pickup_bag_quantity=1
    state = state.copyWith(deliveryCharge: rate.deliveryCharge, sstPercent: rate.sstPercent);
  }

  void setSchedule({
    required int pickupLocationId,
    required DateTime pickupDate,
    required String pickupStartTime,
    required String pickupEndTime,
  }) {
    state = state.copyWith(
      pickupLocationId: pickupLocationId,
      pickupDate: pickupDate,
      pickupStartTime: pickupStartTime,
      pickupEndTime: pickupEndTime,
    );
  }

  void setPickupHandoff({required String photoPath, required String note}) {
    state = state.copyWith(pickupPhotoPath: photoPath, pickupNote: note);
  }

  /// Submits the dry-clean booking. Returns the raw `data` payload —
  /// check for a `booking` key (instant confirmation) vs a `url` key
  /// (needs payment), same shape as the Wash & Fold flow.
  Future<Map<String, dynamic>> submit() async {
    final s = state;
    if (s.cart.isEmpty) {
      throw StateError('Add at least one item before submitting.');
    }
    if (s.isOverLimit) {
      throw StateError('This bag can hold up to ${s.maxItemsPerBag} items — remove some or place a separate booking for the rest.');
    }
    if (s.pickupLocationId == null || s.pickupDate == null) {
      throw StateError('Pickup location and date must be set before submitting.');
    }
    if (s.pickupPhotoPath == null || s.pickupNote == null || s.pickupNote!.trim().isEmpty) {
      throw StateError('A pickup photo and note are required before submitting.');
    }
    if (s.serviceCategoryId == null) {
      throw StateError('Missing service category — please reopen the catalog and try again.');
    }

    final result = await ref.read(customerRepositoryProvider).schedule(
          pickupLocationId: s.pickupLocationId!,
          pickupDate: s.pickupDate!,
          pickupBagQuantity: 1,
          pickupStartTime: s.pickupStartTime ?? '09:00',
          pickupEndTime: s.pickupEndTime ?? '12:00',
          deliveryCharge: s.deliveryCharge,
          washingCharge: s.itemsTotal, // not trusted server-side, recomputed from items — sent for parity with the request shape only
          qrcodeSeriesNumbers: const [],
          pickupPhotoPath: s.pickupPhotoPath!,
          pickupNote: s.pickupNote!,
          serviceCategoryId: s.serviceCategoryId,
          items: s.cart.entries
              .map((e) => {'service_item_id': e.key.id, 'quantity': e.value})
              .toList(),
        );
    reset();
    ref.invalidate(currentSubscriptionProvider);
    ref.invalidate(homeBookingsProvider);
    return result;
  }

  void reset() => state = const DryCleanDraft();
}

final dryCleanDraftProvider = NotifierProvider<DryCleanDraftNotifier, DryCleanDraft>(
  DryCleanDraftNotifier.new,
);
