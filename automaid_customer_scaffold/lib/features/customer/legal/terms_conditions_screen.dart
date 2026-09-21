import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

/// Fetches and displays the admin-uploaded Terms & Conditions PDF
/// (Settings > Legal Documents > terms_conditions, exposed by the
/// backend as Setting.terms_conditions_url), and requires an explicit
/// checkbox acceptance before the "Accept & continue" button enables.
///
/// Pops with `true` if accepted, `false`/`null` if the person backs out
/// without accepting — the booking flow only proceeds to payment on `true`.
class TermsConditionsScreen extends StatefulWidget {
  const TermsConditionsScreen({super.key, required this.pdfUrl});
  final String pdfUrl;

  @override
  State<TermsConditionsScreen> createState() => _TermsConditionsScreenState();
}

class _TermsConditionsScreenState extends State<TermsConditionsScreen> {
  bool _accepted = false;
  bool _loading = true;
  String? _error;
  Uint8List? _pdfBytes;

  @override
  void initState() {
    super.initState();
    _loadPdf();
  }

  Future<void> _loadPdf() async {
    try {
      // This is a direct asset URL (S3), not one of our own API
      // endpoints — fetched with a plain Dio instance rather than going
      // through ApiClient, since there's no bearer token or JSON envelope
      // involved here.
      final response = await Dio().get<List<int>>(
        widget.pdfUrl,
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
          Expanded(
            child: _loading
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
                                onPressed: () {
                                  setState(() => _loading = true);
                                  _loadPdf();
                                },
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
