import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/addon_model.dart';
import '../../../core/models/voucher_model.dart';
import '../providers/customer_providers.dart';

/// Accumulates state across the multi-step "new booking" flow:
/// quantity -> rate calc -> add-ons -> voucher -> extras (insurance/birthday)
/// -> address + schedule -> confirm. Mirrors the fields BookingController::schedule
/// expects, so `submit()` can send them as-is.
class BookingDraft {
  final int bagQuantity;
  final double washingCharge;
  final double deliveryCharge;
  final double sstPercent;
  final double taxCharge;
  final List<AddOn> selectedAddons;
  final Voucher? voucher;
  final double addonDiscount;
  final bool insuranceSelected;
  final double insuranceFee;
  final bool birthdayRewardSelected;
  final double birthdayRewardAmount;
  final int? pickupLocationId;
  final DateTime? pickupDate;
  final String? pickupStartTime;
  final String? pickupEndTime;
  final List<String> qrcodeSeriesNumbers;
  final String? pickupPhotoPath;
  final String? pickupNote;

  const BookingDraft({
    this.bagQuantity = 1,
    this.washingCharge = 0,
    this.deliveryCharge = 0,
    this.sstPercent = 0,
    this.taxCharge = 0,
    this.selectedAddons = const [],
    this.voucher,
    this.addonDiscount = 0,
    this.insuranceSelected = false,
    this.insuranceFee = 0,
    this.birthdayRewardSelected = false,
    this.birthdayRewardAmount = 0,
    this.pickupLocationId,
    this.pickupDate,
    this.pickupStartTime,
    this.pickupEndTime,
    this.qrcodeSeriesNumbers = const [],
    this.pickupPhotoPath,
    this.pickupNote,
  });

  double get addonCharge => selectedAddons.fold(0.0, (sum, a) => sum + a.price);

  /// Public wrapper so screens outside this file can display the
  /// voucher discount as its own line item.
  double get voucherDiscountAmount => _voucherDiscountAmount();

  /// Mirrors BookingController::schedule's grand_total formula exactly:
  /// (washing + delivery + addon + tax + insurance) - (discount + addon_discount + birthday)
  /// SST (tax) is computed server-side by calculateRate() from the admin
  /// setting — never hardcoded here — so this preview always matches
  /// what schedule() will actually charge.
  double get grandTotal {
    final voucherDiscount = _voucherDiscountAmount();
    final insurance = insuranceSelected ? insuranceFee : 0;
    final birthday = birthdayRewardSelected ? birthdayRewardAmount : 0;
    final total = (washingCharge + deliveryCharge + addonCharge + taxCharge) -
        (voucherDiscount + addonDiscount + birthday) +
        insurance;
    return total < 0 ? 0 : total;
  }

  double _voucherDiscountAmount() {
    if (voucher == null) return 0;
    if (voucher!.discountAmount != null) return voucher!.discountAmount!;
    if (voucher!.discountPercent != null) {
      return (washingCharge + deliveryCharge) * voucher!.discountPercent! / 100;
    }
    return 0;
  }

  BookingDraft copyWith({
    int? bagQuantity,
    double? washingCharge,
    double? deliveryCharge,
    double? sstPercent,
    double? taxCharge,
    List<AddOn>? selectedAddons,
    Voucher? voucher,
    bool clearVoucher = false,
    double? addonDiscount,
    bool? insuranceSelected,
    double? insuranceFee,
    bool? birthdayRewardSelected,
    double? birthdayRewardAmount,
    int? pickupLocationId,
    DateTime? pickupDate,
    String? pickupStartTime,
    String? pickupEndTime,
    List<String>? qrcodeSeriesNumbers,
    String? pickupPhotoPath,
    String? pickupNote,
  }) {
    return BookingDraft(
      bagQuantity: bagQuantity ?? this.bagQuantity,
      washingCharge: washingCharge ?? this.washingCharge,
      deliveryCharge: deliveryCharge ?? this.deliveryCharge,
      sstPercent: sstPercent ?? this.sstPercent,
      taxCharge: taxCharge ?? this.taxCharge,
      selectedAddons: selectedAddons ?? this.selectedAddons,
      voucher: clearVoucher ? null : (voucher ?? this.voucher),
      addonDiscount: addonDiscount ?? this.addonDiscount,
      insuranceSelected: insuranceSelected ?? this.insuranceSelected,
      insuranceFee: insuranceFee ?? this.insuranceFee,
      birthdayRewardSelected: birthdayRewardSelected ?? this.birthdayRewardSelected,
      birthdayRewardAmount: birthdayRewardAmount ?? this.birthdayRewardAmount,
      pickupLocationId: pickupLocationId ?? this.pickupLocationId,
      pickupDate: pickupDate ?? this.pickupDate,
      pickupStartTime: pickupStartTime ?? this.pickupStartTime,
      pickupEndTime: pickupEndTime ?? this.pickupEndTime,
      qrcodeSeriesNumbers: qrcodeSeriesNumbers ?? this.qrcodeSeriesNumbers,
      pickupPhotoPath: pickupPhotoPath ?? this.pickupPhotoPath,
      pickupNote: pickupNote ?? this.pickupNote,
    );
  }
}

class BookingDraftNotifier extends Notifier<BookingDraft> {
  @override
  BookingDraft build() => const BookingDraft();

  Future<void> setQuantity(int quantity) async {
    final repo = ref.read(customerRepositoryProvider);
    final rate = await repo.calculateRate(quantity);
    state = state.copyWith(
      bagQuantity: quantity,
      washingCharge: rate.washingCharge,
      deliveryCharge: rate.deliveryCharge,
      sstPercent: rate.sstPercent,
      taxCharge: rate.taxCharge,
    );
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

  Future<String?> applyVoucher(String code) async {
    final voucher = await ref.read(customerRepositoryProvider).checkVoucher(code);
    if (voucher == null) return 'Voucher is invalid, inactive, or already used.';
    state = state.copyWith(voucher: voucher);
    return null;
  }

  void removeVoucher() => state = state.copyWith(clearVoucher: true);

  Future<void> toggleInsurance(bool selected) async {
    if (selected && state.insuranceFee == 0) {
      final fee = await ref.read(customerRepositoryProvider).checkInsurance();
      state = state.copyWith(insuranceSelected: selected, insuranceFee: fee);
    } else {
      state = state.copyWith(insuranceSelected: selected);
    }
  }

  void setBirthdayReward(bool selected, double amount) {
    state = state.copyWith(birthdayRewardSelected: selected, birthdayRewardAmount: amount);
  }

  void setSchedule({
    required int pickupLocationId,
    required DateTime pickupDate,
    required String pickupStartTime,
    required String pickupEndTime,
    required List<String> qrcodeSeriesNumbers,
  }) {
    state = state.copyWith(
      pickupLocationId: pickupLocationId,
      pickupDate: pickupDate,
      pickupStartTime: pickupStartTime,
      pickupEndTime: pickupEndTime,
      qrcodeSeriesNumbers: qrcodeSeriesNumbers,
    );
  }

  /// Sets the mandatory pickup handoff photo + note (e.g. laundry left
  /// at a hotel lobby) — required before submit() will proceed, since
  /// the backend itself rejects a booking without both.
  void setPickupHandoff({required String photoPath, required String note}) {
    state = state.copyWith(pickupPhotoPath: photoPath, pickupNote: note);
  }

  /// Submits the booking. Returns the raw `data` payload — check for a
  /// `booking` key (instant confirmation) vs a `url` key (needs payment).
  Future<Map<String, dynamic>> submit() async {
    final s = state;
    if (s.pickupLocationId == null || s.pickupDate == null) {
      throw StateError('Pickup location and date must be set before submitting.');
    }
    if (s.pickupPhotoPath == null || s.pickupNote == null || s.pickupNote!.trim().isEmpty) {
      throw StateError('A pickup photo and note are required before submitting.');
    }
    final result = await ref.read(customerRepositoryProvider).schedule(
          pickupLocationId: s.pickupLocationId!,
          pickupDate: s.pickupDate!,
          pickupBagQuantity: s.bagQuantity,
          pickupStartTime: s.pickupStartTime ?? '09:00',
          pickupEndTime: s.pickupEndTime ?? '12:00',
          deliveryCharge: s.deliveryCharge,
          washingCharge: s.washingCharge,
          tax: s.taxCharge,
          qrcodeSeriesNumbers: s.qrcodeSeriesNumbers,
          pickupPhotoPath: s.pickupPhotoPath!,
          pickupNote: s.pickupNote!,
          voucherCode: s.voucher?.code,
          addonIds: s.selectedAddons.map((a) => a.id).toList(),
          addonCharge: s.addonCharge,
          addonDiscount: s.addonDiscount,
          insuranceFee: s.insuranceSelected ? s.insuranceFee : null,
          birthdayReward: s.birthdayRewardSelected ? s.birthdayRewardAmount : null,
        );
    reset();
    // A subscribed customer's booking consumes a quota slot server-side
    // (orders_used_current_cycle) — without invalidating this, the
    // dashboard kept showing the pre-booking "0/4" until something else
    // happened to trigger a refresh, even though the backend had
    // already updated correctly.
    ref.invalidate(currentSubscriptionProvider);
    ref.invalidate(homeBookingsProvider);
    return result;
  }

  void reset() => state = const BookingDraft();
}

final bookingDraftProvider = NotifierProvider<BookingDraftNotifier, BookingDraft>(
  BookingDraftNotifier.new,
);
