/// Mirrors one row from POST /state/index (StateController::index).
/// Fetching this list instead of free-text entry sidesteps a real problem:
/// the seeded state names come from an external Malaysia postcodes
/// dataset that names the Kuala Lumpur federal territory "Wp Kuala Lumpur"
/// — nothing a person would guess by typing "Kuala Lumpur".
class StateModel {
  final int id;
  final String name;

  StateModel({required this.id, required this.name});

  factory StateModel.fromJson(Map<String, dynamic> json) => StateModel(
        id: json['id'] as int,
        name: json['name']?.toString() ?? '',
      );
}
