import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Shows the Terms & Conditions chosen in admin (Settings > Legal
/// Documents): either the uploaded PDF, or a web page link
/// ([isWebPage], e.g. https://lbunlimitedwash.com/policy/booking_tnc.html)
/// shown in an in-app browser. Either way it requires an explicit
/// checkbox acceptance before the "Accept & continue" button enables.
///
/// Pops with `true` if accepted, `false`/`null` if the person backs out
/// without accepting — the booking flow only proceeds to payment on `true`.
class TermsConditionsScreen extends StatefulWidget {
  const TermsConditionsScreen({super.key, required this.url, this.isWebPage = false});
  final String url;
  final bool isWebPage;

  @override
  State<TermsConditionsScreen> createState() => _TermsConditionsScreenState();
}

class _TermsConditionsScreenState extends State<TermsConditionsScreen> {
  bool _accepted = false;
  bool _loading = true;
  String? _error;
  Uint8List? _pdfBytes;
  WebViewController? _web;
  int _webProgress = 0;

  @override
  void initState() {
    super.initState();
    if (widget.isWebPage) {
      _initWebPage();
    } else {
      _loadPdf();
    }
  }

  void _initWebPage() {
    final home = Uri.parse(widget.url);
    _web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (p) {
            if (mounted) setState(() => _webProgress = p);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
          onWebResourceError: (err) {
            // Only a failure of the page itself counts, not an image or font.
            if (err.isForMainFrame ?? true) {
              if (mounted) {
                setState(() {
                  _error = 'Could not load Terms & Conditions. Please check your connection and try again.';
                  _loading = false;
                });
              }
            }
          },
          // Links to other sites (e.g. a phone number, email or another
          // website) open outside the app; same-site pages stay here.
          onNavigationRequest: (req) {
            final uri = Uri.tryParse(req.url);
            if (uri == null) return NavigationDecision.prevent;
            final sameSite = uri.host == home.host && (uri.scheme == 'https' || uri.scheme == 'http');
            if (sameSite) return NavigationDecision.navigate;
            launchUrl(uri, mode: LaunchMode.externalApplication);
            return NavigationDecision.prevent;
          },
        ),
      )
      ..loadRequest(home);
  }

  void _retry() {
    setState(() {
      _loading = true;
      _error = null;
    });
    if (widget.isWebPage) {
      _web?.loadRequest(Uri.parse(widget.url));
    } else {
      _loadPdf();
    }
  }

  Future<void> _loadPdf() async {
    try {
      // This is a direct asset URL (S3), not one of our own API
      // endpoints — fetched with a plain Dio instance rather than going
      // through ApiClient, since there's no bearer token or JSON envelope
      // involved here.
      final response = await Dio().get<List<int>>(
        widget.url,
        options: Options(responseType: ResponseType.bytes),
      );
      setState(() {
        _pdfBytes = Uint8List.fromList(response.data!);
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Could not load Terms & Conditions. Please try again.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Terms & Conditions')),
      body: Column(
        children: [
          if (widget.isWebPage && _loading && _error == null)
            LinearProgressIndicator(value: _webProgress > 0 ? _webProgress / 100 : null),
          Expanded(
            child: widget.isWebPage && _error == null
                // The web view is kept in the tree while loading so the
                // page can render; the bar above shows progress.
                ? WebViewWidget(controller: _web!)
                : _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_error!, textAlign: TextAlign.center),
                              const SizedBox(height: 12),
                              OutlinedButton(
                                onPressed: _retry,
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : PdfPreview(
                        build: (format) async => _pdfBytes!,
                        canChangeOrientation: false,
                        canChangePageFormat: false,
                        canDebug: false,
                        allowPrinting: false,
                        allowSharing: false,
                        useActions: false,
                      ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: _accepted,
                    onChanged: (v) => setState(() => _accepted = v ?? false),
                    title: const Text(
                      'I agree to the Terms and Conditions and confirm that all items are '
                      'machine-washable and comply with item care labels and the selected '
                      'package limits.',
                    ),
                  ),
                  FilledButton(
                    onPressed: _accepted ? () => Navigator.of(context).pop(true) : null,
                    child: const Text('Accept & continue'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
