class RouteModel {
  final int id;
  final String name;
  final int groupId;
  bool status;
  double lat;
  double lng;

  RouteModel({
    required this.id,
    required this.name,
    required this.groupId,
    this.lat = 0.0,
    this.lng = 0.0,
    this.status = false,
  });

  factory RouteModel.fromJson(Map<String, dynamic> json) => RouteModel(
        id: json["id"],
        name: json["name"],
        groupId: json["groupId"] ?? 0,
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "name": name,
        "groupId": groupId,
      };
}
