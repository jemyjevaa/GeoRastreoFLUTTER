class RouteModel {
  final int id;
  final String name;
  final int groupId;
  bool? status;   // null = DESCONOCIDO, true = EN LÍNEA, false = FUERA DE LÍNEA
  double lat;
  double lng;
  String statusText;

  RouteModel({
    required this.id,
    required this.name,
    required this.groupId,
    this.lat = 0.0,
    this.lng = 0.0,
    this.status,
    required this.statusText
  });

  factory RouteModel.fromJson(Map<String, dynamic> json) => RouteModel(
        id: json["id"],
        name: json["name"],
        groupId: json["groupId"] ?? 0,
        statusText: json["status"]
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "name": name,
        "groupId": groupId,
        "statusText": statusText,
      };
}
