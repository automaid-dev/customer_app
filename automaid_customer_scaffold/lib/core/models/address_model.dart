/// Mirrors app/Models/Address.php. Field names match AddressController's
/// saveAddress/updateAddress request body exactly.
class Address {
  final int id;
  final String? unitNo;
  final String? floor;
  final String? block;
  final String addressLine1;
  final String? addressLine2;
  final String? addressTitle;
  final String? countryName;
  final String? stateName;
  final String city;
  final String postcode;
  final double latitude;
  final double longitude;

  Address({
    required this.id,
    required this.addressLine1,
    required this.city,
    required this.postcode,
    required this.latitude,
    required this.longitude,
    this.unitNo,
    this.floor,
    this.block,
    this.addressLine2,
    this.addressTitle,
    this.countryName,
    this.stateName,
  });

  factory Address.fromJson(Map<String, dynamic> json) {
    return Address(
      id: json['id'] as int,
      addressLine1: json['address_line_1']?.toString() ?? '',
      city: json['city']?.toString() ?? '',
      postcode: json['postcode']?.toString() ?? '',
      latitude: double.tryParse(json['latitude']?.toString() ?? '') ?? 0,
      longitude: double.tryParse(json['longitude']?.toString() ?? '') ?? 0,
      unitNo: json['unit_no']?.toString(),
      floor: json['floor']?.toString(),
      block: json['block']?.toString(),
      addressLine2: json['address_line_2']?.toString(),
      addressTitle: json['address_title']?.toString(),
      countryName: json['country_name']?.toString(),
      stateName: json['state_name']?.toString(),
    );
  }

  /// Request body shape for saveAddress / updateAddress.
  Map<String, dynamic> toRequestBody({int? addressId}) => {
        if (addressId != null) 'address_id': addressId,
        'unit_no': unitNo,
        'floor': floor,
        'block': block,
        'address_line_1': addressLine1,
        'address_line_2': addressLine2,
        'address_title': addressTitle,
        'country_name': countryName,
        'state_name': stateName,
        'city': city,
        'postcode': postcode,
        'latitude': latitude,
        'longitude': longitude,
      };

  String get displayLabel => addressTitle?.isNotEmpty == true ? addressTitle! : addressLine1;
}
