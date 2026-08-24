import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/customer_providers.dart';
import 'payment_webview_screen.dart';

/// Runs the full gateway flow for an order that needs payment:
/// 1. Opens the Fiuu payment page in-app.
/// 2. If the person completes it (WebView pops true), shows a brief
///    "Confirming payment…" dialog while polling the order's real status.
/// 3. Returns true only once the order is confirmed paid — false if the
///    person backed out, or if it's still pending after polling (their
///    receipt will simply appear in My Bags / show as active once the
///    webhook catches up, no need to block on it further here).
Future<bool> runPaymentFlow({
  required BuildContext context,
  required WidgetRef ref,
  required String paymentUrl,
  required int orderId,
}) async {
  final completedGatewayFlow = await Navigator.of(context).push<bool>(
    MaterialPageRoute(builder: (_) => PaymentWebViewScreen(paymentUrl: paymentUrl)),
  );

  if (completedGatewayFlow != true || !context.mounted) return false;

  bool isPaid = false;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => PopScope(
      canPop: false,
      child: FutureBuilder<bool>(
        future: ref.read(customerRepositoryProvider).waitForPaymentConfirmation(orderId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            isPaid = snapshot.data ?? false;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (Navigator.of(dialogContext).canPop()) Navigator.of(dialogContext).pop();
            });
          }
          return const AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 16),
                Expanded(child: Text('Confirming payment…')),
              ],
            ),
          );
        },
      ),
    ),
  );

  return isPaid;
}
