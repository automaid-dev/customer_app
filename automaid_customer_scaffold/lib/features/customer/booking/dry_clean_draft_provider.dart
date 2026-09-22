import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/service_category_model.dart';
import '../../../core/models/addon_model.dart';
import '../../../core/models/voucher_model.dart';
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
  // How many physical bags the items are packed into — dry-clean
  // pricing is per-piece, not per-bag, so this isn't used for pricing
  // the items themselves. It's still sent as pickup_bag_quantity
  // though, since BookingController::schedule() uses that same field
  // to calculate delivery_charge regardless of order type, and it
  // doubles as a remark for the rider on how many bags to expect at
  // pickup.
  final int bagQuantity;
  final double sstPercent;
  final int? pickupLocationId;
  final DateTime? pickupDate;
  final String? pickupStartTime;
  final String? pickupEndTime;
  final String? pickupPhotoPath;
  final String? pickupNote;
  // Add-ons, insurance, and voucher — same fields/semantics as
  // BookingDraft, added here so dry-cleaning bookings support the same
  // extras as Wash & Fold. Add-ons shown here are filtered server-side
  // (AddOn.applicable_to) to only those the admin marked available for
  // dry cleaning specifically, or "both".
  final List<AddOn> selectedAddons;
  final double addonDiscount;
  final bool insuranceSelected;
  final double insuranceFee;
  final Voucher? voucher;

  const DryCleanDraft({
    this.serviceCategoryId,
    this.cart = const {},
    this.subscriberDiscountPercent = 0,
    this.maxItemsPerBag = 20,
    this.deliveryCharge = 0,
    this.bagQuantity = 1,
    this.sstPercent = 0,
    this.pickupLocationId,
    this.pickupDate,
    this.pickupStartTime,
    this.pickupEndTime,
    this.pickupPhotoPath,
    this.pickupNote,
    this.selectedAddons = const [],
    this.addonDiscount = 0,
    this.insuranceSelected = false,
    this.insuranceFee = 0,
    this.voucher,
  });

  int get totalQuantity => cart.values.fold(0, (sum, qty) => sum + qty);

  double get subtotal =>
      cart.entries.fold(0.0, (sum, e) => sum + (e.key.pricePerPiece * e.value));

  double get discountAmount => subtotal * (subscriberDiscountPercent / 100);

  double get itemsTotal => subtotal - discountAmount;

  double get addonCharge => selectedAddons.fold(0.0, (sum, a) => sum + a.price);

  /// Mirrors BookingDraft's voucher math exactly — flat RM amount or a
  /// percentage of (itemsTotal + deliveryCharge), the dry-clean
  /// equivalent of (washingCharge + deliveryCharge).
  double get voucherDiscountAmount {
    if (voucher == null) return 0;
    if (voucher!.discountAmount != null) return voucher!.discountAmount!;
    if (voucher!.discountPercent != null) {
      return (itemsTotal + deliveryCharge) * voucher!.discountPercent! / 100;
    }
    return 0;
  }

  // Matches BookingController::schedule()'s actual tax formula exactly
  // — (washing/items + delivery) * sst_percent, addon_charge is NOT
  // part of it there (even though the separate calculateRate() preview
  // endpoint does include addon_charge in its own tax figure — a
  // pre-existing inconsistency between the two server-side formulas,
  // not something introduced here). This matches what schedule() will
  // actually charge, which matters more than matching the other
  // preview endpoint's different formula.
  double get taxCharge => (itemsTotal + deliveryCharge) * (sstPercent / 100);

  /// Mirrors BookingController::schedule's grand_total formula, dry-clean
  /// version: (items + delivery + addon + tax) - (voucher + addonDiscount) + insurance.
  double get grandTotal {
    final insurance = insuranceSelected ? insuranceFee : 0;
    final total = (itemsTotal + deliveryCharge + addonCharge + taxCharge) -
        (voucherDiscountAmount + addonDiscount) +
        insurance;
    return total < 0 ? 0 : total;
  }

  bool get isOverLimit => totalQuantity > maxItemsPerBag;

  bool get isEmpty => cart.isEmpty;

  DryCleanDraft copyWith({
    int? serviceCategoryId,
    Map<ServiceItem, int>? cart,
    double? subscriberDiscountPercent,
    int? maxItemsPerBag,
    double? deliveryCharge,
    int? bagQuantity,
    double? sstPercent,
    int? pickupLocationId,
    DateTime? pickupDate,
    String? pickupStartTime,
    String? pickupEndTime,
    String? pickupPhotoPath,
    String? pickupNote,
    List<AddOn>? selectedAddons,
    double? addonDiscount,
    bool? insuranceSelected,
    double? insuranceFee,
    Voucher? voucher,
    bool clearVoucher = false,
  }) {
    return DryCleanDraft(
      serviceCategoryId: serviceCategoryId ?? this.serviceCategoryId,
      cart: cart ?? this.cart,
      subscriberDiscountPercent: subscriberDiscountPercent ?? this.subscriberDiscountPercent,
      maxItemsPerBag: maxItemsPerBag ?? this.maxItemsPerBag,
      deliveryCharge: deliveryCharge ?? this.deliveryCharge,
      bagQuantity: bagQuantity ?? this.bagQuantity,
      sstPercent: sstPercent ?? this.sstPercent,
      pickupLocationId: pickupLocationId ?? this.pickupLocationId,
      pickupDate: pickupDate ?? this.pickupDate,
      pickupStartTime: pickupStartTime ?? this.pickupStartTime,
      pickupEndTime: pickupEndTime ?? this.pickupEndTime,
      pickupPhotoPath: pickupPhotoPath ?? this.pickupPhotoPath,
      pickupNote: pickupNote ?? this.pickupNote,
      selectedAddons: selectedAddons ?? this.selectedAddons,
      addonDiscount: addonDiscount ?? this.addonDiscount,
      insuranceSelected: insuranceSelected ?? this.insuranceSelected,
      insuranceFee: insuranceFee ?? this.insuranceFee,
      voucher: clearVoucher ? null : (voucher ?? this.voucher),
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

  // Add-ons, insurance, voucher — identical logic to
  // BookingDraftNotifier's equivalents, kept as separate methods here
  // (rather than sharing code) so this provider doesn't depend on
  // changes to the Wash & Fold one, and vice versa.

  void setBagQuantity(int quantity) {
    if (quantity < 1) return;
    state = state.copyWith(bagQuantity: quantity);
  }

  void toggleAddon(AddOn addon) {
    final list = [...state.selectedAddons];
    if (list.any((a) => a.id == addon.id)) {
      list.removeWhere((a) => a.id == addon.id);
    } else {
      list.add(addon);
    }
    state = state.copyWith(selectedAddons: list);
  }

  Future<void> refreshAddonDiscount() async {
    if (state.addonCharge <= 0) {
      state = state.copyWith(addonDiscount: 0);
      return;
    }
    final discount = await ref.read(customerRepositoryProvider).checkAddonDiscount(state.addonCharge);
    state = state.copyWith(addonDiscount: discount);
  }

  Future<void> toggleInsurance(bool selected) async {
    if (selected && state.insuranceFee == 0) {
      final result = await ref.read(customerRepositoryProvider).checkInsurance();
      state = state.copyWith(insuranceSelected: selected, insuranceFee: result.fee);
    } else {
      state = state.copyWith(insuranceSelected: selected);
    }
  }

  Future<String?> applyVoucher(String code) async {
    final voucher = await ref.read(customerRepositoryProvider).checkVoucher(code);
    if (voucher == null) return 'Voucher is invalid, inactive, or already used.';
    state = state.copyWith(voucher: voucher);
    return null;
  }

  void removeVoucher() => state = state.copyWith(clearVoucher: true);

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
          pickupBagQuantity: s.bagQuantity,
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
          voucherCode: s.voucher?.code,
          addonIds: s.selectedAddons.map((a) => a.id).toList(),
          addonCharge: s.addonCharge,
          addonDiscount: s.addonDiscount,
          insuranceFee: s.insuranceSelected ? s.insuranceFee : null,
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
