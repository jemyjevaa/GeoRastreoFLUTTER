class RouteModel {
  final int id;
  final String name;
  double lat;
  double lng;

  RouteModel({
    required this.id,
    required this.name,
    this.lat = 0.0,
    this.lng = 0.0,
  });

  factory RouteModel.fromJson(Map<String, dynamic> json) => RouteModel(
        id: json["id"],
        name: json["name"],
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "name": name,
      };
}
