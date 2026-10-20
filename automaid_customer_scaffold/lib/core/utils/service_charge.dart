/// Payment gateway service charge — a % admin sets per gateway
/// (Settings → Payment Gateway). 0 = no charge, and then nothing is shown.
/// The server applies the same formula (App\Support\GatewayFee) and is
/// the source of truth; these helpers only preview it in the summary.

const String kServiceChargeLabel = 'Payment gateway service charge';

/// % of [amount], rounded to 2 decimals like the server (PHP round()).
double serviceChargeFor(double amount, double percent) {
  if (percent <= 0 || amount <= 0) return 0;
  return (amount * percent / 100 * 100).roundToDouble() / 100;
}

/// "1.5", "2", "0.75" — no trailing zeros.
String percentText(double percent) {
  var s = percent.toStringAsFixed(2);
  if (s.contains('.')) s = s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  return s;
}

String serviceChargeLabel(double percent) => '$kServiceChargeLabel (${percentText(percent)}%)';

/// Charge already recorded on an order (receipts / order detail).
double orderGatewayFee(Map<String, dynamic> order) =>
    double.tryParse(order['gateway_fee']?.toString() ?? '') ?? 0;

String orderGatewayFeeLabel(Map<String, dynamic> order) {
  final pct = double.tryParse(order['gateway_fee_percent']?.toString() ?? '') ?? 0;
  return pct > 0 ? serviceChargeLabel(pct) : kServiceChargeLabel;
}

/// Mirrors BookingController::schedule — a booking goes to the payment
/// page unless it's free, or covered by an active plan with no add-ons
/// and no SST.
bool bookingNeedsPayment({
  required double grandTotal,
  required bool subscribed,
  required double addonCharge,
  required double taxCharge,
}) =>
    grandTotal > 0 && !(subscribed && addonCharge == 0 && taxCharge == 0);
