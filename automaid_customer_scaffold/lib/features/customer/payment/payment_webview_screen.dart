import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Opens a Fiuu-hosted payment page in-app and detects when the flow
/// completes by watching for navigation to the backend's own return
/// route (POST /webhook/fiuu/return — see routes/web.php). That page is
/// server-rendered HTML meant for a browser, not something to parse for
/// a verdict — this screen only uses reaching it as a signal that the
/// gateway flow is done, then pops with `true` so the caller can check
/// the actual order/subscription status via the API (the only source of
/// truth), rather than trusting anything read out of the gateway's page.
///
/// Pops with `false` if the person backs out before finishing.
class PaymentWebViewScreen extends StatefulWidget {
  const PaymentWebViewScreen({super.key, required this.paymentUrl});
  final String paymentUrl;

  @override
  State<PaymentWebViewScreen> createState() => _PaymentWebViewScreenState();
}

class _PaymentWebViewScreenState extends State<PaymentWebViewScreen> {
  late final WebViewController _controller;
  bool _loading = true;
  bool _finished = false;

  /// Matches any of the three backend webhook endpoints Fiuu might land
  /// on after payment (return/notification/callback all live under this
  /// same path prefix — see routes/web.php's 'webhook' group).
  bool _isReturnUrl(String url) => url.contains('/webhook/fiuu/');

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            if (!_finished && _isReturnUrl(url)) {
              _finished = true;
              // Give the backend's own page a moment to fully load/render
              // (and the webhook a moment to finish processing) before
              // popping back — the caller will re-check real status via
              // the API regardless, this is just a friendlier transition.
              Future.delayed(const Duration(seconds: 2), () {
                if (mounted) Navigator.of(context).pop(true);
              });
            }
            if (mounted) setState(() => _loading = true);
          },
          onPageFinished: (url) {
            if (mounted) setState(() => _loading = false);
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.paymentUrl));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {},
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Complete payment'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(false),
          ),
        ),
        body: Stack(
          children: [
            WebViewWidget(controller: _controller),
            if (_loading) const LinearProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
