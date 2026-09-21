/// Mirrors app/Models/Qrcode.php — each physical laundry bag has one of these
/// tied to it (series_no is what's printed/encoded as the QR).
class QrcodeModel {
  final int id;
  final String seriesNo;
  final String status; // pending | scanned | assigned ... (see Qrcode::PENDING/SCANNED constants)

  QrcodeModel({required this.id, required this.seriesNo, required this.status});

  factory QrcodeModel.fromJson(Map<String, dynamic> json) => QrcodeModel(
        id: json['id'] as int,
        seriesNo: json['series_no']?.toString() ?? '',
        status: json['status']?.toString() ?? '',
      );
}
